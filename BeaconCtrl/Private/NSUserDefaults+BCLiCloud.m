//
//  NSUserDefaults+BCLiCloud.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "NSUserDefaults+BCLiCloud.h"

@implementation NSUserDefaults (BCLiCloud)

-(void)setValue:(id)value forKey:(NSString *)key iCloudSync:(BOOL)sync
{
    if (sync)
        [[NSUbiquitousKeyValueStore defaultStore] setValue:value forKey:key];

    [self setValue:value forKey:key];
}

-(id)valueForKey:(NSString *)key iCloudSync:(BOOL)sync
{
    if (sync)
    {
        //Get value from iCloud
        id value = [[NSUbiquitousKeyValueStore defaultStore] valueForKey:key];

        //Store locally and synchronize
        [self setValue:value forKey:key];
        [self synchronize];

        return value;
    }

    return [self valueForKey:key];
}

- (void)removeValueForKey:(NSString *)key iCloudSync:(BOOL)sync
{
    [self removeObjectForKey:key iCloudSync:sync];
}



-(void)setObject:(id)value forKey:(NSString *)defaultName iCloudSync:(BOOL)sync
{
    if (sync)
        [[NSUbiquitousKeyValueStore defaultStore] setObject:value forKey:defaultName];

    [self setObject:value forKey:defaultName];
}

-(id)objectForKey:(NSString *)key iCloudSync:(BOOL)sync
{
    if (sync)
    {
        //Get value from iCloud
        id value = [[NSUbiquitousKeyValueStore defaultStore] objectForKey:key];

        //Store to NSUserDefault and synchronize
        [self setObject:value forKey:key];
        [self synchronize];

        return value;
    }

    return [self objectForKey:key];
}

- (void)removeObjectForKey:(NSString *)key iCloudSync:(BOOL)sync
{
    if (sync)
        [[NSUbiquitousKeyValueStore defaultStore] removeObjectForKey:key];

    //Remove from NSUserDefault
    return [self removeObjectForKey:key];
}



-(BOOL)synchronizeWithiCloud
{
    BOOL res = true;

    res &= [self synchronize];
    res &= [[NSUbiquitousKeyValueStore defaultStore] synchronize];
    
    return res;
}

@end
