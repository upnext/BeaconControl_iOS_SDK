Pod::Spec.new do |s|
  s.name      = "BeaconCtrl"
  s.version   = "0.0.1"
  s.summary   = "Low Energy Bluetooth Framework"
  s.authors   = { "Upnext Ltd." => "http://www.up-next.com"}
  s.homepage  = "http://www.up-next.com/beacon"
  s.source    = { :git => "ssh://git@stash.up-next.com:7999/bp/bp-ios-sdk.git", :tag => "v#{s.version}" }
  s.license   = 'LICENSE*.*'
  
  s.platform              = :ios, '7.0'
  s.ios.deployment_target = '7.0'

  s.source_files          = "BeaconCtrl", "BeaconCtrl/**/*.{h,m}"
  s.private_header_files  = "BeaconCtrl/Private/*.h"

  s.frameworks = 'Foundation', 'CoreFoundation', 'CoreLocation', 'SystemConfiguration', 'MobileCoreServices', 'UIKit'
  s.weak_frameworks = 'Twitter', 'Social', 'Accounts'

  s.dependency "SAMCache"
  s.dependency "UNNetworking"
  s.dependency "KontaktSDK-OLD"

  s.requires_arc = true
end
