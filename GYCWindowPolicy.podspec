Pod::Spec.new do |spec|
  spec.name = 'GYCWindowPolicy'
  spec.version = '0.2.0-rc.6'
  spec.summary = 'iOS 播放窗口常亮与录屏遮罩策略'
  spec.homepage = 'https://github.com/gycrosskit/system-actions'
  spec.license = { :type => 'Apache-2.0', :file => 'LICENSE' }
  spec.author = { 'GY CrossKit' => 'https://github.com/gycrosskit' }
  spec.source = { :git => 'https://github.com/gycrosskit/system-actions.git', :tag => spec.version.to_s }
  spec.ios.deployment_target = '14.0'
  spec.swift_version = '5.9'
  spec.source_files = 'ios/Sources/GYCWindowPolicy/**/*.swift'
  spec.frameworks = 'UIKit'
end
