//
//  BCLActionEventScheduler.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLActionEventScheduler.h"
#import "BCLActionEvent.h"
#import "BCLBackend.h"
#import "SAMCache+BeaconCtrl.h"
#import <UIKit/UIKit.h>

static NSTimeInterval BCLActionEventSchedulerMinSendIdleInterval = 15;
static NSString * const BCLActionEventSchedulerCachedEventsCacheKey = @"cachedEventsMutableArray";
NSString * const BCLActionEventSchedulerBackgroundTaskIdentifier = @"backgroundTaskIdentifier";

NSString * _cacheKeyForEventType(BCLEventType type) {
    return [NSString stringWithFormat:@"%li", type];
};

@interface BCLActionEventScheduler ()

@property (weak) BCLBackend *backend;

@property (nonatomic, strong) NSTimer *sendEventsTimer;
@property (nonatomic, strong) NSDate *lastSendDate;
@property (nonatomic, strong) NSNumber *currentBackgroundTaskIdentifierNumber;

@end


/**
 *  Action send events scheduler, connected to BCLBackend and initialized from there.
 */
@implementation BCLActionEventScheduler

#pragma mark - Events recorder

/**
 *  Initialize with backend instance, called from BCLBackend
 *
 *  @param backend weak reference to backend instance
 *
 *  @return Initialized instance
 */
- (instancetype) initWithBackend:(BCLBackend *)backend
{
    if (self = [self init]) {
        self.backend = backend;
    }
    return self;
}

/**
 *  Schedule for sending actions periodicaly
 */
- (void) scheduleSendingActionEventsWithDelay:(NSTimeInterval)delay userInfo:(NSDictionary *)userInfo
{
    if (self.sendEventsTimer) {
        return;
    }
    
    self.sendEventsTimer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(sendActionEventsTimerHandler:) userInfo:userInfo repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.sendEventsTimer forMode:NSDefaultRunLoopMode];
}

/**
 *  Send action events
 */
- (void) sendActionEventsTimerHandler:(NSTimer *)timer
{
    NSDictionary *userInfo = timer.userInfo;
    
    self.sendEventsTimer = nil;
    
    [self sendActionEvents:^(NSError *error) {
        if (userInfo[BCLActionEventSchedulerBackgroundTaskIdentifier]) {
            UIBackgroundTaskIdentifier backgroundTaskIdentifier = [userInfo[BCLActionEventSchedulerBackgroundTaskIdentifier] unsignedIntegerValue];
            
            if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                self.currentBackgroundTaskIdentifierNumber = nil;
#ifdef DEBUG
                NSLog(@"sendActionEventsTimerHandler endBackgroundTask");
#endif
            }
        }
    }];
}

- (void)sendActionEvents:(void (^)(NSError *error))completion
{
    NSMutableArray *cachedEvents = [[SAMCache bcl_actionEventsCache] objectForKey:BCLActionEventSchedulerCachedEventsCacheKey];
    
    if (cachedEvents.count) {
        self.lastSendDate = [NSDate date];
    }
    
    [self.backend sendEvents:cachedEvents completion:^(NSError *error) {
        if (error) {
            NSLog(@"Unable to send events %@",error);
            if (completion) {
                completion(error);
            }
            return;
        }
        
        // clear storage
        [self.class clearCache];
        
        if (completion) {
            completion(nil);
        }
    }];
    
    self.sendEventsTimer = nil;
}

- (dispatch_queue_t)eventsDispatchQueue
{
    static dispatch_queue_t events_queue;
    
    if (!events_queue) {
        events_queue = dispatch_queue_create("events queue", DISPATCH_QUEUE_SERIAL);
    }
    return events_queue;
}

- (void) storeEvent:(BCLActionEvent *)event
{
    if (!self.currentBackgroundTaskIdentifierNumber) {
        __weak typeof(self) weakSelf = self;
        self.currentBackgroundTaskIdentifierNumber = @([[UIApplication sharedApplication] beginBackgroundTaskWithName:@"beacon-os-action-event-scheduler" expirationHandler:^{
            weakSelf.currentBackgroundTaskIdentifierNumber = nil;
            NSLog(@"Application about to terminate with unsent action events: %@", [[SAMCache bcl_actionEventsCache] objectForKey:BCLActionEventSchedulerCachedEventsCacheKey]);
        }]);
    }
    
    dispatch_queue_t queue = [self eventsDispatchQueue];
    dispatch_async(queue, ^{
        // store in cache
        NSMutableArray *cachedEvents = [[[SAMCache bcl_actionEventsCache] objectForKey:BCLActionEventSchedulerCachedEventsCacheKey] mutableCopy];
        if (!cachedEvents) {
            cachedEvents = [NSMutableArray array];
        }
        
        [cachedEvents addObject:event];
        
        [[SAMCache bcl_actionEventsCache] setObject:cachedEvents.copy forKey:BCLActionEventSchedulerCachedEventsCacheKey];
        
        [[SAMCache bcl_lastActionEventsCache] setObject:event forKey:_cacheKeyForEventType(event.eventType)];
        
        NSDictionary *userInfo = @{BCLActionEventSchedulerBackgroundTaskIdentifier: self.currentBackgroundTaskIdentifierNumber};
        
        NSTimeInterval intervalSinceLastSendDate = [[NSDate date] timeIntervalSinceDate:self.lastSendDate];
        
        if (!self.lastSendDate || (intervalSinceLastSendDate > BCLActionEventSchedulerMinSendIdleInterval)) {
            NSLog(@"BEACON OS WILL SEND AN ACTION EVENT RIGHT AWAY");
            [self scheduleSendingActionEventsWithDelay:1 userInfo:userInfo];
        } else {
            NSLog(@"BEACON OS WILL SEND AN ACTION EVENT IN %f SECONDS", BCLActionEventSchedulerMinSendIdleInterval - intervalSinceLastSendDate);
            [self scheduleSendingActionEventsWithDelay:(BCLActionEventSchedulerMinSendIdleInterval - intervalSinceLastSendDate) userInfo:userInfo];
        }
    });
}

- (BCLActionEvent *)lastStoredEventWithType:(BCLEventType)type
{
    return [[SAMCache bcl_lastActionEventsCache] objectForKey:_cacheKeyForEventType(type)];
}

+ (void)clearCache
{
    [[SAMCache bcl_actionEventsCache] setObject:nil forKey:BCLActionEventSchedulerCachedEventsCacheKey];
}

@end
