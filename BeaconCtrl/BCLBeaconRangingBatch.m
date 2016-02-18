//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLBeaconRangingBatch.h"

#define BCLRangingSecondsTimeFrame 1

// timeout value since last read. After that amount of time batch is cheared out
#define BCLRangingSecondsTimeout 120

static NSDate *lastRanging;

@implementation BCLBeaconRangingBatch

- (instancetype) initWithDelegate:(id <BCLBeaconRangingBatchDelegate>)delegate
{
    if (self = [self init]) {
        self.delegate = delegate;
    }
    return self;
}


- (void) add:(NSArray *)rangedBeacons forRegion:(CLBeaconRegion *)region
{
    @synchronized(self) {
        if (!self.batch) {
            self.batch = [NSMutableDictionary dictionary];
            [self resetForRegion:region];
        }
        
        NSTimeInterval timeIntervalSinceLastRanging = [[NSDate date] timeIntervalSinceDate:lastRanging ?: [NSDate dateWithTimeIntervalSinceReferenceDate:0]];
        if (timeIntervalSinceLastRanging >= BCLRangingSecondsTimeout) {
            [self resetForRegion:region];
        }
        
        lastRanging = [NSDate date];
        
        NSArray *beaconsInBatch = self.batch[region.identifier][@"beacons"];
        
        if (beaconsInBatch.count > 0) {
            // if time elapsed from the last read is significant I assume that there was
            // break and batch is processed as new
            NSDate *refDate = self.batch[region.identifier][@"refdate"];
            NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:refDate];
            
            // reset batch after BCLRangingSecondsTimeout
            if (timeInterval >= BCLRangingSecondsTimeout) {
                [self resetForRegion:region];
                beaconsInBatch = self.batch[region.identifier][@"beacons"];
            }
            
            // expand
            beaconsInBatch = [beaconsInBatch arrayByAddingObjectsFromArray:rangedBeacons];
            self.batch[region.identifier] = @{@"refdate": refDate, @"beacons": beaconsInBatch};

            if (timeInterval >= BCLRangingSecondsTimeFrame) {
                id <BCLBeaconRangingBatchDelegate> delegateStrong = self.delegate;
                if ([delegateStrong conformsToProtocol:@protocol(BCLBeaconRangingBatchDelegate)]) {
                    [delegateStrong processBeaconBatch:self beacons:beaconsInBatch];
                }
                [self resetForRegion:region];
            }
        } else {
            // init with ranged beacons
            self.batch[region.identifier] = @{@"refdate": [NSDate date], @"beacons": rangedBeacons};
            id <BCLBeaconRangingBatchDelegate> delegateStrong = self.delegate;
            if ([delegateStrong conformsToProtocol:@protocol(BCLBeaconRangingBatchDelegate)]) {
                [delegateStrong processBeaconBatch:self beacons:rangedBeacons];
            }
            [self resetForRegion:region];
        }
    }
}

- (NSArray *) regions
{
    @synchronized(self) {
        return [self.batch allKeys];
    }
}

- (void) resetForRegion:(CLBeaconRegion *)region
{
    self.batch[region.identifier] = @{@"refdate": [NSDate date], @"beacons": [NSArray array]};
}

@end
