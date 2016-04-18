
#BeaconControl
##Integration Guide ver. 1.0
###Revision History


Date       |Revision     |Description
-----------|-------------|-----------
10.07.2015 |    1.0      |Added BeaconCtrl usage guide. Added BeaconControl iOS SDK integration guide.
15.10.2015 |    1.1      |Switched to publicly available podspec version of UNNetworking. Bug fixes.
14.04.2016 |    1.2      |Added support to override hosting default base URL. Fixed issues with beacons ranging and events cache.

###Overview

BeaconControl is your free entry to the beacon world. It's an open source platform that lets your applications sense the world around them. Beacons provide context-rich information to a user’s device upon entering the range of a specific beacon. BeaconControl allows you to set-up predefined triggers and actions for each beacon. For example, when a “listening” mobile device walks by a beacon, you can configure your app to send notifications, trigger URL openings, or deliver content.

In order to use BeaconCtrl you will need to:

1. Setup your beacon infrastructure (with the help of BeaconControl iOS App - link needed!) and configure actions triggered in your mobile applications. 
2. Integrate the BeaconControl SDK with an application.


### BeaconControl Architechture Description

BeaconControl SDK provides intuitive interfaces for interaction with two APIs provided by BeaconControl: Client API and Server-to-Server API (S2S API).

Main public interfaces (refer to the efficial documentation for more detailed information):

BCLBeaconCtrl - the main interface for interaction with the Client API. You'll use it to authenticate your mobile application against the backend, fetch beacon and action configurations, respond to beacon events etc.

BCLBeaconCtrlAdmin - the main interface for interaction with the S2S API. You'll use it to authorize as an admin user, create beacons, zones and actions, update them, etc.

BCLRange - the BeaconCtrl SDK class that corresponds to your phisical beacons. You'll use it to get information about your beacons and update it using BCLBeaconCtrlAdmin

BCLZone - zone corresponds to a group of beacons in BeaconCtrl. You can use them to describe larger phisical areas, covered with many beacons. Other than that, zones behave similarly to beacons, e.g. you can also define actions for them. BCLZone is the interface that describes zones in BeaconCtrl. You'll use it to retrieve information about zones and change it using BCLBeaconCtrlAdmin

BCLAction - this is the BeaconCtrl class that corresponds to actions that you can assign to your beacons or zones. There are several types of actions, some of them are handled automatically by the SDK (but you can always override the default behavior), some are left for the developer to handle. You can use this class to get information about your actions, e.g. to show them to your mobile users

BCLConfiguration - each mobile application has a configurations of beacons, zones and actions that it uses. This is the class that describes such an app configuration. You'll use it to get detailed information about your configuration, e.g. the number of beacons (and their details information) it interacts with, etc.

BCLBeaconCtrlDelegate - this is a protocol that you'll implement in your interfaces to respond to BeaconControl SDK events. You'll get called each time an action is just about to be triggered, when the closest beacon or the current zone have changed, etc. You can also use this protocol to let the SDK know, which exact actions you want it to handle automatically and which you want to deal with on your own.


###Beacons Infrastructure Setup

1. Create your BeaconControl account at www.beaconctrl.com
2. Download the BeaconControl mobile application from the App Store
3. Log in to the application using your e-mail and password
4. Add your beacons using the application or BeaconControl Admin Panel (UUID, Minor i Major numbers are essential to identify your beacons and are provided by their producer)
5. Use BeaconControl test notifications to check your setup on the BeaconControl mobile application
6. Create a folder of your new application using BeaconControl Admin Panel (Applications)
7. Copy the automatically generatedClient ID and Client Secret from the application settings in the Admin Panel
8. Follow the below SDK integration instructions to start interacting with your beacons in your new mobile application


###Beacon OS iOS SDK Integration

1. It's easiest to integrate BeaconControl iOS SDK using CocoaPods. The name of the pod is just "BeaconControl"
2. Add ``NSLocationWhenInUseUsageDescription`` and ``NSLocationAlwaysUsageDescription`` keys to project’s Info.plist file.
3. In case of a self-hosted BeaconControl environment, you'll need to add the ``BCLBaseURLAPI`` key to project's Info.plist file in order to override the default base url. 
4. Import BeaconControl iOS SDK headers into project’s source code and create a variable or property which will keep strong reference to ``BCLBeaconCtrl`` or ``BCLBeaconCtrlAdmin`` object.
5. Initialise BeaconControl object:
````objc
[BCLBeaconCtrl setupBeaconCtrlWithClientId:<YOUR CLIENT ID GOES HERE> 
                              clientSecret:<YOUR CLIENT SECRET GOES HERE> 
                                    userId:email 
                           pushEnvironment: <SELECT YOUR PUSH ENVIRONMENT> 
                                 pushToken:<YOUR PUSH TOKEN GOES HERE, IF APPLICABLE> 
                                completion:^(BCLBeaconCtrl *beaconCtrl, BOOL isRestoredFromCache, NSError *error) {
                       <HERE BEACONCTRL SHOULD ALREADY BE SET UP>
	                    beaconCtrl.delegate = <SOME OBJECT>
                   }];
````
6. You can now start reacting to BCLBeaconCtrl actions in your delegate object. Some actions are handled automatically (refer to FAQ and docs for more info):

````objc
- (void)closestObservedRangeDidChange:(BCLRange *)closestRange
{
    ///<YOUR CODE GOES HERE>
}

- (void)currentZoneDidChange:(BCLZone *)currentZone
{
    ///<YOUR CODE GOES HERE>
}

- (void)didChangeObservedRanges:(NSSet *)newObservedRanges
{
    ///<YOUR CODE GOES HERE>
}

- (BOOL)shouldAutomaticallyPerformAction:(BCLAction *)action
{
    ///<YOUR CODE GOES HERE>
}

- (void)willPerformAction:(BCLAction *)action
{
    ///<YOUR CODE GOES HERE>
}

- (void) didPerformAction:(BCLAction *)action
{
    ///<YOUR CODE GOES HERE>
}

````
7. You can use BCLBeaconCtrlAdmin to interact with BeaconCtrl S2S API. Just store a reference to a BCLBeaconCtrlAdmin object in a variable or property.
8. Refer to BCLBeaconCtrlAdmin class documentation for detailed information about its usage.
