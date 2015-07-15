//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "CLBeacon+BeaconCtrl.h"

@implementation CLBeacon (BeaconCtrl)

- (NSString *) bcl_identifier
{
    @synchronized(self) {
        // Build identifier
        
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:3];
        if (self.proximityUUID) {
            [arr addObject:self.proximityUUID.UUIDString];
        }
        
        if (self.major) {
            [arr addObject:self.major];
        }
        
        if (self.minor) {
            [arr addObject:self.minor];
        }
        
        return [arr componentsJoinedByString:@"+"];
    }
}

@end
