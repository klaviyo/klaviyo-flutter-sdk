#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal App Store Connect API client for the example app publish workflow.
# Uses only the Ruby standard library so it runs on the runner's system Ruby.
#
# Usage:
#   asc.rb next-build-number
#       Prints (highest CFBundleVersion ever uploaded for BUNDLE_ID) + 1 and
#       writes ASC_APP_ID=<id> to $GITHUB_ENV when set.
#   asc.rb set-whats-new <build-number> <notes-file>
#       Waits for the uploaded build to appear in App Store Connect, then sets
#       its en-US TestFlight "What to Test" text.
#
# Env:
#   APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_KEY_ISSUER_ID
#   BUNDLE_ID
#   APP_STORE_CONNECT_API_KEY_PATH (default: ~/.appstoreconnect/private_keys/AuthKey_<id>.p8)

require 'json'
require 'net/http'
require 'openssl'
require 'base64'
require 'uri'

API = 'https://api.appstoreconnect.apple.com'

def b64url(data)
  Base64.urlsafe_encode64(data, padding: false)
end

# ES256 JWT. OpenSSL returns a DER signature; JWS wants raw r||s (32 bytes each).
def token
  key_id = ENV.fetch('APP_STORE_CONNECT_API_KEY_ID')
  issuer = ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID')
  path = ENV.fetch('APP_STORE_CONNECT_API_KEY_PATH',
                   File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8"))
  key = OpenSSL::PKey::EC.new(File.read(path))
  now = Time.now.to_i
  header = b64url({ alg: 'ES256', kid: key_id, typ: 'JWT' }.to_json)
  payload = b64url({ iss: issuer, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' }.to_json)
  der = key.sign(OpenSSL::Digest.new('SHA256'), "#{header}.#{payload}")
  r, s = OpenSSL::ASN1.decode(der).value.map { |i| i.value.to_s(2).rjust(32, "\x00".b) }
  "#{header}.#{payload}.#{b64url(r + s)}"
end

def request(method, url, body = nil)
  uri = URI(url.start_with?('http') ? url : "#{API}#{url}")
  req = Net::HTTP.const_get(method.capitalize).new(uri)
  req['Authorization'] = "Bearer #{token}"
  if body
    req['Content-Type'] = 'application/json'
    req.body = body.to_json
  end
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  [res.code.to_i, res.body.to_s.empty? ? {} : JSON.parse(res.body)]
end

def get!(url)
  code, json = request('get', url)
  raise "ASC GET #{url}: HTTP #{code}\n#{JSON.pretty_generate(json)}" unless code.between?(200, 299)

  json
end

def app_id
  bundle_id = ENV.fetch('BUNDLE_ID')
  apps = get!("/v1/apps?filter[bundleId]=#{URI.encode_www_form_component(bundle_id)}&limit=1")
  raise "No App Store Connect app for bundle id #{bundle_id}. Create the listing first." if apps['data'].empty?

  apps['data'][0]['id']
end

def write_env(name, value)
  return unless ENV['GITHUB_ENV']

  File.open(ENV['GITHUB_ENV'], 'a') { |f| f.puts "#{name}=#{value}" }
end

def next_build_number
  id = app_id
  write_env('ASC_APP_ID', id)
  highest = 0
  # `version` is a string and uploadedDate can be null, so page through every
  # build and take the numeric max instead of trusting the API's sort.
  url = "/v1/builds?filter[app]=#{id}&fields[builds]=version&limit=200"
  while url
    page = get!(url)
    page['data'].each { |b| highest = [highest, b['attributes']['version'].to_i].max }
    url = page.dig('links', 'next')
  end
  warn "Highest build number in App Store Connect: #{highest}"
  puts highest + 1
end

def set_whats_new(build_number, notes_file)
  notes = File.read(notes_file).strip
  id = app_id
  build = nil
  # Builds usually appear within a few minutes of altool finishing.
  60.times do
    page = get!("/v1/builds?filter[app]=#{id}&filter[version]=#{build_number}&limit=1")
    build = page['data'].first
    break if build

    warn "Build #{build_number} not visible in App Store Connect yet; waiting…"
    sleep 30
  end
  raise "Build #{build_number} never appeared in App Store Connect" unless build

  existing = get!("/v1/builds/#{build['id']}/betaBuildLocalizations")['data']
                .find { |l| l['attributes']['locale'] == 'en-US' }
  if existing
    code, json = request('patch', "/v1/betaBuildLocalizations/#{existing['id']}",
                         { data: { type: 'betaBuildLocalizations', id: existing['id'],
                                   attributes: { whatsNew: notes } } })
  else
    code, json = request('post', '/v1/betaBuildLocalizations',
                         { data: { type: 'betaBuildLocalizations',
                                   attributes: { locale: 'en-US', whatsNew: notes },
                                   relationships: { build: { data: { type: 'builds', id: build['id'] } } } } })
  end
  raise "Could not set What to Test: HTTP #{code}\n#{JSON.pretty_generate(json)}" unless code.between?(200, 299)

  warn "Set What to Test for build #{build_number}"
end

case ARGV[0]
when 'next-build-number' then next_build_number
when 'set-whats-new' then set_whats_new(ARGV.fetch(1), ARGV.fetch(2))
else
  warn 'usage: asc.rb next-build-number | set-whats-new <build-number> <notes-file>'
  exit 2
end
