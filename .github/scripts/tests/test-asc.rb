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

# Runs asc.rb against a stateful in-memory App Store Connect: `builds` are real
# records ({id, app, marketing, version}) and a GET /v1/builds applies the
# filter[app], filter[preReleaseVersion.version], filter[version] and limit
# params it receives, so a lookup that drops a filter returns the wrong build
# and the test fails on behavior, not on the query string.
def run_asc_stateful(args, builds:, localizations: {})
  Dir.mktmpdir do |dir|
    key = OpenSSL::PKey::EC.generate('prime256v1')
    key_path = File.join(dir, 'AuthKey_test-key.p8')
    File.write(key_path, key.to_pem)
    log = File.join(dir, 'requests.json')
    File.write(File.join(dir, 'stub.rb'), <<~'RUBY')
      require 'net/http'
      require 'json'
      require 'uri'
      $builds = JSON.parse(ENV.fetch('STUB_BUILDS'))
      $locs = JSON.parse(ENV.fetch('STUB_LOCS'))
      $log = []
      def respond(code, body)
        res = Net::HTTPResponse.allocate
        res.instance_variable_set(:@code, code.to_s)
        res.instance_variable_set(:@read, true)
        res.instance_variable_set(:@body, body.to_json)
        def res.body = @body
        res
      end
      Net::HTTP.define_singleton_method(:start) do |_host, _port, **_opts, &blk|
        http = Object.new
        http.define_singleton_method(:request) do |req|
          uri = req.uri
          $log << { 'method' => req.method, 'path' => uri.request_uri, 'body' => req.body }
          File.write(ENV.fetch('STUB_LOG'), JSON.pretty_generate($log))
          q = URI.decode_www_form(uri.query.to_s).to_h
          path = uri.path
          if path == '/v1/apps'
            respond(200, { 'data' => [{ 'id' => 'app1' }] })
          elsif path == '/v1/builds'
            rows = $builds.select do |b|
              (q['filter[app]'].nil? || b['app'] == q['filter[app]']) &&
                (q['filter[preReleaseVersion.version]'].nil? || b['marketing'] == q['filter[preReleaseVersion.version]']) &&
                (q['filter[version]'].nil? || b['version'] == q['filter[version]'])
            end
            rows = rows.first(q['limit'].to_i) if q['limit']
            respond(200, { 'data' => rows.map { |b| { 'id' => b['id'], 'attributes' => { 'version' => b['version'] } } }, 'links' => {} })
          elsif path =~ %r{\A/v1/builds/([^/]+)/betaBuildLocalizations\z}
            respond(200, { 'data' => ($locs[$1] || []) })
          elsif path == '/v1/betaBuildLocalizations'
            respond(201, {})
          else
            respond(404, { 'error' => 'unexpected ' + path })
          end
        end
        blk.call(http)
      end
    RUBY
    env = {
      'APP_STORE_CONNECT_API_KEY_ID' => 'test-key',
      'APP_STORE_CONNECT_API_KEY_ISSUER_ID' => 'issuer-1',
      'APP_STORE_CONNECT_API_KEY_PATH' => key_path,
      'BUNDLE_ID' => 'com.klaviyo.FlutterExample',
      'GITHUB_ENV' => File.join(dir, 'github_env'),
      'STUB_BUILDS' => builds.to_json,
      'STUB_LOCS' => localizations.to_json,
      'STUB_LOG' => log
    }
    out = IO.popen(env, ['ruby', '-r', File.join(dir, 'stub.rb'), File.join(SCRIPTS, 'asc.rb'), *args], err: File.join(dir, 'err.txt'), &:read)
    requests = File.exist?(log) ? JSON.parse(File.read(log)) : []
    err = File.exist?(File.join(dir, 'err.txt')) ? File.read(File.join(dir, 'err.txt')) : ''
    yield out, $CHILD_STATUS.exitstatus, requests, err
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

describe 'asc.rb against a stateful App Store Connect' do
  # Build 9 exists under both versions; the older one is listed first, so a lookup
  # that ignores the marketing version selects it.
  let(:builds) do
    [
      { 'id' => 'old-9', 'app' => 'app1', 'marketing' => '0.3.1', 'version' => '9' },
      { 'id' => 'old-12', 'app' => 'app1', 'marketing' => '0.3.1', 'version' => '12' },
      { 'id' => 'new-9', 'app' => 'app1', 'marketing' => '0.3.2', 'version' => '9' },
      { 'id' => 'other-app-30', 'app' => 'app2', 'marketing' => '0.3.2', 'version' => '30' }
    ]
  end

  it 'numbers a marketing version from its own builds only' do
    run_asc_stateful(['next-build-number', '0.3.2'], builds: builds) do |out, rc, _requests|
      assert_equal 0, rc
      assert_equal "10\n", out
    end
    run_asc_stateful(['next-build-number', '0.3.1'], builds: builds) do |out, _rc, _requests|
      assert_equal "13\n", out
    end
    run_asc_stateful(['next-build-number', '9.9.9'], builds: builds) do |out, _rc, _requests|
      assert_equal "1\n", out
    end
  end

  it 'writes What to Test onto the build of the right marketing version' do
    Dir.mktmpdir do |dir|
      notes = File.join(dir, 'notes.txt')
      File.write(notes, 'hello')
      run_asc_stateful(['set-whats-new', '0.3.2', '9', notes], builds: builds) do |_out, rc, requests|
        assert_equal 0, rc
        post = requests.find { |r| r['method'] == 'POST' && r['path'] == '/v1/betaBuildLocalizations' }
        refute_nil post
        assert_equal 'new-9', JSON.parse(post['body']).dig('data', 'relationships', 'build', 'data', 'id')
      end
    end
  end

  it 'never picks a build of another app that has the same number' do
    other = [{ 'id' => 'other-9', 'app' => 'app2', 'marketing' => '0.3.2', 'version' => '9' }] + builds
    Dir.mktmpdir do |dir|
      notes = File.join(dir, 'notes.txt')
      File.write(notes, 'hello')
      run_asc_stateful(['set-whats-new', '0.3.2', '9', notes], builds: other) do |_out, _rc, requests|
        post = requests.find { |r| r['method'] == 'POST' && r['path'] == '/v1/betaBuildLocalizations' }
        assert_equal 'new-9', JSON.parse(post['body']).dig('data', 'relationships', 'build', 'data', 'id')
      end
    end
  end

  it 'requires a marketing version for next-build-number, with no fallback to the global highest' do
    run_asc_stateful(['next-build-number'], builds: builds) do |out, rc, _requests|
      refute_equal 0, rc
      refute_match(/\A\d+\n\z/, out)
    end
  end

  it 'rejects a marketing version with a suffix before any request, for both lookups' do
    Dir.mktmpdir do |dir|
      notes = File.join(dir, 'notes.txt')
      File.write(notes, 'x')
      ['0.3.2-alpha.1', '0.3.2+build.5', 'v0.3.2', '1.2.3.4', 'abc', ' '].each do |bad|
        run_asc_stateful(['next-build-number', bad], builds: builds) do |_out, rc, requests, err|
          refute_equal 0, rc, "next-build-number accepted #{bad.inspect}"
          assert_match(/marketing version must be numeric/, err)
          assert_empty requests
        end
        run_asc_stateful(['set-whats-new', bad, '9', notes], builds: builds) do |_out, rc, requests, _err|
          refute_equal 0, rc, "set-whats-new accepted #{bad.inspect}"
          assert_empty requests
        end
      end
    end
  end

  it 'accepts one, two and three component marketing versions' do
    run_asc_stateful(['next-build-number', '1'], builds: builds) { |_out, rc, _r, _e| assert_equal 0, rc }
    run_asc_stateful(['next-build-number', '1.2'], builds: builds) { |_out, rc, _r, _e| assert_equal 0, rc }
    run_asc_stateful(['next-build-number', '0.3.2'], builds: builds) { |_out, rc, _r, _e| assert_equal 0, rc }
  end

  it 'rejects a non-numeric build number for What to Test before any request' do
    Dir.mktmpdir do |dir|
      notes = File.join(dir, 'notes.txt')
      File.write(notes, 'x')
      ['latest', '', '9a'].each do |bad|
        run_asc_stateful(['set-whats-new', '0.3.2', bad, notes], builds: builds) do |_out, rc, requests, _err|
          refute_equal 0, rc, "set-whats-new accepted build #{bad.inspect}"
          assert_empty requests
        end
      end
    end
  end

  it 'says what is missing instead of crashing, and sends no request' do
    run_asc_stateful(['next-build-number'], builds: builds) do |_out, rc, requests, err|
      refute_equal 0, rc
      assert_match(/requires a marketing version/, err)
      assert_empty requests
    end
    run_asc_stateful(['next-build-number', ''], builds: builds) do |_out, rc, requests|
      refute_equal 0, rc
      assert_empty requests
    end
  end
end

describe 'asc.rb' do
  describe 'JWT' do
    it 'signs a valid ES256 token with the expected header and claims' do
      apps = { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'app1' }] } }
      builds = { 'code' => 200, 'body' => { 'data' => [], 'links' => {} } }
      run_asc(['next-build-number', '0.3.1'], responses: [apps, builds]) do |key, _out, rc, requests, _env|
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
    it 'filters builds by marketing version and pages' do
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
      run_asc(['next-build-number', '0.3.1'], responses: [apps, page1, page2]) do |_key, out, rc, requests, env|
        assert_equal 0, rc, out
        assert_equal "42\n", out
        assert_equal 3, requests.length
        assert_includes requests[1]['path'], 'filter[preReleaseVersion.version]=0.3.1'
        assert_equal '/v1/builds?page=2', requests[2]['path']
        assert_match(/^ASC_APP_ID=app1/, env)
      end
    end

    it 'returns 1 when the marketing version has no builds yet' do
      apps = { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'app1' }] } }
      none = { 'code' => 200, 'body' => { 'data' => [], 'links' => {} } }
      run_asc(['next-build-number', '9.9.9'], responses: [apps, none]) do |_key, out, rc, _requests, _env|
        assert_equal 0, rc, out
        assert_equal "1\n", out
      end
    end

    it 'fails when no app matches the bundle id' do
      apps = { 'code' => 200, 'body' => { 'data' => [] } }
      run_asc(['next-build-number', '0.3.1'], responses: [apps]) do |_key, _out, rc, _requests, _env|
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
        run_asc(['set-whats-new', '0.3.2', '9', notes], responses: [apps, build, none, created]) do |_key, out, rc, requests, _env|
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

    it 'looks the build up by marketing version as well as build number' do
      none = { 'code' => 200, 'body' => { 'data' => [] } }
      created = { 'code' => 201, 'body' => {} }
      Dir.mktmpdir do |dir|
        notes = File.join(dir, 'notes.txt')
        File.write(notes, 'x')
        run_asc(['set-whats-new', '0.3.2', '9', notes], responses: [apps, build, none, created]) do |_key, out, rc, requests, _env|
          assert_equal 0, rc, out
          lookup = requests.find { |r| r['path'].start_with?('/v1/builds?') }
          refute_nil lookup
          assert_includes lookup['path'], 'filter[preReleaseVersion.version]=0.3.2'
          assert_includes lookup['path'], 'filter[version]=9'
          assert_includes lookup['path'], 'filter[app]=app1'
        end
      end
    end

    it 'passes a prerelease-free marketing version, never the full SDK version' do
      none = { 'code' => 200, 'body' => { 'data' => [] } }
      created = { 'code' => 201, 'body' => {} }
      Dir.mktmpdir do |dir|
        notes = File.join(dir, 'notes.txt')
        File.write(notes, 'x')
        run_asc(['set-whats-new', '0.3.2', '12', notes], responses: [apps, build, none, created]) do |_key, _out, rc, requests, _env|
          assert_equal 0, rc
          lookup = requests.find { |r| r['path'].start_with?('/v1/builds?') }
          refute_includes lookup['path'], 'alpha'
        end
      end
    end

    it 'fails without a marketing version argument' do
      Dir.mktmpdir do |dir|
        notes = File.join(dir, 'notes.txt')
        File.write(notes, 'x')
        run_asc(['set-whats-new', '9', notes], responses: [apps, build]) do |_key, _out, rc, _requests, _env|
          refute_equal 0, rc
        end
      end
    end

    it 'patches the existing en-US localization when present' do
      existing = { 'code' => 200, 'body' => { 'data' => [{ 'id' => 'loc1', 'attributes' => { 'locale' => 'en-US' } }] } }
      patched = { 'code' => 200, 'body' => {} }
      Dir.mktmpdir do |dir|
        notes = File.join(dir, 'notes.txt')
        File.write(notes, 'Updated notes')
        run_asc(['set-whats-new', '0.3.2', '9', notes], responses: [apps, build, existing, patched]) do |_key, out, rc, requests, _env|
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
