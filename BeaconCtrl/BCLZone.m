//
//  BCLZone.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLZone.h"
#import "BCLBeacon.h"
#import "BCLUtils.h"
#import "UIColor+Hex.h"
#import <UNNetworking/UNCodingUtil.h>

@implementation BCLZone

- (instancetype)initWithIdentifier:(NSString *)zoneIdentifier name:(NSString *)name
{
    if (self = [super init]) {
        _zoneIdentifier = zoneIdentifier;
        _name = name;
    }
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ id: %@", self.name, self.zoneIdentifier];
}

- (void)updatePropertiesFromDictionary:(NSDictionary *)dictionary beacons:(NSSet *)beaconsSet
{
    self->_name = dictionary[@"name"];
    self->_zoneIdentifier = [dictionary[@"id"] description];
    
    // convert number value to string
    NSMutableSet *beaconIds = [NSMutableSet set];
    for (NSNumber *number in dictionary[@"beacon_ids"]) {
        NSAssert([number isKindOfClass:[NSNumber class]], @"Invalid data - beacon_ids");
        [beaconIds addObject:number.description];
    }

    if (dictionary[@"color"]) {
        self.color = [UIColor colorFromHexString:dictionary[@"color"]];
    }
    
    // store found beacons
    NSHashTable *beacons = [NSHashTable weakObjectsHashTable];
    for (BCLBeacon *beacon in [beaconsSet filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"beaconIdentifier IN %@",beaconIds]]) {
        [beacons addObject:beacon];
        beacon.zone = self;
    }
    self->_beacons = beacons;
}

- (NSArray *)triggers
{
    @synchronized(self) {
        if (!_triggers) {
            _triggers = [NSArray array];
        }
        return _triggers;
    }
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    BCLZone *copyZone = [[BCLZone alloc] init];
    UNCodingUtil *codingHelper = [[UNCodingUtil alloc] initWithObject:self];
    for (NSString *propertyKey in codingHelper.allProperties) {
        [copyZone setValue:[self valueForKey:propertyKey] forKey:propertyKey];
    }
    
    return copyZone;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (!self) {
        return nil;
    }
    [UNCodingUtil decodeObject:self withCoder:aDecoder];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [UNCodingUtil encodeObject:self withCoder:aCoder];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

#pragma mark UNCoding

- (instancetype) initWithDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        [[[UNCodingUtil alloc] initWithObject:self] loadDictionaryRepresentation:dictionary];
    }
    return self;
}

- (NSDictionary *) dictionaryRepresentation
{
    return [[[UNCodingUtil alloc] initWithObject:self] dictionaryRepresentation];
}

- (NSArray *)propertiesToExcludeFromEncoding
{
    return @[];
}

@end
