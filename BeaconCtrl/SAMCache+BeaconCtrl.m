//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "SAMCache+BeaconCtrl.h"

static SAMCache *bcl_monitoredProximityCache;
static SAMCache *bcl_lastActionEventsCache;
static SAMCache *bcl_actionEventsCache;

@implementation SAMCache (BeaconCtrl)

+ (SAMCache *) bcl_monitoredProximityCache
{
    if (bcl_monitoredProximityCache != nil) {
        return bcl_monitoredProximityCache;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bcl_monitoredProximityCache = [[SAMCache alloc] initWithName:[NSString stringWithFormat:@"com.up-next.BeaconCtrl.monitored"]];
    });
    
    return bcl_monitoredProximityCache;
}

+ (SAMCache *)bcl_lastActionEventsCache
{
    if (bcl_lastActionEventsCache != nil) {
        return bcl_lastActionEventsCache;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bcl_lastActionEventsCache = [[SAMCache alloc] initWithName:[NSString stringWithFormat:@"com.up-next.BeaconCtrl.lastActionEventsCache"]];
    });
    
    return bcl_lastActionEventsCache;
}

+ (SAMCache *)bcl_actionEventsCache
{
    if (bcl_actionEventsCache != nil) {
        return bcl_actionEventsCache;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bcl_actionEventsCache = [[SAMCache alloc] initWithName:[NSString stringWithFormat:@"com.up-next.BeaconCtrl.actionEventsCache"]];
    });
    
    return bcl_actionEventsCache;
}

@end
