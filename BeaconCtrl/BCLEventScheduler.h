//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class BCLBeacon;
@class BCLZone;

/**
 *  Schedules events for later execution. Used, e.g., to delay beacon 'leave' and zone 'enter' actions.
 */
@interface BCLEventScheduler : NSObject

/** @name Properties */

/// A background task identifier used to schedule events for execution in background mode.
@property (assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

/** @name Methods */

/**
 *  @brief Schedule a beacon event for later.
 *  @param beacon   A beacon for which the event occured
 *  @param delay    Delay value in seconds
 *  @param callback On time callback block
 */
- (void) scheduleEventForBeacon:(BCLBeacon *)beacon afterDelay:(NSTimeInterval)delay onTime:(void(^)(BCLBeacon *beacon))callback;

/**
 * @biref Schedule a zone 'enter' event for later.
 * @param previousZone   A zone whose range has been left
 * @param newZone A zone whose range has been entered
 *  @param delay    Delay value in seconds
 *  @param callback On time callback block
 */
- (void) scheduleChangeZoneEventWithPreviousZone:(BCLZone *)previousZone newZone:(BCLZone *)newZone afterDelay:(NSTimeInterval)delay onTime:(void(^)(BCLZone *previousZone, BCLZone *newZone))callback;

/**
 *  @brief Cancel all events scheduled for a beacon
 *  @param beacon A beacon beacon whose events will be cancelled
 *
 *  @return YES if canelled.
 */
- (BOOL) cancelForBeacon:(BCLBeacon *)beacon;

/*!
 * @brief Cancel any scheduled 'enter' zone events
 * @return YES is an event has been cancelled
 */
- (BOOL) cancelChangeZoneEvent;

/**
 *  @brief Check if a beacon has any scheduled events
 *  @param beacon A beacon that will be checked for scheduled events
 *
 *  @return YES if any event is scheduled for a beacon
 */
- (BOOL) isScheduledForBeacon:(BCLBeacon *)beacon;

/*!
 * @brief Check if there's a scheduled 'enter' zone event
 * @return YES if there's any scheduled 'enter' zone event
 */
- (BOOL) isChangeZoneEventScheduled;


@end
