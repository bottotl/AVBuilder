Pod::Spec.new do |s|

  s.name         = "JFTAVBuilder"
  s.version      = "1.0.2"
  s.summary      = "JFTAVBuilder with Metal rendering for better memory management"

  s.description  = <<-DESC
                   对视频提供编辑、合成、导出、滤镜功能
                   Now with Metal rendering support for improved memory management and performance.
                   DESC

  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.homepage     = 'https://github.com/bottotl/AVBuilder'
  s.author       = { "jft0m" => "377632523@qq.com" }
  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/bottotl/AVBuilder.git", :tag => "1.0.2" }

  s.source_files = "Classes/**/*.{h,m,c,metal}"
  s.resources    = "Assets/**/*"

  # Configure Metal shader compilation and bundling
  s.resource_bundle = { 'JFTAVBuilderMetalShaders' => 'Assets/.metal_placeholder' }
  s.pod_target_xcconfig = {
    'METAL_LIBRARY_OUTPUT_DIR' => '${TARGET_BUILD_DIR}/JFTAVBuilderMetalShaders.bundle/'
  }

  # Framework dependencies
  s.frameworks = 'Metal', 'MetalKit', 'AVFoundation', 'CoreImage', 'CoreVideo'

end
