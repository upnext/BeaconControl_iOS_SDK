//
//  BCLBackend.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLAbstractBackend.h"

@class BCLConfiguration, BCLActionEventScheduler, BCLBeacon;

@interface BCLBackend : BCLAbstractBackend

@property (copy, readonly) NSString *pushEnvironment;
@property (copy, readonly) NSString *pushToken;
@property (copy, readwrite, nonatomic) NSString *userId;

- (instancetype) initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret pushEnvironment:(NSString *)pushEnvironment pushToken:(NSString *)pushToken;

- (void) fetchConfiguration:(void(^)(BCLConfiguration *configuration, NSError *error))completion;
- (void) sendEvents:(NSArray *)events completion:(void(^)(NSError *error))completion;
- (void) fetchUsersInRangesOfBeacons:(NSSet *)beacons zones:(NSSet *)zones completion:(void (^)(NSDictionary *result, NSError *error))completion;

@end
