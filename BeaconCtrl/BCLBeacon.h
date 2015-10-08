//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

//  An app can register up to 20 regions at a time.
//  In order to report region changes in a timely manner, the region monitoring service requires network connectivity.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import <UNNetworking/UNCoding.h>

#import <MapKit/MapKit.h>

@class BCLLocation;
@class BCLZone;

extern NSString * const BCLInvalidBeaconIdentifierException;
extern NSString * const BCLBeaconTimerFireNotification;

#define BLEBeaconStaysCacheName(beacon) \
    [NSString stringWithFormat:@"com.up-next.BeaconCtrl.stays.%@",beacon.identifier]

/*!
 * A class representing beacons in BeaconCtrl
 */
@interface BCLBeacon : CLBeacon <NSCopying, UNCoding, MKAnnotation>

/** @name Properties */

/// Protocol of a beacon (iBeacon or Eddystone)
@property (readwrite, nonatomic, strong) NSString *protocol;

/// UUID value of a beacon
@property (readwrite, nonatomic, strong) NSUUID *proximityUUID;

/// Major value of an iBeacon
@property (readwrite, nonatomic, strong) NSNumber *major;

/// Minor value of an iBeacon
@property (readwrite, nonatomic, strong) NSNumber *minor;

/// Namespace value of an Eddystone beacon
@property (readwrite, nonatomic, strong) NSString *namespaceId;

/// Intance id of an Eddystone beacon
@property (readwrite, nonatomic, strong) NSString *instanceId;

/// Proximity of a beacon to a device running the SDK described as a CLProximity constant
@property (readwrite, nonatomic, assign) CLProximity proximity;

/// Rough distance in meters from a beacon to a device running the SDK, 0 if the beacon is out of range
@property (readwrite, nonatomic, assign) CLLocationAccuracy accuracy;

/// Estimated distance in meters from a beacon to a device running the SDK
@property (readwrite, nonatomic, assign) double estimatedDistance;

/// Bluetooth signal strength of a beacon
@property (readwrite, nonatomic, assign) NSInteger rssi;

/// The date when a beacon's range was last entered
@property (readwrite, nonatomic, strong) NSDate *lastEnteredDate;

/// Name of a beacon.
@property (strong) NSString *name;

/// A zone to which a beacon is assigned, nil if there's none
@property (nonatomic, weak) BCLZone *zone;

/// How long a beacon has been in range of a device running the SDK (time since last entry, if there was no leave afterwards)
@property (assign, readonly) NSTimeInterval staysTimeInterval;

/// Triggers defined for beacon
@property (strong, nonatomic) NSArray *triggers;

/// A unique identifier - string of proximityUUID+major+minor
@property (readonly) NSString *identifier;

/// Beacon identifier assigned by the backend
@property (strong) NSString *beaconIdentifier;

/// Beacon's vendor (i.e. Kontakt.io, Estimote or other)
@property (strong) NSString *vendor;

/// Beacon's vendor-specific identifier
@property (strong) NSString *vendorIdentifier;

/// Beacon's vendor-specific firmware version
@property (strong) NSString *vendorFirmwareVersion;

/// Transmission power for a beacon. May be NSNotFound, if vendor is unknown
@property (nonatomic) NSUInteger transmissionPower;

/// Transmission interval for a beacon. May be NSNotFound, if vendor is unknown
@property (nonatomic) NSUInteger transmissionInterval;

/// Battery level for a beacon. May be NSNotFound, if vendor is unknown
@property (nonatomic) NSUInteger batteryLevel;

/// A flag stating whether a given beacon has outdated properties
@property (nonatomic) BOOL needsCharacteristicsUpdate;

/// A dictionary of fields to update with property names as keys and new values as values. May be nil for beacons with an unknown vendor
@property (nonatomic, strong) NSDictionary *fieldsToUpdate;

/// A flag stating whether a given beacon is currently being updated
@property (nonatomic) BOOL characteristicsAreBeingUpdated;

/// A flag stating whether a given beacon has outdated firmware
@property (nonatomic) BOOL needsFirmwareUpdate;

/// Firmware update progress
@property (nonatomic) NSUInteger firmwareUpdateProgress;

/// Callback called when a beacon's range is entered
@property (copy) void(^onEnterCallback)(BCLBeacon *beacon);

/// Callback called when a beacon's range is left
@property (copy) void(^onExitCallback)(BCLBeacon *beacon);

/// Callback called when beacon's proximity changes
@property (copy) void(^onChangeProximityCallback)(BCLBeacon *beacon);

/** @name MKAnnotation-related properties */

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, strong) BCLLocation *location;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

/** @name Methods */

/*!
 *  @brief Initialize beacon with parameters
 *
 *  @param beaconIdentifier    immutable value representing single beacon.
 *  @param proximityUUID proximity UUID
 *  @param major         major
 *  @param minor         minor
 *
 *  @return Initialized object
 */
- (instancetype) initWithIdentifier:(NSString *)beaconIdentifier proximityUUID:(NSUUID *)proximityUUID major:(NSNumber *)major minor:(NSNumber *)minor;

/*!
 * @brief Update a beacon's properties with values taken from dictionary
 * @param dictionary A dictionary with beacon's properties
 */
- (void)updatePropertiesFromDictionary:(NSDictionary *)dictionary;

/*!
 * @brief Check if a new proximity can be set for a beacon
 * @param newProximity a proximity that will be checked
 * @return YES, if a new proximity can be set for a beacon
 */
- (BOOL)canSetProximity:(CLProximity)newProximity;

@end
