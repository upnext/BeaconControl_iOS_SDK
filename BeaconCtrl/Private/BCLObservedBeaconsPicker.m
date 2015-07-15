//
//  BCLObservedBeaconsPicker.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLObservedBeaconsPicker.h"
#import "BCLBeacon.h"
#import "BCLZone.h"

static NSUInteger const BCLObservedBeaconsPickerMaxObservedBeaconsCount = 16;
static CGFloat const BCLMinimumDistanceChangeForRecalculation = 6.0;

@interface BCLObservedBeaconsPicker ()

@property (nonatomic, copy) NSDictionary *allBeaconsDictionary; // dictionary of sets
@property (nonatomic, copy) NSSet *allZones;

@property (nonatomic, strong) BCLLocation *lastCheckedLocation;
@property (nonatomic, strong) NSSet *lastComputedObservedBeacons;
@property (nonatomic, strong) NSSet *lastComputedObservedZones;
@property (nonatomic) BOOL shouldZonesBeRecalculated;

@end

@implementation BCLObservedBeaconsPicker

- (instancetype)initWithBeacons:(NSSet *)beacons andZones:(NSSet *)zones
{
    if (self = [super init]) {
        NSMutableDictionary *allBeaconsMutableDictionary = [NSMutableDictionary dictionaryWithCapacity:beacons.count];
        
        // Store all beacons in a dictionary with floor numbers as keys and
        // sets of beacons as values
        
        __block NSNumber *normalizedLocationFloor;
        
        [beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
            
            normalizedLocationFloor = beacon.location.floor ? : @-1;
            
            if (!allBeaconsMutableDictionary[normalizedLocationFloor]) {
                allBeaconsMutableDictionary[normalizedLocationFloor] = [NSMutableSet set];
            }
            
            [allBeaconsMutableDictionary[normalizedLocationFloor] addObject:beacon];
        }];
        
        _allBeaconsDictionary = [allBeaconsMutableDictionary copy];
        _allZones = zones;
        _shouldZonesBeRecalculated = YES;
    }
    
    return self;
}

- (NSSet *)observedBeaconsWithLocation:(BCLLocation *)location beaconsDidChange:(BOOL *)didChange
{
    /*
     Returns a set that contains closest beacons from the given location's floor
     plus at least one closest beacon from each adjacent florr (well... there are at most two
     adjacent floors ;))
     
     If the floor is not given, it returns the nearest beacons, without checking up their floors
     */
    
    // Return last computed beacons is given location doesn't differ significantly
    // from the last calculated one
    if (self.lastCheckedLocation && [self.lastCheckedLocation.location distanceFromLocation:location.location] < BCLMinimumDistanceChangeForRecalculation && ([self.lastCheckedLocation.floor isEqual:location.floor] || self.lastCheckedLocation.floor == location.floor)) {
        *didChange = NO;
        return self.lastComputedObservedBeacons;
    }
    
    self.lastCheckedLocation = location;
    
    __block NSSet *adjacentFloorNumbersSet = [NSSet set];
    NSArray *sortedAvailableFloors = [[self.allBeaconsDictionary.allKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }] copy];
    
    // We're only interested in adjacent floors, if the floor is given
    // Otherwise, we ignore beacons' floors
    
    NSMutableArray *otherAvailableFloors;
    
    if (location.floor) {
        // Get an array of available floors other than the requested location's floor
        otherAvailableFloors = sortedAvailableFloors.mutableCopy;
        [otherAvailableFloors removeObject:location.floor];
        
        // Calculate which adjacent floors should we also monitor for (so that it's possible at all to
        // move from one floor to another)
        adjacentFloorNumbersSet = [NSSet set];
        [otherAvailableFloors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([location.floor compare:obj] == NSOrderedAscending) {
                if (idx == 0) {
                    adjacentFloorNumbersSet = [NSSet setWithArray:@[obj]];
                } else {
                    adjacentFloorNumbersSet = [NSSet setWithArray:@[otherAvailableFloors[idx -1], obj]];
                }
                *stop = YES;
            } else if (idx + 1 == otherAvailableFloors.count) {
                adjacentFloorNumbersSet = [NSSet setWithArray:@[obj]];
            }
        }];
    }
    
    // Get the observed beacons for the requested location's floor
    NSNumber *adjacentFloorsCapacity;
    if (adjacentFloorNumbersSet.count == 0) {
        adjacentFloorsCapacity = @0;
    } else if (adjacentFloorNumbersSet.count == 1) {
        adjacentFloorsCapacity = @(3);
    } else {
        adjacentFloorsCapacity = @(2);
    }
    
    NSUInteger givenFloorBeaconsCapacity = BCLObservedBeaconsPickerMaxObservedBeaconsCount - (adjacentFloorsCapacity.integerValue * adjacentFloorNumbersSet.count);
    
    NSMutableArray *observedBeacons = [[self sortedBeaconsWithLocation:location floor:location.floor capacityNumber:@(givenFloorBeaconsCapacity)] mutableCopy];
    
    // Get at least one closest beacon from each of the adjacent floors
    __block NSArray *otherFloorFirstBeaconArray;
    
    [adjacentFloorNumbersSet enumerateObjectsUsingBlock:^(id floorNumber, BOOL *stop) {
        otherFloorFirstBeaconArray = [self sortedBeaconsWithLocation:location floor:floorNumber capacityNumber:adjacentFloorsCapacity];
        [observedBeacons addObjectsFromArray:otherFloorFirstBeaconArray];
    }];
    
    NSSet *observedBeaconsSet = [NSSet setWithArray:observedBeacons];
    
    *didChange = ![self.lastComputedObservedBeacons isEqualToSet:observedBeaconsSet];
    
    self.lastComputedObservedBeacons = observedBeaconsSet;
    
    return self.lastComputedObservedBeacons;
}

- (NSSet *)observedZones:(BOOL *)didChange
{
    if (!self.shouldZonesBeRecalculated) {
        return self.lastComputedObservedZones;
    }
    
    if (!self.lastComputedObservedBeacons) {
        return nil;
    }
    
    self.shouldZonesBeRecalculated = NO;
    
    NSMutableSet *observedZones = [NSMutableSet set];
    
    __block BCLZone *currentZone;
    [self.lastComputedObservedBeacons enumerateObjectsUsingBlock:^(id beaconObj, BOOL *stop) {
        [self.allZones enumerateObjectsUsingBlock:^(id zoneObj, BOOL *innerStop) {
            currentZone = zoneObj;
            if ([currentZone.beacons containsObject:beaconObj]) {
                [observedZones addObject:currentZone];
            }
        }];
    }];
    
    NSSet *result = [observedZones copy];
    
    *didChange = ![result isEqual:self.lastComputedObservedZones];
    
    self.lastComputedObservedZones = result;
    
    return result;
}

#pragma mark - Private

- (NSArray *)sortedBeaconsWithLocation:(BCLLocation *)location floor:(NSNumber *)floor capacityNumber:(NSNumber *)capacity
{
    NSArray *observedBeacons;
    
    // If no floor is specified, we're looking on all floors
    if (floor) {
        observedBeacons = [self.allBeaconsDictionary[floor] copy];
    } else {
        NSMutableArray *mutableObservedBeacons = [NSMutableArray array];
        
        [self.allBeaconsDictionary.allKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSAssert([self.allBeaconsDictionary[obj] isKindOfClass:[NSSet class]], @"Invalid object class");
            [mutableObservedBeacons addObjectsFromArray:[self.allBeaconsDictionary[obj] allObjects]];
        }];
        
        observedBeacons = [mutableObservedBeacons copy];
    }

    __block BCLBeacon *beacon1;
    __block BCLBeacon *beacon2;
    __block CLLocationDistance beacon1Distance;
    __block CLLocationDistance beacon2Distance;

    observedBeacons = [observedBeacons sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        beacon1 = (BCLBeacon *)obj1;
        beacon2 = (BCLBeacon *)obj2;

        if (!beacon1.location || !beacon2.location) {
            NSLog(@"");
        }
        
        beacon1Distance = [beacon1.location.location distanceFromLocation:location.location];
        beacon2Distance = [beacon2.location.location distanceFromLocation:location.location];

        if (!beacon1.location && beacon2.location) {
            return NSOrderedDescending;
        } else if (!beacon2.location && beacon1.location) {
            return NSOrderedAscending;
        } if (beacon1Distance > beacon2Distance) {
            return NSOrderedDescending;
        } else if (beacon1Distance < beacon2Distance) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];

    if (capacity && observedBeacons.count > capacity.integerValue) {
        observedBeacons = [observedBeacons subarrayWithRange:NSMakeRange(0, capacity.integerValue)];
    }
    
    return observedBeacons;
}

@end
