//
//  BCLZone.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <UNNetworking/UNCoding.h>
#import <UIKit/UIKit.h>

/*!
 * A class representing zones of beacons in BeaconCtrl
 */

@interface BCLZone : NSObject <NSCopying, UNCoding>

/** @name Properties */

/// Zone identifier assigned by the backend
@property (nonatomic, copy) NSString *zoneIdentifier;

/// Name of a zone
@property (nonatomic, copy) NSString *name;

/// A custom color assigned to a zone on the backend
@property (nonatomic, strong) UIColor *color;

/// Beacons assigned to a zone. A hash table with weak references to BCLBeacon objects
@property (nonatomic, strong) NSHashTable *beacons; // conveniency

/// Triggers assigned to a zone
@property (strong, nonatomic) NSArray *triggers;

/// Callback called on enter zone event
@property (copy) void(^onEnterCallback)(BCLZone *zone);

/// Callback called on leave zone event
@property (copy) void(^onExitCallback)(BCLZone *zone);

/** @name Methods */

/*!
 * @brief Initialize a zone object with an identifier and a name
 *
 * @param zoneIdentifier A zone identifier
 * @param name A zone name
 *
 * @return An initialized zone object
 */
- (instancetype)initWithIdentifier:(NSString *)zoneIdentifier name:(NSString *)name;

/*!
 * @brief Update a zone's properties with values from a dictionary and a set of beacons
 *
 * @param dictionary A dictionary with zone's properties
 * @param beaconsSet A set of BLCBeacon objects that will be assigned to a zone
 *
 * @return An updated zone object
 */
- (void)updatePropertiesFromDictionary:(NSDictionary *)dictionary beacons:(NSSet *)beaconsSet;

@end
