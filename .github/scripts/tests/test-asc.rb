#!/usr/bin/env ruby
# frozen_string_literal: true

# Offline tests for asc.rb. A generated stub replaces Net::HTTP.start so the
# script runs without network access; the stub logs each request (including
# the Authorization header) to a JSON file the assertions read back.
#
# Run: ruby .github/scripts/tests/test-asc.rb

require 'json'
require 'minitest/autorun'
require 'openssl'
require 'base64'
require 'tmpdir'
require 'English'

SCRIPTS = File.expand_path('..', __dir__)

# Runs asc.rb in a subprocess with Net::HTTP stubbed. `responses` is a list of
# {'code' => int, 'body' => hash} consumed in order. Yields the signing key,
# stdout, exit status, and the logged requests.
def run_asc(args, responses: [])
  Dir.mktmpdir do |dir|
    key = OpenSSL::PKey::EC.generate('prime256v1')
    key_path = File.join(dir, 'AuthKey_test-key.p8')
    File.write(key_path, key.to_pem)
    log = File.join(dir, 'requests.json')

    File.write(File.join(dir, 'stub.rb'), <<~RUBY)
      require 'net/http'
      require 'json'
      $responses = JSON.parse(#{responses.to_json.inspect})
      $log = []
      Net::HTTP.define_singleton_method(:start) do |_host, _port, **_opts, &blk|
        http = Object.new
        http.define_singleton_method(:request) do |req|
          $log << {
            'method' => req.method,
            'path' => req.uri.request_uri,
            'auth' => req['Authorization'],
            'body' => req.body
          }
          File.write(#{log.inspect}, JSON.pretty_generate($log))
          entry = $responses.shift || { 'code' => 500, 'body' => { 'error' => 'unstubbed request' } }
          res = Net::HTTPResponse.allocate
          res.instance_variable_set(:@code, entry['code'].to_s)
          res.instance_variable_set(:@read, true)
          res.instance_variable_set(:@body, entry['body'].to_json)
          def res.body = @body
          res
        end
        blk.call(http)
      end
    RUBY

    env = {
      'APP_STORE_CONNECT_API_KEY_ID' => 'test-key',
      'APP_STORE_CONNECT_API_KEY_ISSUER_ID' => 'issuer-1',
      'APP_STORE_CONNECT_API_KEY_PATH' => key_path,
      'BUNDLE_ID' => 'com.klaviyo.FlutterExample',
      'GITHUB_ENV' => File.join(dir, 'github_env')
    }
    out = IO.popen(env, ['ruby', '-r', File.join(dir, 'stub.rb'), File.join(SCRIPTS, 'asc.rb'), *args], err: File.join(dir, 'err.txt'), &:read)
    requests = File.exist?(log) ? JSON.parse(File.read(log)) : []
    github_env = File.exist?(env['GITHUB_ENV']) ? File.read(env['GITHUB_ENV']) : ''
    yield key, out, $CHILD_STATUS.exitstatus, requests, github_env
  end
end

def decode(segment)
  JSON.parse(Base64.urlsafe_decode64(segment))
end

# raw r||s (32 bytes each) -> DER, so OpenSSL can verify the JWT signature.
def raw_to_der(raw)
  r = OpenSSL::BN.new(raw.byteslice(0, 32), 2)
  s = OpenSSL::BN.new(raw.byteslice(32, 32), 2)
  OpenSSL::ASN1::Sequence([OpenSSL::ASN1::Integer(r), OpenSSL::ASN1::Integer(s)]).to_der
end

describe 'asc.rb' do
  describe 'JWT' do
    it 'signs a valid ES256 token with the expected header and claims' do
      apps = { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'app1' }] } }
      builds = { 'code' => 200, 'body' => { 'data' => [], 'links' => {} } }
      run_asc(['next-build-number'], responses: [apps, builds]) do |key, _out, rc, requests, _env|
        assert_equal 0, rc
        auth = requests.first['auth']
        assert_match(/^Bearer /, auth)
        header_b64, payload_b64, sig_b64 = auth.delete_prefix('Bearer ').split('.')

        header = decode(header_b64)
        assert_equal 'ES256', header['alg']
        assert_equal 'test-key', header['kid']
        assert_equal 'JWT', header['typ']

        claims = decode(payload_b64)
        assert_equal 'issuer-1', claims['iss']
        assert_equal 'appstoreconnect-v1', claims['aud']
        assert_in_delta Time.now.to_i + 1200, claims['exp'], 120

        raw = Base64.urlsafe_decode64(sig_b64)
        assert_equal 64, raw.bytesize
        digest = OpenSSL::Digest.new('SHA256')
        verified = key.verify(digest, raw_to_der(raw), "#{header_b64}.#{payload_b64}")
        assert verified, 'signature must verify against the signing key'
      end
    end
  end

  describe 'next-build-number' do
    it 'takes the numeric max across pages and ignores null/non-numeric versions' do
      apps = { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'app1' }] } }
      page1 = { 'code' => 200, 'body' => {
        'data' => [{ 'attributes' => { 'version' => '41' } },
                   { 'attributes' => { 'version' => nil } },
                   { 'attributes' => { 'version' => 'abc' } }],
        'links' => { 'next' => '/v1/builds?page=2' }
      } }
      page2 = { 'code' => 200, 'body' => {
        'data' => [{ 'attributes' => { 'version' => '7' } }],
        'links' => {}
      } }
      run_asc(['next-build-number'], responses: [apps, page1, page2]) do |_key, out, rc, requests, env|
        assert_equal 0, rc, out
        assert_equal "42\n", out
        assert_equal 3, requests.length
        assert_equal '/v1/builds?page=2', requests[2]['path']
        assert_match(/^ASC_APP_ID=app1/, env)
      end
    end

    it 'fails when no app matches the bundle id' do
      apps = { 'code' => 200, 'body' => { 'data' => [] } }
      run_asc(['next-build-number'], responses: [apps]) do |_key, _out, rc, _requests, _env|
        refute_equal 0, rc
      end
    end
  end

  describe 'set-whats-new' do
    let(:apps) { { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'app1' }] } } }
    let(:build) { { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'build1' }], 'links' => {} } } }

    it 'creates a betaBuildLocalization when none exists' do
      none = { 'code' => 200, 'body' => { 'data' => [] } }
      created = { 'code' => 201, 'body' => {} }
      Dir.mktmpdir do |dir|
        notes = File.join(dir, 'notes.txt')
        File.write(notes, "What to test\nLine two")
        run_asc(['set-whats-new', '9', notes], responses: [apps, build, none, created]) do |_key, out, rc, requests, _env|
          assert_equal 0, rc, out
          post = requests.last
          assert_equal 'POST', post['method']
          assert_equal '/v1/betaBuildLocalizations', post['path']
          body = JSON.parse(post['body'])
          assert_equal 'en-US', body.dig('data', 'attributes', 'locale')
          assert_equal "What to test\nLine two", body.dig('data', 'attributes', 'whatsNew')
          assert_equal 'build1', body.dig('data', 'relationships', 'build', 'data', 'id')
        end
      end
    end

    it 'patches the existing en-US localization when present' do
      existing = { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'loc1', 'attributes' => { 'locale' => 'en-US' } }] } }
      patched = { 'code' => 200, 'body' => {} }
      Dir.mktmpdir do |dir|
        notes = File.join(dir, 'notes.txt')
        File.write(notes, 'Updated notes')
        run_asc(['set-whats-new', '9', notes], responses: [apps, build, existing, patched]) do |_key, out, rc, requests, _env|
          assert_equal 0, rc, out
          patch = requests.last
          assert_equal 'PATCH', patch['method']
          assert_equal '/v1/betaBuildLocalizations/loc1', patch['path']
          assert_equal 'Updated notes', JSON.parse(patch['body']).dig('data', 'attributes', 'whatsNew')
        end
      end
    end
  end
end
