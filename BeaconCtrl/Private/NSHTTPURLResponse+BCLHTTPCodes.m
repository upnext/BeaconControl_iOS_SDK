//
//  NSHTTPURLResponse+BCLHTTPCodes.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "NSHTTPURLResponse+BCLHTTPCodes.h"

@implementation NSHTTPURLResponse (BCLHTTPCodes)

- (BOOL) isInformational
{
    return (self.statusCode >= 100 && self.statusCode < 200);
}

- (BOOL) isSuccess
{
    return (self.statusCode >= 200 && self.statusCode < 300) || [self isRedirect] || [self isInformational];
}

- (BOOL) isRedirect
{
    return (self.statusCode >= 300 && self.statusCode < 400);
}

- (BOOL) isClientError
{
    return (self.statusCode >= 400 && self.statusCode < 500);
}

- (BOOL) isServerError
{
    return (self.statusCode >= 500 && self.statusCode < 600);
}

@end
