//
//  BCLBeaconCtrlAdmin.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLBeaconCtrlAdmin.h"
#import "BCLAdminBackend.h"

@interface BCLBeaconCtrlAdmin ()

@property (nonatomic, copy) NSString *clientId;
@property (nonatomic, copy) NSString *clientSecret;

@property (nonatomic, strong) BCLAdminBackend *backend;

@end

@implementation BCLBeaconCtrlAdmin

+ (instancetype)beaconCtrlAdminWithCliendId:(NSString *)clientId clientSecret:(NSString *)clientSecret
{
    BCLBeaconCtrlAdmin *beaconCtrlAdmin = [self new];
    
    beaconCtrlAdmin.clientId = clientId;
    beaconCtrlAdmin.clientSecret = clientSecret;
    
    beaconCtrlAdmin.backend = [[BCLAdminBackend alloc] initWithClientId:clientId clientSecret:clientSecret];
    
    return beaconCtrlAdmin;
}

- (void)fetchZonesAndBeacons:(void(^)(NSError *error))completion
{
    __weak BCLBeaconCtrlAdmin *weakSelf = self;
    [self.backend fetchBeacons:^(NSSet *beacons, NSError *error) {
        if (!error) {
            weakSelf.beacons = beacons;
            [weakSelf.backend fetchZones:beacons completion:^(NSSet *zones, NSError *error) {
                if (!error) {
                    weakSelf.zones = zones;
                }
                if (completion) completion(error);
            }];
        } else {
            if (completion) completion(error);
        }
    }];
}

- (void)syncBeacon:(BCLBeacon *)beacon completion:(void (^)(NSError *))completion
{
    [self.backend syncBeacon:beacon completion:completion];
}

- (void)fetchZoneColors:(void (^)(NSError *))completion
{
    __weak BCLBeaconCtrlAdmin *weakSelf = self;
    
    [self.backend fetchZoneColors:^(NSArray *zoneColors, NSError *error) {
        if (!error) {
            weakSelf.zoneColors = zoneColors;
            if (completion) completion(error);
        } else {
            if (completion) completion(error);
        }
    }];
}

- (void)fetchVendors:(void (^)(NSArray *vendors, NSError *error))completion
{
    [self.backend fetchVendors:completion];
}

- (void)loginAdminUserWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(BOOL, NSError *))completion
{
    [self.backend authenticateUserWithEmail:email password:password completion:completion];
}

- (void)registerAdminUserWithEmail:(NSString *)email password:(NSString *)password passwordConfirmation:(NSString *)passwordConfirmation completion:(void (^)(BOOL, NSError *))completion
{
    [self.backend registerNewUserWithEmail:email password:password passwordConfirmation:passwordConfirmation completion:completion];
}

- (void)fetchTestApplicationCredentials:(void (^)(NSString *, NSString *, NSError *))completion
{
    [self.backend fetchTestApplicationCredentials:completion];
}

- (void)createBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BCLBeacon *, NSError *))completion
{
    [self.backend createBeacon:beacon testActionName:testActionName testActionTrigger:trigger testActionAttributes:testActionAttributes completion:completion];
}

- (void)updateBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BOOL, NSError *))completion
{
    [self.backend updateBeacon:beacon testActionName:testActionName testActionTrigger:trigger testActionAttributes:testActionAttributes completion:completion];
}

- (void)deleteBeacon:(BCLBeacon *)beacon completion:(void (^)(BOOL, NSError *))completion
{
    [self.backend deleteBeacon:beacon completion:completion];
}

- (void)createZone:(BCLZone *)zone completion:(void (^)(BCLZone *, NSError *))completion
{
    [self.backend createZone:zone completion:completion];
}

- (void)updateZone:(BCLZone *)zone completion:(void (^)(BOOL, NSError *))completion
{
    [self.backend updateZone:zone completion:completion];
}

- (void)deleteZone:(BCLZone *)zone completion:(void (^)(BOOL, NSError *))completion
{
    [self.backend deleteZone:zone completion:completion];
}

- (void)logout
{
    [self.backend reset];
}

@end
