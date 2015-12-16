//
//  BCLConfiguration.m
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLConfiguration.h"
#import "BCLBeacon.h"
#import "BCLZone.h"
#import "BCLTrigger.h"

#import <objc/runtime.h>

@interface BCLConfiguration ()
@property (strong, nonatomic, readwrite) NSSet <BCLExtension> *extensions;
@property (strong, nonatomic, readwrite) NSSet *beacons;
@property (strong, nonatomic, readwrite) NSSet *zones;
@property (copy, nonatomic, readwrite) NSString *kontaktIOAPIKey;
@end

@implementation BCLConfiguration

- (instancetype) init
{
    if (self = [super init]) {
        self.beacons = [NSSet set];
    }
    return self;
}

- (instancetype) initWithJSON:(NSData *)jsonData
{
    if (self = [self init]) {
        [self loadFromJSON:jsonData];
    }
    return self;
}

- (NSSet<BCLExtension> *)extensions
{
    if (!_extensions) {
        _extensions = (NSSet <BCLExtension> *)[NSSet set];
    }
    return _extensions;
}

- (BOOL) loadFromJSON:(NSData *)jsonData
{
    // load json and translato to BeaconCtrl format
    NSError *error = nil;
    NSDictionary *configurationDictionary = nil;
    if (jsonData) {
        configurationDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    }
    if (error || !configurationDictionary)
        return NO;

    // Load and initialize extension classess
    NSDictionary *extensionsDictionary = configurationDictionary[@"extensions"];
    if (extensionsDictionary) {
        for (NSString *extensionKey in extensionsDictionary.allKeys) {
            Class extensionClass = [BCLConfiguration classForName:extensionKey protocol:@protocol(BCLExtension) selector:@selector(bcl_extensionName)];
            if (extensionClass) {
                id <BCLExtension> extensionImpl = [[extensionClass alloc] initWithParameters:extensionsDictionary[extensionKey]];
                self.extensions = (NSSet <BCLExtension> *)[self.extensions setByAddingObject:extensionImpl];
            }
        }
    }

    // Load beacons
    NSMutableSet *beaconsSet = [NSMutableSet set];

    for (NSDictionary *beaconDictionary in configurationDictionary[@"ranges"]) {
        BCLBeacon *beacon = [[BCLBeacon alloc] init];
        [beacon updatePropertiesFromDictionary:beaconDictionary];
        [beaconsSet addObject:beacon];
    }

    // load zones
    NSMutableSet *zonesSet = [NSMutableSet set];
    
    for (NSDictionary *zoneDictionary in configurationDictionary[@"zones"]) {
        BCLZone *zone = [[BCLZone alloc] init];
        [zone updatePropertiesFromDictionary:zoneDictionary beacons:beaconsSet];
        [zonesSet addObject:zone];
    }
    
    // load triggers
    for (NSDictionary *triggerDictionary in configurationDictionary[@"triggers"]) {
        [triggerDictionary[@"range_ids"] enumerateObjectsUsingBlock:^(NSNumber *beaconId, NSUInteger idx, BOOL *stop) {
            BCLTrigger *trigger = [[BCLTrigger alloc] init];
            
            if ([beaconId isEqual:@236]) {
                NSLog(@"");
            }
            
            NSSet *beaconSet = [beaconsSet filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"beaconIdentifier == %@", beaconId.description]];
            for (BCLBeacon *beacon in beaconSet) {
                trigger.beacon = beacon; //FIXME: fix strong cross reference
                [trigger updatePropertiesFromDictionary:triggerDictionary];
                beacon.triggers = [beacon.triggers arrayByAddingObject:trigger];
            }
        }];
        
        [triggerDictionary[@"zone_ids"] enumerateObjectsUsingBlock:^(NSNumber *zoneId, NSUInteger idx, BOOL *stop) {
            BCLTrigger *trigger = [[BCLTrigger alloc] init];
            
            NSSet *zoneSet = [zonesSet filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"zoneIdentifier == %@", zoneId.description]];
            for (BCLZone *zone in zoneSet) {
                trigger.zone = zone; //FIXME: fix strong cross reference
                [trigger updatePropertiesFromDictionary:triggerDictionary];
                zone.triggers = [zone.triggers arrayByAddingObject:trigger];
            }
        }];
    }

    
    
    self.beacons = [beaconsSet copy];
    self.zones = [zonesSet copy];
    
    if (configurationDictionary[@"kontakt_api_key"] != [NSNull null] && ![configurationDictionary[@"kontakt_api_key"] isEqualToString:@""]) {
        self.kontaktIOAPIKey = configurationDictionary[@"kontakt_api_key"];
    }
    
    return YES;
}

+ (Class) classForName:(NSString *)name protocol:(Protocol *)protocol selector:(SEL)nameSelector
{
    int numberOfClasses = objc_getClassList(NULL, 0);
    Class classList[numberOfClasses];
    numberOfClasses = objc_getClassList(classList, numberOfClasses);

    for (int idx = 0; idx < numberOfClasses; idx++)
    {
        Class class = classList[idx];
        if (class_getClassMethod(class, @selector(conformsToProtocol:)) && [class conformsToProtocol:protocol])
        {
#ifdef DEBUG
            NSLog(@"Found class %@ (%@)", NSStringFromClass(class), NSStringFromProtocol(protocol));
#endif
            Class <BCLExtension> extensionClass = class;
            if ([class respondsToSelector:nameSelector]) {
                NSString *identifier = [class performSelector:nameSelector];
                if ([identifier isEqualToString:name]) {
                    return extensionClass;
                }
            }
        }
    }
    return nil;
}

@end
