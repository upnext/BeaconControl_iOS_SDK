//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLBeacon.h"

#import <SAMCache/SAMCache.h>
#import <UNNetworking/UNCodingUtil.h>
#import "BCLBeaconCtrl.h"

#import "CLBeacon+BeaconCtrl.h"
#import "BCLLocation.h"


#define NSUINT_BIT (CHAR_BIT * sizeof(NSUInteger))
#define NSUINTROTATE(val, howmuch) ((((NSUInteger)val) << howmuch) | (((NSUInteger)val) >> (NSUINT_BIT - howmuch)))

NSString * const BCLInvalidBeaconIdentifierException = @"BCLInvalidBeaconIdentifierException";
NSString * const BCLBeaconTimerFireNotification = @"BCLBeaconTimerFireNotification";

const int kMaxAccuracyReadouts = 5;
const int kResetAccuracyReadoutsInterval = 60;

@interface BCLBeacon ()

@property (strong) dispatch_source_t timer;
@property (assign) BOOL timerIsActive;

@property (nonatomic, strong) NSMutableArray *accuracyReadouts;
@property (nonatomic, strong) NSDate *lastAccuracyReadoutDate;

@property (nonatomic, strong) NSMutableDictionary *proximitiesSetTimestampsMapping;

@end

@implementation BCLBeacon

@synthesize proximityUUID = _proximityUUID;
@synthesize major = _major;
@synthesize minor = _minor;
@synthesize accuracy = _accuracy;
@synthesize proximity = _proximity;
@synthesize rssi = _rssi;

- (instancetype) init
{
    if (self = [super init]) {
        // remove only if period of time is significant
        SAMCache *staysCache = [[SAMCache alloc] initWithName:BLEBeaconStaysCacheName(self)];
        [staysCache removeAllObjects];
        
        [self scheduleStaysTimer];
        
        self.proximitiesSetTimestampsMapping = [@{
                                                  @(CLProximityFar)          : @0,
                                                  @(CLProximityNear)         : @0,
                                                  @(CLProximityImmediate)    : @0
                                                  } mutableCopy];
    }
    return self;
}


- (instancetype) initWithIdentifier:(NSString *)beaconIdentifier proximityUUID:(NSUUID *)proximityUUID major:(NSNumber *)major minor:(NSNumber *)minor
{
    if (self = [self init]) {
        self.proximityUUID = proximityUUID;
        self.major = major;
        self.minor = minor;
        self.beaconIdentifier = beaconIdentifier;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    BCLBeacon *copyBeacon = [super copyWithZone:zone];

    copyBeacon.proximityUUID = self.proximityUUID;
    copyBeacon.major = self.major;
    copyBeacon.minor = self.minor;
    copyBeacon.proximity = self.proximity;
    copyBeacon.accuracy = self.accuracy;
    copyBeacon.estimatedDistance = self.estimatedDistance;
    copyBeacon.rssi = self.rssi;
    copyBeacon.lastEnteredDate = self.lastEnteredDate;
    copyBeacon.location = self.location;
    copyBeacon.zone = self.zone;
    copyBeacon.name = self.name;
    copyBeacon.triggers = self.triggers;
    copyBeacon.beaconIdentifier = self.beaconIdentifier;
    copyBeacon.onEnterCallback = self.onEnterCallback;
    copyBeacon.onExitCallback = self.onExitCallback;
    copyBeacon.onChangeProximityCallback = self.onChangeProximityCallback;
    copyBeacon.vendor = self.vendor;
    copyBeacon.vendorIdentifier = self.vendorIdentifier;
    copyBeacon.needsCharacteristicsUpdate = self.needsCharacteristicsUpdate;
    copyBeacon.protocol = self.protocol;
    copyBeacon.namespaceId = self.namespaceId;
    copyBeacon.instanceId = self.instanceId;
    copyBeacon.vendorFirmwareVersion = self.vendorFirmwareVersion;
    copyBeacon.batteryLevel = self.batteryLevel;
    copyBeacon.transmissionInterval = self.transmissionInterval;
    copyBeacon.transmissionPower = self.transmissionPower;

    return copyBeacon;
}

- (CLLocationCoordinate2D)coordinate
{
    return self.location.location.coordinate;
}

- (NSString *)title
{
    return [NSString stringWithFormat:@"Name: %@, floor: %@", self.name, self.location.floor];
}

- (NSString *)identifier
{
    return self.bcl_identifier;
}

- (BOOL)isEqual:(id)other
{
    if(![other isKindOfClass: [self class]])
        return NO;
    
    BOOL ret = NO;
    if ([other respondsToSelector:@selector(identifier)]) {
        ret = self == other;
    }
    
    return ret;
}

- (NSUInteger)hash
{
    NSUInteger outHash = [_proximityUUID hash];
    outHash = NSUINTROTATE(outHash, NSUINT_BIT / 2) ^ [_major hash];
    outHash = NSUINTROTATE(outHash, NSUINT_BIT / 2) ^ [_minor hash];
    outHash = NSUINTROTATE(outHash, NSUINT_BIT / 2) ^ [_name hash];
    return outHash;
}

- (NSString *) debugDescription
{
    return self.identifier;
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

- (NSTimeInterval) staysTimeInterval
{
    SAMCache *staysCache = [[SAMCache alloc] initWithName:BLEBeaconStaysCacheName(self)];
    NSDate *lastEnter = [staysCache objectForKey:self.identifier];
    if (lastEnter) {
        return [[NSDate date] timeIntervalSinceDate:lastEnter];
    }
    return 0;
}

- (void) scheduleStaysTimer
{
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    if (self.timer)
    {
        __weak typeof(self)selfWeak = self;
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            __strong __typeof(self)selfStrong = selfWeak;
            if (self.timerIsActive) {
                dispatch_suspend(selfStrong.timer);
                selfStrong.timerIsActive = NO;
            }
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            __strong __typeof(self)selfStrong = selfWeak;
            if (!self.timerIsActive) {
                dispatch_resume(selfStrong.timer);
                selfStrong.timerIsActive = YES;
            }
        }];
        
        
        dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, 0), 60 * NSEC_PER_SEC, 1 * NSEC_PER_SEC); // 1m, 1s
        dispatch_source_set_event_handler(self.timer, ^{
            if (!selfWeak.proximityUUID) {
                return;
            }
            
            __strong __typeof(self)selfStrong = selfWeak;
            @synchronized(selfStrong) {
#ifdef DEBUG
                NSLog(@"%@ Time based event for beacon %@.", [selfStrong class], selfStrong);
                if (selfStrong.proximity == CLProximityUnknown) {
                    NSLog(@"Beacon not in range!");
                } else {
                    NSLog(@"Beacon in range!");
                }
#endif
                [[NSNotificationCenter defaultCenter] postNotificationName:BCLBeaconTimerFireNotification object:selfStrong];
            }
        });
        
        self.timerIsActive = YES;
        dispatch_resume(self.timer);
    }
}

#pragma mark - Properties

- (NSMutableArray *)accuracyReadouts
{
    if (!_accuracyReadouts) {
        _accuracyReadouts = [NSMutableArray arrayWithCapacity:kMaxAccuracyReadouts + 1];
    }
    
    return _accuracyReadouts;
}

- (double)estimatedDistance
{
    if (!_estimatedDistance) {
        _estimatedDistance = NSNotFound;
    }
    
    return _estimatedDistance;
}

- (void)setAccuracy:(CLLocationAccuracy)accuracy
{
    _accuracy = accuracy;
    
    if (!accuracy) {
        self.estimatedDistance = NSNotFound;
        self.accuracyReadouts = nil;
        return;
    }
    
    NSDate *now = [NSDate date];
    
    if (self.lastAccuracyReadoutDate && [now timeIntervalSinceDate:self.lastAccuracyReadoutDate] > kResetAccuracyReadoutsInterval) {
        self.accuracyReadouts = nil;
    }
    
    self.lastAccuracyReadoutDate = now;
    
    [self.accuracyReadouts insertObject:@(accuracy) atIndex:0];
    
    if (self.accuracyReadouts.count > kMaxAccuracyReadouts) {
        [self.accuracyReadouts removeLastObject];
    }
    
    NSArray *sortedReadouts = [self.accuracyReadouts sortedArrayUsingSelector:@selector(compare:)];
    
    double estimatedDistance = [sortedReadouts[(int)(self.accuracyReadouts.count / 2)] doubleValue];
    
    if (!estimatedDistance) {
        estimatedDistance = NSNotFound;
    }
    
    self.estimatedDistance = estimatedDistance;
}

- (void)setProximity:(CLProximity)proximity
{
    self.proximitiesSetTimestampsMapping[@(proximity)] = @([[NSDate date] timeIntervalSince1970]);
    
    if (self.lastEnteredDate == nil && proximity != CLProximityUnknown) {
        self.lastEnteredDate = [NSDate date];
    } else if (self.lastEnteredDate != nil && proximity == CLProximityUnknown) {
        self.lastEnteredDate = nil;
    }
    
    _proximity = proximity;
}

- (BOOL)canSetProximity:(CLProximity)newProximity
{
    if (self.proximity == newProximity) {
        return NO;
    }
    
    if ([[NSDate date] timeIntervalSince1970] - [self.proximitiesSetTimestampsMapping[@(newProximity)] intValue] < 60) {
        return NO;
    }
    
    return YES;
}

#pragma mark - BLEUpdatableFromDictionary

- (void)updatePropertiesFromDictionary:(NSDictionary *)dictionary
{
    self->_name = dictionary[@"name"]!=[NSNull null]?dictionary[@"name"]:nil;
    self->_beaconIdentifier = [dictionary[@"id"] description];
    self->_protocol = [dictionary[@"protocol"] description];
    
    if (dictionary[@"location"] && dictionary[@"location"][@"lat"] != [NSNull null] && dictionary[@"location"][@"lng"] != [NSNull null]) {
        double lat = [dictionary[@"location"][@"lat"] doubleValue];
        double lng = [dictionary[@"location"][@"lng"] doubleValue];
        CLLocation *location = [[CLLocation alloc] initWithLatitude:lat longitude:lng];
        NSNumber *floor = dictionary[@"location"][@"floor"] != [NSNull null] ? dictionary[@"location"][@"floor"] : nil;
        self->_location = [[BCLLocation alloc] initWithLocation:location floor:floor];
    }
    
    if (dictionary[@"proximity_id"]) {
        NSString *idString = [dictionary[@"proximity_id"] description];
        NSError *error = NULL;
        
        if ([self->_protocol.lowercaseString isEqualToString:@"ibeacon"]) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^([\\w-]*)(\\+(\\d*)){0,1}(\\+(\\d*)){0,1}" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
            NSArray *matches =  [regex matchesInString:idString
                                               options:0
                                                 range:NSMakeRange(0, [idString length])];
            
            NSTextCheckingResult *match = matches[0];
            for (int idx = 1; idx < match.numberOfRanges; idx++) {
                NSRange range = [match rangeAtIndex:idx];
                if (range.location != NSNotFound && idx == 1) {
                    self.proximityUUID = [[NSUUID alloc] initWithUUIDString:[idString substringWithRange:range]];
                }
                
                if (range.location != NSNotFound && idx == 3) {
                    self.major = @([[idString substringWithRange:range] integerValue]);
                }
                
                if (range.location != NSNotFound && idx == 5) {
                    self.minor = @([[idString substringWithRange:range] integerValue]);
                }
            }
            
        } else if ([self->_protocol.lowercaseString isEqualToString:@"eddystone"]) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^([\\w-]*)\\+([\\w-]*)\\+([\\w-]*)" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
            NSArray *matches =  [regex matchesInString:idString
                                               options:0
                                                 range:NSMakeRange(0, [idString length])];
            
            NSTextCheckingResult *match = matches[0];
            for (int idx = 1; idx < match.numberOfRanges; idx++) {
                NSRange range = [match rangeAtIndex:idx];
                if (range.location != NSNotFound && idx == 1) {
                    self.proximityUUID = [[NSUUID alloc] initWithUUIDString:[idString substringWithRange:range]];
                }
                
                if (range.location != NSNotFound && idx == 3) {
                    self.namespaceId = [idString substringWithRange:range];
                }
                
                if (range.location != NSNotFound && idx == 5) {
                    self.instanceId = [idString substringWithRange:range];
                }
            }
        }
        
//        if (!self.proximityUUID) {
//            @throw [NSException exceptionWithName:BCLInvalidBeaconIdentifierException reason:[NSString stringWithFormat:@"Defined beacon identifier '%@' is invalid", idString] userInfo:dictionary];
//        }
    }
    
    self.vendor = dictionary[@"vendor"];
    
    if (dictionary[@"unique_id"] && dictionary[@"unique_id"] != [NSNull null]) {
        self.vendorIdentifier = dictionary[@"unique_id"];
    }
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return nil;
    }
    [UNCodingUtil decodeObject:self withCoder:aDecoder];
    
    [self scheduleStaysTimer];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
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
    return @[
             @"timer",
             @"accuracy",
             @"rssi",
             @"estimatedDistance"];
}

@end
