//
//  BCLLocation.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLLocation.h"
#import <UNNetworking/UNCodingUtil.h>

@interface BCLLocation ()

@property (nonatomic, strong, readwrite) CLLocation *location;
@property (nonatomic, strong, readwrite) NSNumber *floor;

@end

@implementation BCLLocation

- (instancetype)initWithLocation:(CLLocation *)location floor:(NSNumber *)floor
{
    if (self = [super init]) {
        _location = location;
        _floor = floor;
    }
    
    return self;
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
