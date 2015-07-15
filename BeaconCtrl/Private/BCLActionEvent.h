//
//  BCLEvent.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <SAMCache/SAMCache.h>
#import "BCLTypes.h"

@interface BCLActionEvent : NSObject <NSCopying, NSSecureCoding>

@property (readonly) NSString *identifier;
@property (assign) NSTimeInterval timestamp;
@property (strong) NSString *beaconIdentifier;
@property (strong) NSString *zoneIdentifier;
@property (strong) NSString *actionIdentifier;
@property (strong) NSString *actionName;
@property (nonatomic) BCLEventType eventType;

- (NSString *) eventTypeName;

@end


