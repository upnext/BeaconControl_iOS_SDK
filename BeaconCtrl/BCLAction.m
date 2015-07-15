//
//  BCLAction.m
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

static NSString * const BCLActionCouponTypeName = @"coupon";
static NSString * const BCLActionURLTypeName = @"url";
static NSString * const BCLActionCouponURLAttrName = @"url";

#import "BCLAction.h"
#import "UNCodingUtil.h"

@implementation BCLAction

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (%@)", self.name, self.type];
}

- (BOOL)isCouponAction
{
    return [self.type.lowercaseString isEqualToString:BCLActionCouponTypeName];
}

- (BOOL)isUrlAction
{
    return [self.type.lowercaseString isEqualToString:BCLActionURLTypeName];
}

- (NSURL *)URL
{
    if (!self.isCouponAction && !self.isUrlAction) {
        return nil;
    }
    
    return [NSURL URLWithString:self.payload[BCLActionCouponURLAttrName]];
}

@end
