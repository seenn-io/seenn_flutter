Pod::Spec.new do |s|
  s.name             = 'seenn_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Seenn Flutter SDK for real-time job tracking'
  s.description      = <<-DESC
A Flutter plugin for integrating with Seenn job tracking service.
Provides real-time updates for job progress via polling.
                       DESC
  s.homepage         = 'https://seenn.io'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Seenn' => 'hello@seenn.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
