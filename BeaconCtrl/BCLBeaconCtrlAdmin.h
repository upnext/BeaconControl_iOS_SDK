//
//  BCLBeaconCtrlAdmin.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLTypes.h"

@class BCLBeacon;
@class BCLZone;

/*!
 * A BCLBeaconCtrlAdmin singleton is the main point of interaction with BeaconCtrl S2S API
 */
@interface BCLBeaconCtrlAdmin : NSObject

/** @name Properties */

/// Beacons fetched from the backend
@property(nonatomic, strong) NSSet *beacons;

// Zones fetched from the backend
@property(nonatomic, strong) NSSet *zones;

// Available zone colors fetched from the backend
@property(nonatomic, strong) NSArray *zoneColors;


/** @name Methods */

/*!
 * @brief The main setup method for BCLBeaconCtrlAdmin
 * @param clientId A client id obtained from the s2s API provider, used for authentication
 * @param clientSecret A client secret obtained from the s2s API provider, used for authentication
 * @return An initialized instance of BCLBeaconCtrlAdmin
 */
+ (instancetype)beaconCtrlAdminWithCliendId:(NSString *)clientId clientSecret:(NSString *)clientSecret;

/*!
 * @brief Fethes beacons and zones from the backend
 * @param completion A completion handler that is called after the fetch is finished
 */
- (void)fetchZonesAndBeacons:(void (^)(NSError *error))completion;

/*!
 * @brief Syncs a given beacon with its state on the backend
 * @param beacon A beacon to sync
 * @param completion The completion handler that is fires after the sync is finished
 */
- (void)syncBeacon:(BCLBeacon *)beacon completion:(void (^)(NSError *error))completion;

/*!
 * @brief Fetch available zone colors from the backend
 * @discussion Each zone can have a color that is one the colors stored in the zoneColors property that is populated once this method is successfully called
 * @param completion A completion handler that is called after the fetch is finished
 */
- (void)fetchZoneColors:(void (^)(NSError *error))completion;

/*!
 * @brief Registers a new admin user on the backend
 * @param email The new user's email
 * @param password The new user's password
 * @param passwordConfirmation The new user's password confirmation for verification
 * @param completion A completion block that is called after the registration is finished
 */
- (void)registerAdminUserWithEmail:(NSString *)email password:(NSString *)password passwordConfirmation:(NSString *)passwordConfirmation completion:(void (^)(BOOL success, NSError *error))completion;

/*!
 * @brief Authenticates an existing admin user against the backend
 * @param email Admin user's email
 * @param password Admin user's password
 * @param completion A completion block that is called after the authentication is finished
 */
- (void)loginAdminUserWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(BOOL success, NSError *error))completion;

/*!
 * @brief Fethes a cliend id and client secret for the currently logged in admin user's test application
 * @discussion Every admin user has exactly one test application that monitors all the beacons and zones added to the admin user's account
 * @param completion A completion block that is called after the fetch is finished
 */
- (void)fetchTestApplicationCredentials:(void (^)(NSString *applicationClientId, NSString *applicationClientSecret, NSError *error))completion;

/*!
 * @brief Creates a beacon on the backend
 * @discussion When creating a beacon, an admin SDK user can create the first test action. It will be added as a custom action with given attributes on the backend.
 * @param beacon A beacon that will be created
 * @param testActionName Name of the test action
 * @param testActionTrigger Trigger of the test action
 * @param testActionAttributes Attributes of the test action
 * @param completion A completion handler that will be called after the creation is finished
 */
- (void)createBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BCLBeacon *, NSError *))completion;

/*!
 * @brief Updates a beacon on the backend
 * @discussion When updating a beacon, an admin SDK user can create or update its test action. Any test action is added as a custom action with given attributes on the backend.
 * @param beacon A beacon that will be updated
 * @param testActionName Name of the test action
 * @param testActionTrigger Trigger of the test action
 * @param testActionAttributes Attributes of the test action
 * @param completion A completion handler that will be called after the update is finished
 */
- (void)updateBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BOOL success, NSError *error))completion;

/*!
 * @brief Deletes a beacon on the backend
 * @param beacon A beacon that will be deleted
 * @param completion A completion handler that will be called after the deletion is finished
 */
- (void)deleteBeacon:(BCLBeacon *)beacon completion:(void (^)(BOOL success, NSError *error))completion;

/*!
 * @brief Creates a zone on the backend
 * @param zone A zone that will be created
 * @param completion A completion handler that will be called after the creation is finished
 */
- (void)createZone:(BCLZone *)zone completion:(void (^)(BCLZone *newZone, NSError *error))completion;

/*!
 * @brief Updates a zone on the backend
 * @param zone A zone that will be updated
 * @param completion A completion handler that will be called after the update is finished
 */
- (void)updateZone:(BCLZone *)zone completion:(void (^)(BOOL success, NSError *error))completion;

/*!
 * @brief Deletes a zone on the backend
 * @param zone A zone that will be deleted
 * @param completion A completion handler that will be called after the deletion is finished
 */
- (void)deleteZone:(BCLZone *)zone completion:(void (^)(BOOL success, NSError *error))completion;

/*!
 * @brief Fetches an array of available vendors
 * @param completion A completion handler that will be called after the fetch is complete
 */
- (void)fetchVendors:(void (^)(NSArray *vendors, NSError *error))completion;

- (void)logout;

@end
