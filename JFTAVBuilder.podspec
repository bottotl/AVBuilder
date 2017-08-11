Pod::Spec.new do |s|

  s.name         = "JFTAVBuilder"
  s.version      = "1.0.0"
  s.summary      = "JFTAVBuilder"

  s.description  = <<-DESC
                   对视频提供编辑、合成、导出、滤镜功能
                   DESC

  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.homepage     = 'https://github.com/bottotl/AVBuilder'
  s.author       = { "jft0m" => "377632523@qq.com" }
  s.platform     = :ios, "8.0"

  s.source       = { :git => "git@github.com:bottotl/AVBuilder.git" }

  s.source_files = "Classes/**/*.{h,m,c}"
  s.resources    = "Assets/**/*"

end
