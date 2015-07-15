//
//  NSUserDefaults+BCLiCloud.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

@interface NSUserDefaults (BCLiCloud)

-(void)setValue:(id)value  forKey:(NSString *)key iCloudSync:(BOOL)sync;
-(void)setObject:(id)value forKey:(NSString *)key iCloudSync:(BOOL)sync;

-(id)valueForKey:(NSString *)key  iCloudSync:(BOOL)sync;
-(id)objectForKey:(NSString *)key iCloudSync:(BOOL)sync;

-(BOOL)synchronizeWithiCloud;

@end
