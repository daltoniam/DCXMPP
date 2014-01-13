Pod::Spec.new do |s|
  s.name         = "DCXMPP"
  s.version      = "0.0.1"
  s.summary      = "XMPP library for iOS or OSX in objective-c. Uses BOSH and supports group chat."
  s.homepage     = "https://github.com/daltoniam/RestReaper"
  s.license      = 'Apache License, Version 2.0'
  s.author       = { "Dalton Cherry" => "daltoniam@gmail.com" }
  s.source       = { :git => "https://github.com/daltoniam/DCXMPP.git", :tag => '0.0.1' }
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.source_files = '*.{h,m}'
  s.dependency 'XMLKit' #still need to add XMLKit to cooca pods
  s.requires_arc = true
end