//
//  BCLAdminBackend.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLAbstractBackend.h"
#import "BCLTypes.h"

@class BCLBeacon;
@class BCLZone;

@interface BCLAdminBackend : BCLAbstractBackend

- (void)authenticateUserWithEmail:(NSString *)email password:(NSString *)password completion:(void(^)(BOOL success, NSError *error))completion;
- (void)registerNewUserWithEmail:(NSString *)email password:(NSString *)password passwordConfirmation:(NSString *)passwordConfirmation completion:(void(^)(BOOL success, NSError *error))completion;

- (void)fetchTestApplicationCredentials:(void (^)(NSString *applicationClientId, NSString *applicationClientSecret, NSError *error))completion;

- (void)createBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BCLBeacon *, NSError *))completion;
- (void)updateBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BOOL success, NSError *error))completion;
- (void)deleteBeacon:(BCLBeacon *)beacon completion:(void (^)(BOOL success, NSError *error))completion;

- (void)fetchVendors:(void (^)(NSArray *vendors, NSError *error))completion;

- (void)fetchBeacons:(void (^)(NSSet *beacons, NSError *error))completion;

- (void)syncBeacon:(BCLBeacon *)beacon completion:(void (^)(NSError *error))completion;

- (void)fetchZones:(NSSet *)beacons completion:(void (^)(NSSet *zones, NSError *error))completion;

- (void)fetchZoneColors:(void (^)(NSArray *zoneColors, NSError *error))completion;

- (void)createZone:(BCLZone *)zone completion:(void (^)(BCLZone *newZone, NSError *error))completion;
- (void)updateZone:(BCLZone *)zone completion:(void (^)(BOOL success, NSError *error))completion;
- (void)deleteZone:(BCLZone *)zone completion:(void (^)(BOOL success, NSError *error))completion;

@end
