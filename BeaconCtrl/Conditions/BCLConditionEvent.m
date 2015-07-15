//
//  BCLConditionEvent.m
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLConditionEvent.h"
#import "UNCodingUtil.h"
#import "BCLBeacon.h"

@implementation BCLConditionEvent

+ (NSString *)bcl_conditionType
{
    return @"event_type";
}

- (instancetype)initWithParameters:(NSDictionary *)parameters
{
    if (self = [self init]) {
        _eventType = parameters[@"event_type"];
    }
    return self;
}

- (BOOL)evaluateCondition:(BCLEventType)eventType forBeacon:(BCLBeacon *)beacon
{
    if ((eventType == BCLEventTypeEnter) && [self.eventType isEqualToString:@"enter"]) {
        return YES;
    } else if ((eventType == BCLEventTypeLeave) && [self.eventType isEqualToString:@"leave"]) {
        return YES;
    } else if ((eventType == BCLEventTypeRangeFar) && [self.eventType isEqualToString:@"far"]) {
        return YES;
    } else if ((eventType == BCLEventTypeRangeNear) && [self.eventType isEqualToString:@"near"]) {
        return YES;
    } else if ((eventType == BCLEventTypeRangeImmediate) && [self.eventType isEqualToString:@"immediate"]) {
        return YES;
    }
    return NO;
}

- (BOOL)evaluateCondition:(BCLEventType)eventType forZone:(BCLZone *)zone
{
    if ((eventType == BCLEventTypeEnter) && [self.eventType isEqualToString:@"enter"]) {
        return YES;
    } else if ((eventType == BCLEventTypeLeave) && [self.eventType isEqualToString:@"leave"]) {
        return YES;
    }
    
    return NO;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
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

@end
