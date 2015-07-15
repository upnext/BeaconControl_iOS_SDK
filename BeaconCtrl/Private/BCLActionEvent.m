//
//  BCLEvent.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLActionEvent.h"
#import "BCLActionEventScheduler.h"
#import <UNCodingUtil.h>

@implementation BCLActionEvent

- (instancetype)init
{
    if (self = [super init]) {
        _identifier = [[NSUUID UUID] UUIDString];
        _timestamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    BCLActionEvent *copyEvent = [[BCLActionEvent alloc] init];
    UNCodingUtil *codingHelper = [[UNCodingUtil alloc] initWithObject:self];
    for (NSString *propertyKey in codingHelper.allProperties) {
        [self setValue:[self valueForKey:propertyKey] forKey:propertyKey];
    }
    return copyEvent;
}

- (NSString *)eventTypeName
{
    switch (self.eventType) {
        case BCLEventTypeEnter:
            return @"enter";
        case BCLEventTypeLeave:
            return @"leave";
        case BCLEventTypeRangeFar:
            return @"far";
        case BCLEventTypeRangeNear:
            return @"near";
        case BCLEventTypeRangeImmediate:
            return @"immediate";
        case BCLEventTypeDwellTime:
            return @"dwell_time";
        default:
            return nil;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Action Event: type: %@ - beacon_id: %@ - zone_id: %@ - timestamp: %f ", self.eventTypeName, self.beaconIdentifier, self.zoneIdentifier, self.timestamp];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
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

@end
