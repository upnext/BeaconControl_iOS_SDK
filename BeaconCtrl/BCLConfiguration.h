//
//  BCLConfiguration.h
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLExtension.h"
#import "BCLEncodableObject.h"

/*!
 * A BCLConfiguration object represents a beacon, zone, actions and extensions configuration relevant for a given BeaconCtrl Application, fetched from the BeaconCtrl Client API and is kept as a reference in
 * the BCLBeaconCtrl singleton
 */
@interface BCLConfiguration : BCLEncodableObject

/** @name Properties */

/// Fetched extensions. Set of initialized instances of objects.
@property (strong, nonatomic, readonly) NSSet <BCLExtension> *extensions;

/// Fetched beacons. A set of CTLBeacon objects
@property (strong, nonatomic, readonly) NSSet <BCLBeacon *> *beacons;

/// Fetched zones. A set of CTLZone objects
@property (strong, nonatomic, readonly) NSSet *zones;

/// Kontakt.io API key or nil if the kontakt.io add-on is not switched on
@property (nonatomic, copy, readonly) NSString *kontaktIOAPIKey;

/** @name Methods */

/*!
 * @brief inits a BCLConfiguration object with jsonData fetched from the backend
 * @param jsonData An NSData object that contains json with a configuration representation fetched from the backend
 */
- (instancetype) initWithJSON:(NSData *)jsonData;

/*!
 * @brief Finds a class with a given name (found by calling a given selector on a class) and protocol
 * @param name A name of the class to find
 * @param protocol A protocol that the class needs to conform to
 * @param nameSelector A selector that will be called on a class to get its name
 */
+ (Class) classForName:(NSString *)name protocol:(Protocol *)protocol selector:(SEL)nameSelector;

@end
