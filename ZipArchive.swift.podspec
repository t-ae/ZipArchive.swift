Pod::Spec.new do |s|
  s.name = "ZipArchive.swift"
  s.version = "0.1.3"
  s.summary = "Zip archiving library written in Swift."
  s.homepage = "https://github.com/yaslab/ZipArchive.swift"
  s.license = "MIT"
  s.author = { "Yasuhiro Hatta" => "hatta.yasuhiro@gmail.com" }
  s.source = { :git => "https://github.com/yaslab/ZipArchive.swift.git", :tag => s.version, :submodules => true }
  #s.social_media_url = 'https://twitter.com/...'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'
  s.requires_arc = true

  s.source_files = 'Sources/ZipArchive/*.swift', 'Sources/CMinizip/*.c', 'Sources/CMinizip/include/*.h'
  #s.private_header_files = 'Minizip/*.h'
  #s.frameworks = 'Foundation'
  s.libraries = 'z'
  s.module_name = 'ZipArchive'

  #s.module_map = "Source/module.modulemap"

  s.xcconfig = { 'SWIFT_INCLUDE_PATHS' => '$(PODS_ROOT)/ZipArchive.swift/Sources/CMinizip' }

  s.compiler_flags = '-DUSE_FILE32API'

  s.preserve_paths = 'Sources/CMinizip/module.modulemap'
end
