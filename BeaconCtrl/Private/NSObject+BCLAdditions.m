//
//  NSObject+BCLAdditions.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "NSObject+BCLAdditions.h"

@implementation NSObject (BCLAdditions)

- (id) bcl_performSelector:(SEL)selector withParameters:(NSArray *)parameters
{
    // perform selector
    NSMethodSignature *sig = [self methodSignatureForSelector:selector];
    if (!sig)
        return nil;

    NSInvocation* invo = [NSInvocation invocationWithMethodSignature:sig];
    [invo setSelector:selector];
    [invo retainArguments];

    for (NSInteger idx = 0; idx < parameters.count; idx++) {
        id parameter = parameters[idx];
        if (parameter != [NSNull null]) {
            [invo setArgument:&parameter atIndex:idx + 2];
        }
    }

    [invo invokeWithTarget:self];
    if (sig.methodReturnLength) {
        id anObject;
        [invo getReturnValue:&anObject];
        return anObject;
    }
    return nil;
}

@end
