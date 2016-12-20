//
//  BCLBeaconCtrlDelegate.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

@class BCLZone;
@class BCLBeacon;

/*!
 * BCLBeaconCtrl delegate. Gets notified about BeaconCtrl SDK actions
 */
@protocol BCLBeaconCtrlDelegate <NSObject>

@optional

/** @name Methods */

/*!
 * @brief Called when a beacon or zone action is performed in background-mode
 *
 * @param action An action that will be called
 */
- (void) notifyAction:(BCLAction *)action;

/*!
 * @brief Called to ask a delegate if a local notificiation for the BeaconCtrl action should be presented automatically by the SDK
 *
 * @discussion When a BeaconCtrl action is performed in background-mode, a local notification is created automatically using the action's name. You can use this method to prevent this default behavior.
 *
 * @param action An action that would normally be notified in case of background-mode by default by the SDK
 *
 * @return YES, if the action should be notified automatically
 */
- (BOOL) shouldAutomaticallyNotifyAction:(BCLAction *)action;

/*!
 * @brief Called just before a beacon or zone action is performed
 *
 * @param action An action that will be called
 */
- (void) willPerformAction:(BCLAction *)action;

/*!
 * @brief Called just after a beacon or zone action was performed
 *
 * @param action An action that was called
 */
- (void) didPerformAction:(BCLAction *)action;

/*!
 * @brief Called to ask a delegate if a BeaconCtrl action should be handled automatically by the SDK
 *
 * @discussion Some BeaconCtrl actions, e.g. URL actions, are handled automatically by the SDK by default (in case of URL actions a modal web view is shown). You can use this method to prevent this default behavior.
 *
 * @param action An action that would normally be handled by default by the SDK
 *
 * @return YES, if the action should be handled automatically
 */
- (BOOL) shouldAutomaticallyPerformAction:(BCLAction *)action;


/*!
 * @brief Called each time a set of beacons currently monitored by the SDK has changed
 *
 * @discussion The SDK monitors a limited set of beacons at any given time and changes this set basing on the device's position and beacons currently in range. This way, the SDK gets through the iOS limitation for 20 monitored beacons at a time.
 *
 * @param newObservedBeacons A set of new monitored beacons.
 */
- (void) didChangeObservedBeacons:(NSSet *)newObservedBeacons;

/*!
 * @brief Called each time the closest beacon has changed.
 *
 * @param closestBeacon A beacons that is currently the closest to the device
 */
- (void) closestObservedBeaconDidChange:(BCLBeacon *)closestBeacon;

/*!
 * @brief Called each time the current zone has changed
 *
 * @param currentZone The beacon zone in which the device is at a given time. It's calculated by looking at beacons in range and their estimated distances from the device
 */
- (void) currentZoneDidChange:(BCLZone *)currentZone;

- (void) beaconsPropertiesUpdateDidStart:(BCLBeacon *)beacon;

- (void) beaconsPropertiesUpdateDidFinish:(BCLBeacon *)beacon success:(BOOL)success;

- (void) beaconsFirmwareUpdateDidStart:(BCLBeacon *)beacon;

- (void) beaconsFirmwareUpdateDidProgress:(BCLBeacon *)beacon progress:(NSUInteger)progress;

- (void) beaconsFirmwareUpdateDidFinish:(BCLBeacon *)beacon success:(BOOL)success;

@end
