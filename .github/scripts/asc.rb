#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal App Store Connect API client for the example app publish workflow.
# Uses only the Ruby standard library so it runs on the runner's system Ruby.
#
# Usage:
#   asc.rb next-build-number <marketing-version>
#       Prints (highest CFBundleVersion uploaded for BUNDLE_ID with that
#       marketing version) + 1 — build numbers restart per marketing version —
#       and writes ASC_APP_ID=<id> to $GITHUB_ENV when set.
#   asc.rb set-whats-new <marketing-version> <build-number> <notes-file>
#       Waits for that build of that marketing version to appear in App Store
#       Connect, then sets its en-US TestFlight "What to Test" text. The
#       marketing version is part of the lookup because build numbers restart
#       for each marketing version.
#
# Env:
#   APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_KEY_ISSUER_ID
#   BUNDLE_ID
#   APP_STORE_CONNECT_API_KEY_PATH (default: ~/.appstoreconnect/private_keys/AuthKey_<id>.p8)
#   ASC_API_ROOT (default: https://api.appstoreconnect.apple.com; tests stub it)

require 'json'
require 'net/http'
require 'openssl'
require 'base64'
require 'uri'

API = ENV.fetch('ASC_API_ROOT', 'https://api.appstoreconnect.apple.com')

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

# App Store Connect's preReleaseVersion.version holds the numeric marketing
# version (0.3.2), never the SDK version with a prerelease suffix (0.3.2-alpha.1),
# so a lookup that sends the suffix finds nothing. Fail now instead of waiting
# out the processing timeout.
def require_marketing_version!(value)
  return value if value.to_s.match?(/\A\d+(\.\d+){0,2}\z/)

  abort "marketing version must be numeric X[.Y[.Z]] with no prerelease or build suffix, got #{value.to_s.inspect}"
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

def next_build_number(marketing_version)
  require_marketing_version!(marketing_version)
  id = app_id
  write_env('ASC_APP_ID', id)
  highest = 0
  # `version` is a string and uploadedDate can be null, so page through the
  # marketing version's builds and take the numeric max instead of trusting
  # the API's sort. The preReleaseVersion filter keeps other marketing
  # versions' build numbers out of the count.
  url = "/v1/builds?filter[app]=#{id}&filter[preReleaseVersion.version]=#{URI.encode_www_form_component(marketing_version)}&fields[builds]=version&limit=200"
  while url
    page = get!(url)
    page['data'].each { |b| highest = [highest, b['attributes']['version'].to_i].max }
    url = page.dig('links', 'next')
  end
  warn "Highest build number for #{marketing_version} in App Store Connect: #{highest}"
  puts highest + 1
end

def set_whats_new(marketing_version, build_number, notes_file)
  require_marketing_version!(marketing_version)
  abort "build number must be numeric, got #{build_number.inspect}" unless build_number.to_s.match?(/\A\d+\z/)
  notes = File.read(notes_file).strip
  id = app_id
  build = nil
  # Build numbers restart for each marketing version, so the same number can
  # exist under an older version; the lookup must name both.
  filters = "filter[app]=#{id}&filter[preReleaseVersion.version]=#{URI.encode_www_form_component(marketing_version)}" \
            "&filter[version]=#{build_number}&limit=1"
  # Builds usually appear within a few minutes of altool finishing.
  60.times do
    page = get!("/v1/builds?#{filters}")
    build = page['data'].first
    break if build

    warn "Build #{marketing_version} (#{build_number}) not visible in App Store Connect yet; waiting…"
    sleep 30
  end
  raise "Build #{marketing_version} (#{build_number}) never appeared in App Store Connect" unless build

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

  warn "Set What to Test for build #{marketing_version} (#{build_number})"
end

case ARGV[0]
when 'next-build-number'
  # Build numbers restart for each marketing version, so there is no global fallback.
  abort 'next-build-number requires a marketing version' if ARGV[1].to_s.empty?
  next_build_number(ARGV[1])
when 'set-whats-new'
  abort 'set-whats-new requires <marketing-version> <build-number> <notes-file>' if ARGV[1..3].to_a.any? { |a| a.to_s.empty? } || ARGV.length < 4
  set_whats_new(ARGV[1], ARGV[2], ARGV[3])
else
  warn 'usage: asc.rb next-build-number <marketing-version> | set-whats-new <marketing-version> <build-number> <notes-file>'
  exit 2
end
