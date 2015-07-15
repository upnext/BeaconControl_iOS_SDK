//
//  BCLExtension.h
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLTypes.h"

@class BCLBeacon;

@protocol BCLExtension <NSObject>
@required

+ (NSString *) bcl_extensionName;
- (instancetype) initWithParameters:(NSDictionary *)parameters;

- (void) event:(BCLEventType)eventType forBeacon:(BCLBeacon *)beacon;

@end
