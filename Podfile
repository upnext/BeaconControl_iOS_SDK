source 'https://github.com/CocoaPods/Specs.git'
source 'git@github.com:upnext/Specs.git'

platform :ios, '7.0'

xcodeproj 'BeaconCtrl.xcodeproj'

target "BeaconCtrl", :exclusive => true do
	link_with "BeaconCtrl"
	pod "UNNetworking", :git => "ssh://git@stash.up-next.com:7999/var/unnetworking.git", :branch => :master
	pod "SAMCache"
end
