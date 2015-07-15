//
//  BCLLocation.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import <UNNetworking/UNCoding.h>

@interface BCLLocation : NSObject <UNCoding>

@property (nonatomic, strong, readonly) CLLocation *location;
@property (nonatomic, strong, readonly) NSNumber *floor;

- (instancetype)initWithLocation:(CLLocation *)location floor:(NSNumber *)floor;

@end
