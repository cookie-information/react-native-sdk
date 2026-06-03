require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'CookieInformationRNSDK'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = {
    :ios => '15.1',
    :tvos => '15.1'
  }
  s.swift_version  = '5.4'
  s.source         = { git: 'https://github.com/cookie-information/react-native-sdk' }
  s.static_framework = true

  s.dependency 'React-Core'
  s.dependency 'MobileConsentsSDK', '1.5.8'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
  s.exclude_files = "Tests/**/*"

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/*Tests.swift'
    test_spec.platforms = { :ios => '15.1' }
    test_spec.requires_app_host = true
  end
end
