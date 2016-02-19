//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLEventScheduler.h"
#import "CLBeacon+BeaconCtrl.h"
#import "BCLBeacon.h"
#import "BCLZone.h"
#import "BCLActionEventScheduler.h"

@interface BCLEventScheduler ()

@property (strong) NSMutableDictionary *beaconTimers;
@property (strong) NSMutableDictionary *zoneTimers;

@end

@implementation BCLEventScheduler

- (instancetype)init
{
    if (self = [super init]) {
        self.beaconTimers = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void) scheduleEventForBeacon:(BCLBeacon *)beacon afterDelay:(NSTimeInterval)delay onTime:(void(^)(BCLBeacon *beacon))callback
{
    @synchronized(self) {
        if (!self.beaconTimers) {
            self.beaconTimers = [NSMutableDictionary dictionary];
        }

        UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"beacon-os-event-scheduler" expirationHandler:^{
            NSLog(@"Application about to terminate with range timers %@", self.beaconTimers);
        }];
        
        NSDictionary *userInfo = @{@"beacon": beacon, @"delay": @(delay), @"callback": [callback copy], BCLActionEventSchedulerBackgroundTaskIdentifier: @(backgroundTaskIdentifier)};
        
        if ([self isScheduledForBeacon:beacon]) {
            [self cancelForBeacon:beacon];
        }

        // Schedule event for delay
        __weak typeof(self)selfWeak = self;
        NSTimer *timer = [NSTimer timerWithTimeInterval:delay target:selfWeak selector:@selector(handleBeaconTimer:) userInfo:userInfo repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        
        [self.beaconTimers setObject:@{@"userInfo":userInfo, @"timer": timer} forKey:beacon.identifier];
    }
}

- (void)scheduleChangeZoneEventWithPreviousZone:(BCLZone *)previousZone newZone:(BCLZone *)newZone afterDelay:(NSTimeInterval)delay onTime:(void (^)(BCLZone *, BCLZone *))callback
{
    @synchronized(self) {
        if (!self.zoneTimers) {
            self.zoneTimers = [NSMutableDictionary dictionary];
        }
        
        UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"beacon-os-event-scheduler" expirationHandler:^{
            NSLog(@"Application about to terminate with zone timers %@", self.zoneTimers);
        }];
        
        NSDictionary *userInfo = @{@"previousZone": previousZone ? : [NSNull null], @"newZone": newZone ? : [NSNull null], @"delay": @(delay), @"callback": [callback copy], BCLActionEventSchedulerBackgroundTaskIdentifier: @(backgroundTaskIdentifier)};
        
        // Schedule event for delay
        __weak typeof(self)selfWeak = self;
        NSTimer *timer = [NSTimer timerWithTimeInterval:delay target:selfWeak selector:@selector(handleChangeZoneTimer:) userInfo:userInfo repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        
        self.zoneTimers[@"changeZoneEventTimer"] = @{@"userInfo" : userInfo, @"timer" : timer};
    }
}

- (void) handleBeaconTimer:(NSTimer *)timer
{
    @synchronized(self) {
        void (^callback)(BCLBeacon *beacon) = [timer.userInfo objectForKey:@"callback"];
        
        UIBackgroundTaskIdentifier timerBackgroundTaskIdentifier = [timer.userInfo[BCLActionEventSchedulerBackgroundTaskIdentifier] unsignedIntegerValue];
        UIBackgroundTaskIdentifier newBackgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];

        BCLBeacon *beacon = timer.userInfo[@"beacon"];
        if (callback) {
            callback(beacon);
        }

        [self.beaconTimers removeObjectForKey:beacon.identifier];
        
        if (newBackgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:newBackgroundTaskIdentifier];
            newBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
#ifdef DEBUG
            NSLog(@"handleBeaconTimer endBackgroundTask 1");
#endif
        }
        
        if (timerBackgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:timerBackgroundTaskIdentifier];
#ifdef DEBUG
            NSLog(@"handleBeaconTimer endBackgroundTask 2");
#endif
        }
    }
}

- (void) handleChangeZoneTimer:(NSTimer *)timer
{
    @synchronized(self) {
        void (^callback)(BCLZone *previousZone, BCLZone *newZone) = [timer.userInfo objectForKey:@"callback"];
        
        UIBackgroundTaskIdentifier timerBackgroundTaskIdentifier = [timer.userInfo[BCLActionEventSchedulerBackgroundTaskIdentifier] unsignedIntegerValue];
        UIBackgroundTaskIdentifier newBackgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        
        id previousZone = timer.userInfo[@"previousZone"];
        if (previousZone == [NSNull null]) {
            previousZone = nil;
        }
        
        id newZone = timer.userInfo[@"newZone"];
        if (newZone == [NSNull null]) {
            newZone = nil;
        }
        
        if (callback) {
            callback(previousZone, newZone);
        }
        
        [self.zoneTimers removeObjectForKey:@"changeZoneEventTimer"];
        
        if (newBackgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:newBackgroundTaskIdentifier];
            NSLog(@"handleChangeZoneTimer endBackgroundTask 1");
        }
        
        if (timerBackgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:timerBackgroundTaskIdentifier];
            NSLog(@"handleChangeZoneTimer endBackgroundTask 2");
        }
    }
}

- (BOOL) cancelForBeacon:(BCLBeacon *)beacon
{
    @synchronized(self) {
        
        if (!self.beaconTimers)
            return NO;
        
        NSDictionary *timerDict = self.beaconTimers[beacon.identifier];
        if (timerDict) {
            NSTimer *timer = timerDict[@"timer"];
            NSDictionary *userInfo = timerDict[@"userInfo"]; //workaround for crashin timer.userInfo
            
            // stop background if any
            UIBackgroundTaskIdentifier backgroundTaskIdentifier = [userInfo[BCLActionEventSchedulerBackgroundTaskIdentifier] unsignedIntegerValue];
            
            if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
#ifdef DEBUG
                NSLog(@"cancelForBeacon endBackgroundTask");
#endif
            }

            if (timer.isValid) {
                [timer invalidate];
            }
            
            [self.beaconTimers removeObjectForKey:beacon.identifier];
        }
        return NO;
    }
}

- (BOOL)cancelChangeZoneEvent
{
    @synchronized(self) {
        
        if (!self.zoneTimers)
            return NO;
        
        NSDictionary *timerDict = self.zoneTimers[@"changeZoneEventTimer"];
        
        if (timerDict) {
            NSTimer *timer = timerDict[@"timer"];
            NSDictionary *userInfo = timerDict[@"userInfo"]; //workaround for crashin timer.userInfo
            
            // stop background if any
            UIBackgroundTaskIdentifier backgroundTaskIdentifier = [userInfo[BCLActionEventSchedulerBackgroundTaskIdentifier] unsignedIntegerValue];
            
            if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
#ifdef DEBUG
                NSLog(@"cancelChangeZoneEvent endBackgroundTask");
#endif
            }
            
            if (timer.isValid) {
                [timer invalidate];
            }
            
            [self.beaconTimers removeObjectForKey:@"changeZoneEventTimer"];
        }
        return NO;
    }
}

- (BOOL) isScheduledForBeacon:(BCLBeacon *)beacon
{
    @synchronized(self) {
        id obj = self.beaconTimers[beacon.identifier];
        return obj ? YES : NO;
    }
}

- (BOOL) isChangeZoneEventScheduled
{
    @synchronized(self) {
        return self.zoneTimers[@"changeZoneEventTimer"] ? YES : NO;
    }
}



@end
