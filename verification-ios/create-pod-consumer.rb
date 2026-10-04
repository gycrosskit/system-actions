require 'xcodeproj'
require 'fileutils'

root = File.expand_path('..', __dir__)
output = File.join(root, 'build', 'pod-consumer')
FileUtils.mkdir_p(output)
FileUtils.cp(File.join(__dir__, 'Sources/WindowPolicyConsumer/Probe.swift'), output)
project = Xcodeproj::Project.new(File.join(output, 'WindowPolicyConsumer.xcodeproj'))
target = project.new_target(:framework, 'WindowPolicyConsumer', :ios, '14.0')
reference = project.main_group.new_file('Probe.swift')
target.source_build_phase.add_file_reference(reference)
target.build_configurations.each do |configuration|
  configuration.build_settings['SWIFT_VERSION'] = '5.9'
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'io.github.gycrosskit.WindowPolicyConsumer'
  configuration.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.save_as(project.path, 'WindowPolicyConsumer')
File.write(File.join(output, 'Podfile'), <<~PODFILE)
  platform :ios, '14.0'
  use_frameworks!
  project 'WindowPolicyConsumer.xcodeproj'
  target 'WindowPolicyConsumer' do
    pod 'GYCWindowPolicy', :git => 'https://github.com/gycrosskit/system-actions.git', :tag => '0.2.0-rc.2'
  end
PODFILE
puts output
