//
//  BCLActionEventScheduler.h
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

extern NSString * const BCLActionEventSchedulerBackgroundTaskIdentifier;

@class BCLActionEvent, BCLBackend;

@interface BCLActionEventScheduler : NSObject

- (instancetype) initWithBackend:(BCLBackend *)backend;

- (void)sendActionEvents:(void (^)(NSError *error))completion;

- (void) storeEvent:(BCLActionEvent *)event;

- (BCLActionEvent *) lastStoredEventWithType:(BCLEventType)type;

+ (void)clearCache;

@end
