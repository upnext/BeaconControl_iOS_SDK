//
//  BCLTrigger.h
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLBeacon.h"
#import "BCLZone.h"
#import "BCLCondition.h"
#import "BCLAction.h"
#import "BCLEncodableObject.h"

@protocol BCLBeaconCtrlDelegate;

@interface BCLTrigger : BCLEncodableObject

@property (strong, nonatomic) BCLBeacon *beacon; //FIXME: why strong ?
@property (strong, nonatomic) BCLZone *zone; //FIXME: why strong ?
@property (strong, nonatomic) NSArray <BCLCondition> *conditions;
@property (strong, nonatomic) NSArray *actions;

- (void)updatePropertiesFromDictionary:(NSDictionary *)dictionary;

@end
