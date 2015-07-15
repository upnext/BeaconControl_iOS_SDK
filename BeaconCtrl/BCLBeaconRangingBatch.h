//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class BCLBeaconRangingBatch;

@protocol BCLBeaconRangingBatchDelegate <NSObject>

- (void) processBeaconBatch:(BCLBeaconRangingBatch *)batch beacons:(NSArray *)rangedBeacons;
@end

@interface BCLBeaconRangingBatch : NSObject

@property (strong) NSMutableDictionary *batch;

@property (strong, readonly) NSArray *regions;

@property (weak) id <BCLBeaconRangingBatchDelegate> delegate;

- (instancetype) initWithDelegate:(id <BCLBeaconRangingBatchDelegate>)delegate;

- (void) add:(NSArray *)rangedBeacons forRegion:(CLBeaconRegion *)region;

@end
