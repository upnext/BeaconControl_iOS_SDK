//
//  UIColor+Hex.h
//  Pods
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>

@interface UIColor (Hex)

+ (UIColor *)colorFromHexString:(NSString *)hexString;
- (NSString *)hexString;

@end
