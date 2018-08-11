Pod::Spec.new do |s|

  s.name         = "SuperCache"
  s.version      = "0.0.1"
  s.summary      = "Extremely fast cache written in Swift."

  s.homepage     = "https://github.com/jianstm/SuperCache"
  s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "QuentinJin" => "jianstm@gmail.com" }

  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.12"

  s.source       = { :git => "https://github.com/jianstm/SuperCache.git",
                     :tag => "#{s.version}" }

  s.source_files = "Sources/SuperCache/*.swift"
  s.requires_arc = true

  s.swift_version= "4.0"
end
