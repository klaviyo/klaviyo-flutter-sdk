require 'yaml'
pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))

Pod::Spec.new do |s|
  s.name             = 'klaviyo_flutter_sdk'
  s.version          = pubspec['version']
  s.summary          = 'A Flutter plugin for Klaviyo SDK integration'
  s.description      = <<-DESC
A Flutter plugin that provides a wrapper around the native Klaviyo SDKs for iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/klaviyo/klaviyo-flutter-sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Klaviyo' => 'support@klaviyo.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.resources        = ['klaviyo-sdk-configuration.plist']

  s.dependency 'Flutter'
  s.dependency 'KlaviyoSwift', '~> 5.2.1'
  # Forms: included by default, set to 'false' to exclude
  if ENV['KLAVIYO_INCLUDE_FORMS'] != 'false'
    s.dependency 'KlaviyoForms', '~> 5.2.1'
  end

  # Conditional location dependency based on environment variable
  # Default is FALSE (opt-in for geofencing)
  include_location = ENV['KLAVIYO_INCLUDE_LOCATION'] == 'true'
  if include_location
    s.dependency 'KlaviyoLocation', '~> 5.2.1'
  end

  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
