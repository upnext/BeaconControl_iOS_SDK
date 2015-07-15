//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "SAMCache.h"

#define BLECacheActionIdentifierFormat(action,beacon) \
    [NSString stringWithFormat:@"beacon.%@.action.%@.type.%@", beacon.identifier, action.uniqueIdentifier, action.type]

@interface SAMCache (BeaconCtrl)

+ (SAMCache *) bcl_monitoredProximityCache;
+ (SAMCache *) bcl_lastActionEventsCache;
+ (SAMCache *)bcl_actionEventsCache;

@end
