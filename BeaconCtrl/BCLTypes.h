//
//  BCLTypes.h
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <CoreLocation/CLBeaconRegion.h>

typedef NS_ENUM(NSInteger, BCLEventType) {
    BCLEventTypeUnknown = 0,
    BCLEventTypeEnter = 1,
    BCLEventTypeLeave = 2,
    BCLEventTypeRangeImmediate = 3,
    BCLEventTypeRangeNear = 4,
    BCLEventTypeRangeFar = 5,
    BCLEventTypeDwellTime = 6,
    BCLEventTypeTimer = 7
};

