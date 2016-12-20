//
//  BCLBeaconCtrl.h
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLAction.h"
#import "BCLConfiguration.h"
#import "BCLBeaconCtrlDelegate.h"
#import "BCLEncodableObject.h"
#import "BCLBeacon.h"

extern NSInteger const BCLInvalidParametersErrorCode;
extern NSInteger const BCLInvalidDataErrorCode;
extern NSInteger const BCLErrorHTTPError;
extern NSInteger const BCLInvalidDeviceConfigurationError;
extern NSString * const BCLBluetoothNotTurnedOnErrorKey;
extern NSString * const BCLDeniedMonitoringErrorKey;
extern NSString * const BCLDeniedLocationServicesErrorKey;
extern NSString * const BCLDeniedBackgroundAppRefreshErrorKey;
extern NSString * const BCLDeniedNotificationsErrorKey;
extern NSString * const BCLErrorDomain;

@protocol BCLExtension;

/*!
 * @typedef BCLBeaconCtrlPushEnvironment
 * @brief A list of possible push environments
 * @constant BCLBeaconCtrlPushEnvironmentNone is for application builds that don't have any push environment set up
 * @constant BCLBeaconCtrlPushEnvironmentSandbox is for debug builds of applications with set up sandbox push environments
 * @constant BCLBeaconCtrlPushEnvironmentProduction is for production builds of applications with set up production push environments
*/
typedef NS_ENUM(NSUInteger, BCLBeaconCtrlPushEnvironment) {
    BCLBeaconCtrlPushEnvironmentNone,
    BCLBeaconCtrlPushEnvironmentSandbox,
    BCLBeaconCtrlPushEnvironmentProduction
};

/*!
 * A BCLBeaconCtrl singleton is the main point of interaction with BeaconCtrl Client API
 */
@interface BCLBeaconCtrl : BCLEncodableObject

/** @name Properties */

/// A reference to beacons', zones' and actions' configuration fetched from the backend
@property (nonatomic, strong) BCLConfiguration *configuration;

/// Processing status. YES if processing is paused.
@property (assign) BOOL paused;

/// client id obtained from the admin panel for authentication
@property (copy, nonatomic, readonly) NSString *clientId;

/// client secret obtained from the admin panel for authentication
@property (copy, nonatomic, readonly) NSString *clientSecret;

/// an arbitrary string identifier for an app user. given as a parameter during the setup
@property (copy, nonatomic, readonly) NSString *userId;

/// A set of beacons that are currently monitored by the SDK
@property (nonatomic, copy, readonly) NSSet *observedBeacons;

/// a weak reference to the delegate
@property (weak) id <BCLBeaconCtrlDelegate> delegate;

/** @name Methods */

/*!
 * @brief Check, if bluetooth is turned on
 * @return YES, if bluetooth is turned on
 */
- (BOOL)isBluetoothTurnedOn;

/*!
 * @brief Check, if the current device supports monitoring beacons
 * @return YES, if the current device supports monitoring beacons
 */
- (BOOL)isBeaconMonitoringAvailable;

/*!
 * @brief Check, if the location services are turned on for the current app
 * @return Yes, if the location services are turned on for the current app
 */
- (BOOL)isLocationServicesAvailable;

/*!
 * @brief Check, if background app refresh is turned on for the current app
 * @return Yes, if background app refresh is turned on for the current app
 */
- (BOOL)isBackgroundAppRefreshAvailable;

/*!
 * @brief Check, if notifications are turned on for the current app
 * @return Yes, if notifications are turned on for the current app
 */
- (BOOL)isNotificationsAvailable;

/*!
 * @brief Check, if the current device and the running app are capable of processing beacon actions
 * @param error A pointer to an NSError object that will be populated with error info, if processing beacon actions is not possible
 * @return YES, if the current device and the running app are capable of processing beacon actions
 */
- (BOOL)isBeaconCtrlReadyToProcessBeaconActions:(NSError **)error;

/*!
 * @brief Start responding to beacon events
 * @return YES, if BecaonOS has successfully started monitoring, NO otherwise
 */
- (BOOL) startMonitoringBeacons;

/*!
 * @brief Stop responding to beacon events
 */
- (void) stopMonitoringBeacons;

/*!
 * @brief The main method that determines which beacons should currently be monitored, basing on the estimated location of the device
 * @return YES, if BecaonCtrl has successfully updated monitored beacons, NO otherwise
 */
- (BOOL)updateMonitoredBeacons;

/*!
 * @return The zone that the user's device is currently in
 */
- (BCLZone *)currentZone;

/*!
 * @brief Recalculates the current zone basing on the signal strengths of visible beacons
 */
- (void)recheckCurrentZone;

/*!
 * @return The beacon that is closest to the user's device
 */
- (BCLBeacon *)closestBeacon;

/*!
 @return The beacon whose range was last entered by the user's device
 */
- (BCLBeacon *)lastEnteredBeacon;

/*!
 * @return An array of beacons sorted ascendingly by distance from the user's device
 */
- (NSArray<BCLBeacon *> *)beaconsSortedByDistance;

/*!
 * @brief the main setup method for the SDK
 * @param clientId Client id obtained from the admin panel for authentication
 * @param clientSecret Client secret obtained from the admin panel for authentication
 * @param userId An arbitrary string identifier for an app user. given as a parameter during the setup
 * @param pushEnvironment Push environment that should be used in the current build as defined in "BCLBeaconCtrlPushEnvironment" NS_ENUM
 * @param pushToken Devices push token retrieved from the APNS or nil, if the push environment is BCLBeaconCtrlPushEnvironmentNone
 * @param completion The completion handler called after the setup is finished
 */
+ (void)setupBeaconCtrlWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret userId:(NSString *)userId pushEnvironment:(BCLBeaconCtrlPushEnvironment)pushEnvironment pushToken:(NSString *)pushToken  completion:(void (^)(BCLBeaconCtrl *beaconCtrl, BOOL isRestoredFromCache, NSError *error))completion;

/*!
 * @return A BCLBeaconCtrl instance restored from the device's cache
 */
+ (BCLBeaconCtrl *) beaconCtrlRestoredFromCache;

/*!
 @brief Stored the receiver in the device's cache
 @discussion Should be called when the application is terminated, so that all the beacon and/or zone actions are correctly handled when the application is launched after some beacon event has occured
 */
- (BOOL) storeInCache;

/*!
 @brief Deletes the currently stored BCLBeaconCtrl instance from the device's cache
 */
+ (void) deleteBeaconCtrlFromCache;

/*!
 * @brief A method for handling push and local notifications fired by BeaconCtrl
 * @discussion BeaconCtrl backend sends some push notifications to the SDK in order to fire some admin-defined beacon and zone actions; BeaconCtrl SDK fires some local notifications for the same purpose.
 */
- (BOOL)handleNotification:(NSDictionary *)userInfo error:(NSError **)error;

/*!
 * @brief Fetches the latest configuration from the backend
 * @param completion The completion handler that is fired after the fetch is finished
 */
- (void)fetchConfiguration:(void(^)(NSError *error))completion;

/*!
 * @brief Fetches users who are in range of given beacons or zones
 * @discussion Available when the Presence Add-on is activated for the application in the Admin Panel
 * @param beacons A set of beacons that an SDK user wants to query for users being in their range
 * @param zones A set of zone that an SDK user wants to query for users being in their range
 * @param completion The completion handler that is fired after the fetch is finished
 */
- (void)fetchUsersInRangesOfBeacons:(NSSet *)beacons zones:(NSSet *)zones completion:(void (^)(NSDictionary *result, NSError *error))completion;

/*!
 * @brief Logs out the current SDK client
 */
- (void)logout;

@end
