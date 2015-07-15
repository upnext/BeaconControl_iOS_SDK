//
//  UIColor+Hex.m
//  Pods
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "UIColor+Hex.h"

@implementation UIColor (Hex)

+ (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

- (NSString *)hexString
{
    const CGFloat *components = CGColorGetComponents(self.CGColor);

    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    
    NSString *result = [[NSString stringWithFormat:@"%02lX%02lX%02lX",
                        lroundf(r * 255),
                        lroundf(g * 255),
                        lroundf(b * 255)] lowercaseString];

    return result;
}

@end
