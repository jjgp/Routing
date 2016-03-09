Pod::Spec.new do |s|
  s.name             = "Routing"
  s.version          = "0.2.0"
  s.summary          = "A swift router implementation"
  s.description      = <<-DESC
                        Routing allows for routing URLs matched by string patterns to associated closures.
                        DESC
  s.homepage         = "https://github.com/jwalapr/Routing"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Jason Prasad" => "jwalapr@gmail.com" }
  s.source           = { :git => "https://github.com/jwalapr/Routing.git", :tag => s.version.to_s }
  s.requires_arc = true

  s.default_subspec = 'iOS'
  s.subspec 'iOS' do |sp|
    sp.ios.deployment_target = '9.0'
    sp.frameworks   = 'UIKit', 'QuartzCore'
    sp.source_files = 'Source/Routing.swift', 'Source/RoutingiOS.swift'
  end

  s.subspec 'Other' do |sp|
    sp.tvos.deployment_target = '9.0'
    sp.watchos.deployment_target = '2.1'
    sp.osx.deployment_target = '10.11'
    sp.source_files = 'Source/Routing.swift', 'Source/RoutingOthers.swift'
  end

end
