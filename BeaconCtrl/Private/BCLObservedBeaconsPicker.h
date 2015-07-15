//
//  BCLObservedBeaconsPicker.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLLocation.h"
#import "BCLEncodableObject.h"

@interface BCLObservedBeaconsPicker : BCLEncodableObject

- (instancetype)initWithBeacons:(NSSet *)beacons andZones:(NSSet *)zones;

- (NSSet *)observedBeaconsWithLocation:(BCLLocation *)location beaconsDidChange:(BOOL *)didChange;
- (NSSet *)observedZones:(BOOL *)didChange;

@end
