//
//  BCLBeaconCtrl.m
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <SAMCache/SAMCache.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <KontaktSDK-OLD/KTKBeacon.h>
#import <KontaktSDK-OLD/KTKBeaconDevice.h>

#import "BCLConfiguration.h"
#import "SAMCache+BeaconCtrl.h"
#import "BCLBeaconRangingBatch.h"
#import "CLBeacon+BeaconCtrl.h"
#import "BCLEventScheduler.h"
#import "BCLActionEventScheduler.h"
#import "BCLActionEvent.h"

#import "BCLBackend.h"

#import "BCLBeaconCtrl.h"
#import "BCLBeacon.h"
#import "BCLZone.h"
#import "BCLTrigger.h"

#import "BCLObservedBeaconsPicker.h"

#import "BCLActionHandlerFactory.h"

#import "BCLKontaktIOBeaconConfigManager.h"

#define BCLDelayEventTimeInterval 3

@import UserNotifications;

NSInteger const BCLInvalidParametersErrorCode = -1;
NSInteger const BCLInvalidDataErrorCode = -5;
NSInteger const BCLErrorHTTPError = -10;
NSInteger const BCLInvalidDeviceConfigurationError = -15;
NSString * const BCLBluetoothNotTurnedOnErrorKey = @"BCLBluetoothNotTurnedOnErrorKey";
NSString * const BCLDeniedMonitoringErrorKey = @"BCLDeniedMonitoringErrorKey";
NSString * const BCLDeniedLocationServicesErrorKey = @"BCLDeniedLocationServicesErrorKey";
NSString * const BCLDeniedBackgroundAppRefreshErrorKey = @"BCLDeniedBackgroundAppRefreshErrorKey";
NSString * const BCLDeniedNotificationsErrorKey = @"BCLDeniedNotificationsErrorKey";

static NSString * const BCLPreviousZoneKey = @"previousZone";
static NSString * const BCLCurrentZoneKey = @"currentZone";

NSString * const BCLErrorDomain = @"com.up-next.BCLBeaconCtrl";

static NSString * const monitoredRegionIdentifiersKey = @"monitoredRegionIdentifiers";

static NSString * const BCLBeaconCtrlCacheDirectoryName = @"BeaconCtrl";
static NSString * const BCLBeaconCtrlArchiveFilename = @"beacon_ctrl.data";

@interface BCLBeaconCtrl () <CLLocationManagerDelegate, CBCentralManagerDelegate, BCLBeaconRangingBatchDelegate, BCLKontaktIOBeaconConfigManagerDelegate >

@property (strong) CLLocationManager *locationManager;
@property (strong) CBCentralManager *bluetoothCentralManager;
@property (strong) BCLBeaconRangingBatch *beaconBatch;
@property (strong) BCLEventScheduler *eventScheduler;
@property (strong) BCLActionEventScheduler *actionEventScheduler;
@property (strong, nonatomic) BCLBackend *backend;

@property (nonatomic, copy, readwrite) NSSet *observedBeacons;

@property (nonatomic, strong) BCLActionHandlerFactory *actionHandlerFactory;

@property (nonatomic, strong) BCLObservedBeaconsPicker *observedBeaconsPicker;

@property (nonatomic, strong) BCLLocation *estimatedUserLocation;

@property (nonatomic, weak) BCLBeacon *cachedClosestBeacon;
@property (nonatomic, weak) BCLZone *cachedClosestZone;

@property (nonatomic, strong) BCLKontaktIOBeaconConfigManager *kontaktIOManager;

@property (nonatomic, strong) NSDictionary *previousZoneChange;
@property (nonatomic, strong) NSSet <CLRegion *> *initiallyMonitoredRegions;

@end

@implementation BCLBeaconCtrl

- (instancetype)init
{
    if (self = [super init]) {
        [self finishInitialization];
    }
    return self;
}

+ (BCLBeaconCtrl *)beaconCtrlRestoredFromCache
{
    return [NSKeyedUnarchiver unarchiveObjectWithFile:[[self cacheDirectoryPath] stringByAppendingPathComponent:BCLBeaconCtrlArchiveFilename]];
}

- (BOOL)storeInCache
{
    NSString *cacheDirectoryPath = [[self class] cacheDirectoryPath];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:cacheDirectoryPath]){
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return [NSKeyedArchiver archiveRootObject:self toFile:[cacheDirectoryPath stringByAppendingPathComponent:BCLBeaconCtrlArchiveFilename]];
}

+ (void)deleteBeaconCtrlFromCache
{
    [BCLActionEventScheduler clearCache];
    [[NSFileManager defaultManager] removeItemAtPath:[[self cacheDirectoryPath] stringByAppendingPathComponent:BCLBeaconCtrlArchiveFilename] error:nil];
}

+ (void)setupBeaconCtrlWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret userId:(NSString *)userId pushEnvironment:(BCLBeaconCtrlPushEnvironment)pushEnvironment pushToken:(NSString *)pushToken completion:(void (^)(BCLBeaconCtrl *, BOOL, NSError *))completion
{
    BCLBeaconCtrl *beaconCtrl = [self beaconCtrlRestoredFromCache];
    
    BOOL isRestoredFromCache = YES;
    
    if (![beaconCtrl.clientId isEqualToString:clientId] || ![beaconCtrl.clientSecret isEqualToString:clientSecret]) {
        [BCLBeaconCtrl deleteBeaconCtrlFromCache];
        beaconCtrl = [[BCLBeaconCtrl alloc] initWithClientId:clientId clientSecret:clientSecret pushEnvironment:pushEnvironment pushToken:pushToken];
        isRestoredFromCache = NO;
    }
    
    __weak typeof(self) weakSelf = self;
    
    void (^finishSetup)() = ^void() {
        if (completion) {
            completion(beaconCtrl, isRestoredFromCache, nil);
        }
    };
    
    if (isRestoredFromCache) {
        finishSetup();
        return;
    }
    
    [beaconCtrl fetchConfiguration:^(NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, isRestoredFromCache, error);
            }
            
            return;
        }
        beaconCtrl.backend.userId = userId;
        finishSetup();
    }];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSSet *)observedBeacons
{
    return _observedBeacons;
}

- (NSString *)userId
{
    return self.backend.userId;
}

- (NSString *)clientId
{
    return self.backend.clientId;
}

- (NSString *)clientSecret
{
    return self.backend.clientSecret;
}

- (BOOL)isBluetoothTurnedOn
{
    return self.bluetoothCentralManager.state == CBCentralManagerStatePoweredOn;
}

- (BOOL)isBeaconMonitoringAvailable
{
    return [CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]];
}

- (BOOL)isLocationServicesAvailable
{
    return [CLLocationManager authorizationStatus] > 2;
}

- (BOOL)isBackgroundAppRefreshAvailable
{
    return [[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusAvailable;
}

- (BOOL)isNotificationsAvailable
{
    UIUserNotificationSettings *remoteNotificationSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    return (remoteNotificationSettings.types & UIRemoteNotificationTypeAlert) || (remoteNotificationSettings.types & UIRemoteNotificationTypeBadge) || (remoteNotificationSettings.types & UIRemoteNotificationTypeSound);
}

- (BOOL)isBeaconCtrlReadyToProcessBeaconActions:(NSError *__autoreleasing *)error
{
    NSMutableDictionary *errorsDictUserInfo = [@{} mutableCopy];
    
    if (![self isBluetoothTurnedOn]) {
        errorsDictUserInfo[BCLBluetoothNotTurnedOnErrorKey] = @"Bluetooth is not turned on";
    }
    
    if (![self isBeaconMonitoringAvailable]) {
        errorsDictUserInfo[BCLDeniedMonitoringErrorKey] = @"The device is not capable of monitoring beacons";
    }
    
    if (![self isLocationServicesAvailable]) {
        errorsDictUserInfo[BCLDeniedLocationServicesErrorKey] = @"The user hasn't agreed for the app to use location services";
    }
    
    if (![self isBackgroundAppRefreshAvailable]) {
        errorsDictUserInfo[BCLDeniedBackgroundAppRefreshErrorKey] = @"The user hasn't agreed for the app to use background app refresh";
    }
    
    if (![self isNotificationsAvailable]) {
        errorsDictUserInfo[BCLDeniedNotificationsErrorKey] = @"The user hasn't agreed for the app to send notifications";
    }
    
    if (errorsDictUserInfo.allKeys.count) {
        if (error) {
            *error = [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidDeviceConfigurationError userInfo:errorsDictUserInfo.copy];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL) startMonitoringBeacons
{
    if ([[UIApplication sharedApplication] backgroundRefreshStatus] < UIBackgroundRefreshStatusAvailable)
        return NO;
    
    if (![CLLocationManager locationServicesEnabled]) {
        return NO;
    }
    
    if (![CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        return NO;
    }
    
    if (![CLLocationManager isRangingAvailable]) {
        return NO;
    }
    
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    
    if (authorizationStatus != kCLAuthorizationStatusNotDetermined && authorizationStatus != kCLAuthorizationStatusAuthorized && authorizationStatus != kCLAuthorizationStatusAuthorizedAlways && authorizationStatus != kCLAuthorizationStatusAuthorizedWhenInUse) {
        return NO;
    }

    BOOL result = [self updateMonitoredBeacons];

    self.initiallyMonitoredRegions = self.locationManager.monitoredRegions;
    [self performSelector:@selector(processInitiallyRangedRegions) withObject:nil afterDelay:3];
    return result;
}

- (void)processInitiallyRangedRegions
{
    for (CLRegion *region in self.initiallyMonitoredRegions) {
        [self.locationManager requestStateForRegion:region];
    }
}

- (void) stopMonitoringBeacons
{
    // Unregister only these regions monitored by BLEKit. It may be region registered outside BLEKit though (registered before of after BLEKit but we don't know that).
    NSSet *monitoredRegionIdentifiers = [[SAMCache bcl_monitoredProximityCache] objectForKey:monitoredRegionIdentifiersKey];
    NSSet *monitoredRegions = [self.locationManager.monitoredRegions filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.identifier IN %@",monitoredRegionIdentifiers]];
    for (CLBeaconRegion *region in monitoredRegions) {
        if ([self.locationManager.rangedRegions containsObject:region]) {
            [self.locationManager stopRangingBeaconsInRegion:region];
        }
        [self.locationManager stopMonitoringForRegion:region];
    }
    [[SAMCache bcl_monitoredProximityCache] removeObjectForKey:monitoredRegionIdentifiersKey];
    
    for (BCLBeacon *beacon in self.observedBeacons) {
        beacon.proximity = CLProximityUnknown;
        [self beaconProximityDidChange:beacon];
    }
    
    self.observedBeacons = nil;
}

/*!
 * @brief The main method that determines which beacons should currently be monitored, basing on the estimated location of the device
 */
- (BOOL)updateMonitoredBeacons
{
    BOOL didObservedBeaconsChange = NO;
    NSSet *beaconsToObserve = [self.observedBeaconsPicker observedBeaconsWithLocation:self.estimatedUserLocation beaconsDidChange:&didObservedBeaconsChange];
    
    // Register new regions
    NSMutableSet *monitoredRegionIdentifiers = [NSMutableSet setWithCapacity:beaconsToObserve.count];
    
    for (BCLBeacon *beacon in beaconsToObserve) {
        CLBeaconRegion *beaconRegion = nil;
        
        if (beacon.major && !beacon.minor) {
            beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:beacon.proximityUUID major:[beacon.major unsignedIntegerValue] identifier:beacon.identifier];
        } else if (beacon.major && beacon.minor) {
            beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:beacon.proximityUUID major:[beacon.major unsignedIntegerValue] minor:[beacon.minor unsignedIntegerValue] identifier:beacon.identifier];
        } else {
            beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:beacon.proximityUUID identifier:beacon.identifier];
        }
        beaconRegion.notifyOnEntry = YES;
        beaconRegion.notifyOnExit = YES;
        //FIXME: this perform didDetermineState every time phone go out of sleep
        //When set to YES, the location manager sends beacon notifications when the user turns on the display and the device is already inside the region.
        beaconRegion.notifyEntryStateOnDisplay = YES;
        
        if (self.locationManager != nil && ![self.locationManager.monitoredRegions containsObject:beaconRegion]) {
            [self.locationManager startMonitoringForRegion:beaconRegion];
        }
        
        if (beaconRegion) {
            if (![self.locationManager.rangedRegions containsObject:beaconRegion]) {
                [self.locationManager startRangingBeaconsInRegion:beaconRegion];
            }
            
            [monitoredRegionIdentifiers addObject:beaconRegion.identifier];
        }
    }
    
    // should I refresh observable regions?
    // remove previously monitored regions but not monitored any more. JSON changed.
    NSMutableSet *previouslyMonitoredRegionIdentifiers = [[[SAMCache bcl_monitoredProximityCache] objectForKey:monitoredRegionIdentifiersKey] mutableCopy];
    [previouslyMonitoredRegionIdentifiers minusSet:monitoredRegionIdentifiers];
    NSSet *regionsNotToMonitor = [self.locationManager.monitoredRegions filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.identifier IN %@", previouslyMonitoredRegionIdentifiers]];
    for (CLRegion *region in regionsNotToMonitor) {
        if ([self.locationManager.monitoredRegions containsObject:region]) {
            [self.locationManager stopMonitoringForRegion:region];
        }
    }
    
    // save monitored regions
    [[SAMCache bcl_monitoredProximityCache] setObject:monitoredRegionIdentifiers forKey:monitoredRegionIdentifiersKey];
    
    self.observedBeacons = beaconsToObserve;
    
    if (didObservedBeaconsChange) {
        NSLog(@"Observed beacons have changed!!!");
        
#ifdef DEBUG
        [beaconsToObserve enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
            NSLog([NSString stringWithFormat:@"%@ %@ %@", beacon.name, beacon.location.floor, beacon.zone.name]);
        }];
#endif
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(didChangeObservedBeacons:)]) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                [self.delegate didChangeObservedBeacons:beaconsToObserve];
            });
        }
    }
    
    return YES;
}

- (BCLZone *)currentZone
{
    NSLog(@"Checking the current zone!");
    
    if (self.isInBackground) {
        NSLog(@"Checking the current zone in background!!");
        BCLZone *candidate = [self zonesSortedByRatioOfVisibleBeacons].firstObject;
        NSLog(@"Current zone candidate: %@", candidate.name);
        BOOL hasRange = NO;
        for (BCLBeacon *beacon in candidate.beacons) {
            if (beacon.proximity != CLProximityUnknown) {
                hasRange = YES;
                break;
            }
        }
        NSLog(@"Any beacon in candidate has proximity: %i", hasRange);
        return hasRange ? candidate : nil;
    } else {
        __block BCLZone *currentZone;
        
        NSArray *beacons = [self beaconsSortedByDistance];
        
        [beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, NSUInteger idx, BOOL *stop) {
            if (beacon.proximity == CLProximityUnknown) {
                // The closes beacon is out of range, so we're not in any zone
                *stop = YES;
            } else if (beacon.zone) {
                currentZone = beacon.zone;
                *stop = YES;
            }
        }];
        
        return currentZone;
    }
}

- (void)recheckCurrentZone
{
    if (self.cachedClosestZone) {
        self.cachedClosestZone = nil;
    }
    
    [self processCurrentZoneChange];
}

- (BCLBeacon *)closestBeacon
{
    BCLBeacon *candidate = [[self beaconsSortedByDistance] firstObject];
    if (candidate.estimatedDistance == NSNotFound) {
        return nil;
    }
    return candidate;
}

- (BCLBeacon *)lastEnteredBeacon
{
    BCLActionEvent *lastEvent = [self.actionEventScheduler lastStoredEventWithType:BCLEventTypeEnter];
    if (!lastEvent) {
        return nil;
    }
    
    return [[self.configuration.beacons filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"beaconIdentifier == %@", [lastEvent beaconIdentifier]]] anyObject];
}

- (NSArray<BCLBeacon *> *)beaconsSortedByDistance
{
    NSArray *result = [self.observedBeacons.allObjects sortedArrayUsingComparator:^NSComparisonResult(BCLBeacon *beacon1, BCLBeacon *beacon2) {
        if (beacon1.estimatedDistance > beacon2.estimatedDistance) {
            return NSOrderedDescending;
        } else if (beacon1.estimatedDistance < beacon2.estimatedDistance) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    [result enumerateObjectsUsingBlock:^(BCLBeacon *beacon, NSUInteger idx, BOOL *stop) {
        NSLog(@"Proximity: %lu, accuracy: %f, estimatedDistance: %f", beacon.proximity, beacon.accuracy, beacon.estimatedDistance);
    }];
    
    return result;
}

- (BOOL)handleNotification:(NSDictionary *)userInfo error:(NSError *__autoreleasing *)error
{
    NSNumber *actionIdentifier = userInfo[@"action_id"];
    
    if (!actionIdentifier) {
        if (error) {
            *error = [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidDataErrorCode userInfo:@{@"message": @"This is not a push notification sent by Beacon OS"}];
        }
        return NO;
    }
    
    BCLAction *actionToPerform;
    BCLTrigger *triggerToFire;
    
    [self getTrigger:&triggerToFire andAction:&actionToPerform withActionIdentifier:actionIdentifier];
    
    if (!actionToPerform || !triggerToFire) {
        if (error) {
            *error = [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidDataErrorCode userInfo:@{@"message": @"Invalid action identifier sent in push notification"}];
        }
        return NO;
    }
    
    [self performAction:actionToPerform withTrigger:triggerToFire withEventType:BCLEventTypeDwellTime];
    
    return YES;
}

- (void)fetchConfiguration:(void(^)(NSError *error))completion;
{
    __weak typeof(self) weakSelf = self;
    
    BCLConfiguration *oldConfiguration = self.configuration;
    
    [self.backend fetchConfiguration:^(BCLConfiguration *configuration, NSError *error) {
        if (configuration) {
            if (weakSelf.configuration) {
                [oldConfiguration.beacons enumerateObjectsUsingBlock:^(BCLBeacon  *oldBeacon, BOOL * _Nonnull oldStop) {
                    [configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon  *newBeacon, BOOL * _Nonnull newStop) {
                        if ([oldBeacon.beaconIdentifier isEqualToString:newBeacon.beaconIdentifier]) {                            
                            newBeacon.needsFirmwareUpdate = oldBeacon.needsFirmwareUpdate;
                            newBeacon.firmwareUpdateProgress = oldBeacon.firmwareUpdateProgress;
                            newBeacon.needsCharacteristicsUpdate = oldBeacon.needsCharacteristicsUpdate;
                            newBeacon.vendorFirmwareVersion = oldBeacon.vendorFirmwareVersion;
                            newBeacon.batteryLevel = oldBeacon.batteryLevel;
                            newBeacon.transmissionPower = oldBeacon.transmissionPower;
                            newBeacon.transmissionInterval = oldBeacon.transmissionInterval;
                            *newStop = YES;
                        }
                    }];
                }];
            }
            
            weakSelf.configuration = configuration;
            weakSelf.observedBeaconsPicker = [[BCLObservedBeaconsPicker alloc] initWithBeacons:weakSelf.configuration.beacons andZones:weakSelf.configuration.zones];
            
            if (configuration.kontaktIOAPIKey) {
                self.kontaktIOManager = [[BCLKontaktIOBeaconConfigManager alloc] initWithApiKey:configuration.kontaktIOAPIKey];
                self.kontaktIOManager.delegate = self;
                [self.kontaktIOManager startManagement];
                
                [self.kontaktIOManager fetchConfiguration:^(NSError *kontaktIOError) {
                    if (completion) {
                        completion(kontaktIOError);
                    }
                }];
            } else if (completion) {
                completion(error);
            }

            return;
        }
        
        if (completion) {
            completion(error);
        }
    }];
}

- (void)fetchUsersInRangesOfBeacons:(NSSet *)beacons zones:(NSSet *)zones completion:(void (^)(NSDictionary *, NSError *))completion
{
    [self.backend fetchUsersInRangesOfBeacons:beacons zones:zones completion:completion];
}

#pragma mark - BCLKontaktIOBeaconConfigManagerDelegate

- (void)kontaktIOBeaconManagerDidFetchKontaktIOBeacons:(BCLKontaktIOBeaconConfigManager *)manager
{
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.vendorIdentifier) {
            if ([manager.configsToUpdate.allKeys containsObject:beacon.vendorIdentifier]) {
                beacon.needsCharacteristicsUpdate = YES;
                beacon.fieldsToUpdate = [manager fieldsToUpdateForKontaktBeacon:manager.configsToUpdate[beacon.vendorIdentifier]];
            }
            
            if ([manager.firmwaresToUpdate.allKeys containsObject:beacon.vendorIdentifier]) {
                beacon.needsFirmwareUpdate = YES;
            }
            
            if ([manager.kontaktBeaconsDictionary.allKeys containsObject:beacon.vendorIdentifier]) {
                KTKBeacon *kontaktBeacon = manager.kontaktBeaconsDictionary[beacon.vendorIdentifier];
                beacon.transmissionPower = kontaktBeacon.power.integerValue;
                beacon.transmissionInterval = kontaktBeacon.interval.integerValue;
            }
        }
    }];
}

- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didMonitorBeaconDevices:(NSArray *)devices
{
    NSMutableDictionary *devicesDictionary = @{}.mutableCopy;
    [devices enumerateObjectsUsingBlock:^(KTKBeaconDevice *device, NSUInteger idx, BOOL *stop) {
        devicesDictionary[device.uniqueID] = device;
    }];

    __block KTKBeaconDevice *device;
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.vendorIdentifier && [devicesDictionary.allKeys containsObject:beacon.vendorIdentifier]) {
            device = devicesDictionary[beacon.vendorIdentifier];
            beacon.batteryLevel = device.batteryLevel;
            beacon.vendorFirmwareVersion = device.firmwareVersion.stringValue;
        }
    }];
}

- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didStartUpdatingBeaconWithUniqueId:(NSString *)uniqueId
{
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.vendorIdentifier && [beacon.vendorIdentifier.lowercaseString isEqualToString:uniqueId.lowercaseString]) {
            beacon.characteristicsAreBeingUpdated = YES;
            if ([self.delegate respondsToSelector:@selector(beaconsPropertiesUpdateDidStart:)]) {
                [self.delegate beaconsPropertiesUpdateDidStart:beacon];
            }
            *stop = YES;
        }
    }];
}

- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didFinishUpdatingBeaconWithUniqueId:(NSString *)uniqueId newConfig:(KTKBeacon *)config success:(BOOL)success
{
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.vendorIdentifier && [beacon.vendorIdentifier.lowercaseString isEqualToString:uniqueId.lowercaseString]) {
            beacon.characteristicsAreBeingUpdated = NO;
            if (success) {
                beacon.needsCharacteristicsUpdate = NO;
                if (config.power) {
                    beacon.transmissionPower = config.power.integerValue;
                }
                
                if (config.proximity) {
                    beacon.proximityUUID = [[NSUUID alloc] initWithUUIDString:config.proximity];
                }
                
                if (config.major) {
                    beacon.major = config.major;
                }
                
                if (config.minor) {
                    beacon.minor = config.minor;
                }
                
                if (config.interval) {
                    beacon.transmissionInterval = config.interval.integerValue;
                }
                
                beacon.fieldsToUpdate = [manager fieldsToUpdateForKontaktBeacon:manager.kontaktBeaconsDictionary[config.uniqueID]];

            }

            if ([self.delegate respondsToSelector:@selector(beaconsPropertiesUpdateDidFinish:success:)]) {
                [self.delegate beaconsPropertiesUpdateDidFinish:beacon success:success];
            }
            
            *stop = YES;
        }
    }];
}

- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didStartUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId
{
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.vendorIdentifier && [beacon.vendorIdentifier.lowercaseString isEqualToString:uniqueId.lowercaseString]) {
            beacon.firmwareUpdateProgress = 0;
            if ([self.delegate respondsToSelector:@selector(beaconsFirmwareUpdateDidStart:)]) {
                [self.delegate beaconsFirmwareUpdateDidStart:beacon];
            }
            *stop = YES;
        }
    }];
}

- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager isUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId progress:(NSUInteger)progress
{
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.vendorIdentifier && [beacon.vendorIdentifier.lowercaseString isEqualToString:uniqueId.lowercaseString]) {
            beacon.firmwareUpdateProgress = progress;
            if ([self.delegate respondsToSelector:@selector(beaconsFirmwareUpdateDidProgress:progress:)]) {
                [self.delegate beaconsFirmwareUpdateDidProgress:beacon progress:progress];
            }
            NSLog(@"Updating firmware for beacon with uniqueId %@; progress: %lu", beacon.vendorIdentifier, progress);
            *stop = YES;
        }
    }];
}

- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didFinishUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId newFirwmareVersion:(NSString *)firmwareVersion success:(BOOL)success
{
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.vendorIdentifier && [beacon.vendorIdentifier.lowercaseString isEqualToString:uniqueId.lowercaseString]) {
            beacon.firmwareUpdateProgress = NSNotFound;
            if (success) {
                beacon.needsFirmwareUpdate = NO;
                beacon.vendorFirmwareVersion = firmwareVersion;
            }

            if ([self.delegate respondsToSelector:@selector(beaconsFirmwareUpdateDidFinish:success:)]) {
                [self.delegate beaconsFirmwareUpdateDidFinish:beacon success:success];
            }
            *stop = YES;
        }
    }];
}

#pragma mark - Private

/*!
 * @brief Returns an instance of BCLBeaconCtrl restored from json kept in a file at a given path
 */
- (instancetype) initWithConfigurationFile:(NSString *)path
{
    if (self = [self init]) {
        self.configuration = [[BCLConfiguration alloc] initWithJSON:[NSData dataWithContentsOfFile:path]];
    }
    return self;
}

/*!
 * @brief The main init method
 */
- (instancetype)initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret pushEnvironment:(BCLBeaconCtrlPushEnvironment)pushEnvironment pushToken:(NSString *)pushToken
{
    if (self = [self init]) {
        _backend = [[BCLBackend alloc] initWithClientId:clientId clientSecret:clientSecret pushEnvironment:[self pushEnvironmentNameWithPushEnvironment:pushEnvironment] pushToken:pushToken];
        _actionEventScheduler = [[BCLActionEventScheduler alloc] initWithBackend:_backend];
        [_actionEventScheduler sendActionEvents:nil];
    }
    return self;
}

/*!
 * @brief Returns an instance of BCLBeaconCtrl restored from json kept in a file at a given path
 */
+ (BCLBeaconCtrl *) beaconCtrlWithConfigurationFile:(NSString *)path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    
    BCLBeaconCtrl *bcl = [[BCLBeaconCtrl alloc] initWithConfigurationFile:path];
    return bcl;
}

/*!
 * @brief The method that is called at the end of each initilization flow
 */
- (void)finishInitialization
{
    self.eventScheduler = [[BCLEventScheduler alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBeaconTimerEvent:) name:BCLBeaconTimerFireNotification object:nil];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    self.bluetoothCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    
    self.actionHandlerFactory = [[BCLActionHandlerFactory alloc] init];
    
    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
        [self.locationManager performSelector:@selector(requestAlwaysAuthorization) withObject:nil];
    }
}

/*!
 * @return A string representation of a constant of type BCLBeaconCtrlPushEnvironment
 */
- (NSString *)pushEnvironmentNameWithPushEnvironment:(BCLBeaconCtrlPushEnvironment)pushEnvironment
{
    switch(pushEnvironment) {
        case BCLBeaconCtrlPushEnvironmentProduction:
            return @"production";
        case BCLBeaconCtrlPushEnvironmentSandbox:
            return @"sandbox";
        default:
            return nil;
    }
}

/*!
 * @brief A shortcut method that returns a set of extensions from the current configuration
 */
- (NSSet *) extensions
{
    return self.configuration.extensions;
}

/*
 * @brief A shortcut method that returns an extension with a given name from the current configuration
 */
- (id <BCLExtension>) extensionForName:(NSString *)extensionName
{
    NSSet *subset = [[self extensions] objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        id <BCLExtension> extension = obj;
        NSString *name = [[extension class] bcl_extensionName];
        if ([name isEqualToString:extensionName]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    return [subset anyObject];
}

/*!
 * @brief A method that returns an array of zones sorted by the amount of beacons from each zone that are in range (with some modifiers that are supposed to compensate size differences between zones.
 */
- (NSArray *)zonesSortedByRatioOfVisibleBeacons
{
    BOOL didChange = NO;
    
    NSSet *observedZones = [self.observedBeaconsPicker observedZones:&didChange];
    
    NSLog(@"Observed beacons picker: %@", self.observedBeaconsPicker);
    NSLog(@"Observed zones: %@", observedZones);
    
    __block CGFloat ratio1;
    __block NSDate *zone1LastEnterDate;
    __block CGFloat ratio2;
    __block NSDate *zone2LastEnterDate;
    
    NSArray *result = [observedZones.allObjects sortedArrayUsingComparator:^NSComparisonResult(BCLZone *zone1, BCLZone *zone2) {
        NSLog(@"Comparing zone %@ and zone %@", zone1.name, zone2.name);
        
        ratio1 = 0.0;
        zone1LastEnterDate = nil;
        ratio2 = 0.0;
        zone2LastEnterDate = nil;
        
        for (BCLBeacon *beacon in zone1.beacons) {
            if (beacon.proximity == CLProximityUnknown || ![self.observedBeacons containsObject:beacon]) {
                continue;
            }
            
            ratio1 += 1.0;
            zone1LastEnterDate = [zone1LastEnterDate laterDate:beacon.lastEnteredDate];
        }
        
        for (BCLBeacon *beacon in zone2.beacons) {
            if (beacon.proximity == CLProximityUnknown || ![self.observedBeacons containsObject:beacon]) {
                continue;
            }
            
            ratio2 += 1.0;
            zone2LastEnterDate = [zone2LastEnterDate laterDate:beacon.lastEnteredDate];
        }
        
        ratio1 /= zone1.beacons.count;
        ratio2 /= zone2.beacons.count;
        
        if (ratio1 == ratio2) {
            // If the ratio is the same, we want to favor the zone with a beacon with the earlier
            // enter date
            switch ([zone1LastEnterDate compare:zone2LastEnterDate]) {
                case NSOrderedAscending:
                    ratio1 += 1.0;
                    break;
                case NSOrderedDescending:
                    ratio2 += 1.0;
                    break;
                default:
                    break;
            }
        }
        
        NSLog(@"Zone %@ ratio is %f", zone1.name, ratio1);
        NSLog(@"Zone %@ ratio is %f", zone2.name, ratio2);
        
        return [@(ratio2) compare:@(ratio1)];
    }];
    
    return result;
}

/*!
 * @return YES, if there's any beacon in range, NO otherwise
 */
- (BOOL)isInAnyRange
{
    __block BOOL result = NO;
    
    [self.observedBeacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        if (beacon.proximity != CLProximityUnknown) {
            result = YES;
            *stop = YES;
        }
    }];
    
    return result;
}

/*!
 * @return YES, if the closest beacon has changed since the previous check, NO otherwise
 */
- (BOOL)checkIfClosestBeaconHasChanged
{
    BCLBeacon *closestBeacon = [self closestBeacon];
    
    if (![closestBeacon isEqual:self.cachedClosestBeacon]) {
        self.cachedClosestBeacon = closestBeacon;
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(closestObservedBeaconDidChange:)]) {
            [self.delegate closestObservedBeaconDidChange:self.cachedClosestBeacon];
        }
        
        return YES;
    } else {
        return NO;
    }
}

/*!
 * @brief A method that checks if the currently occupied zone has changed since the previous check and triggers all the necessary actions, if so.
 */
- (void)processCurrentZoneChange
{
    NSLog(@"Checking if the zone has changed!");
    
    BCLZone *currentZone = [self currentZone];
    
    NSLog(@"Current zone: %@", currentZone.name);
    NSLog(@"Cached zone: %@", self.cachedClosestZone.name);
    
    NSDictionary *currentZoneChange = @{
                                        BCLPreviousZoneKey : self.cachedClosestZone ?: [NSNull null],
                                        BCLCurrentZoneKey : currentZone ?: [NSNull null],
    };
    
    if (![currentZone isEqual:self.cachedClosestZone] && !(currentZone == nil && self.cachedClosestZone == nil) && ![self.previousZoneChange isEqual:currentZoneChange]) {
        if ([self.eventScheduler isChangeZoneEventScheduled]) {
            [self.eventScheduler cancelChangeZoneEvent];
        }
        
        NSLog(@"The zone has changed. Scheduling a zone change event!!");
        self.previousZoneChange = currentZoneChange;
        
        __weak typeof(self) weakSelf = self;
        [self.eventScheduler scheduleChangeZoneEventWithPreviousZone:self.cachedClosestZone newZone:currentZone afterDelay:BCLDelayEventTimeInterval onTime:^(BCLZone *previousZone, BCLZone *newZone) {
            weakSelf.cachedClosestZone = currentZone;
            weakSelf.previousZoneChange = nil;
            
            NSLog(@"Firing a zone change event!!");
            
            if (previousZone) {
                // We want to send enter and leave events for each zone
                NSLog(@"Scheduling zone leave event for zone: %@", previousZone.name);
                [weakSelf storeActionEventWithType:BCLEventTypeLeave beacon:nil zone:previousZone action:nil];
                [weakSelf performActionsForZone:previousZone eventType:BCLEventTypeLeave];
            }
            
            if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(currentZoneDidChange:)]) {
                [weakSelf.delegate currentZoneDidChange:newZone];
            }
            
            if (newZone) {
                if (!self.isInBackground) {
                    weakSelf.estimatedUserLocation = [weakSelf centerOfZone:newZone];
                }
                [weakSelf.locationManager stopUpdatingLocation];
                // We want to send enter and leave events for each zone
                NSLog(@"Scheduling zone enter event for zone: %@", newZone.name);
                [weakSelf storeActionEventWithType:BCLEventTypeEnter beacon:nil zone:newZone action:nil];
                [weakSelf performActionsForZone:newZone eventType:BCLEventTypeEnter];
            } else {
                if (!self.isInBackground) {
                    weakSelf.estimatedUserLocation = nil;
                }
                
                [weakSelf.locationManager startUpdatingLocation];
            }
            
            if (!self.isInBackground) {
                [weakSelf updateMonitoredBeacons];
            }
        }];
    }
}

/*!
 * @return The center location of a given zone, calculated as an average of the most extended points
 */
- (BCLLocation *)centerOfZone:(BCLZone *)zone
{
    CGFloat minLat = 180.0;
    CGFloat maxLat = 0.0;
    CGFloat minLong = 180.0;
    CGFloat maxLong = 0.0;
    NSUInteger floor = 0;
    
    for (BCLBeacon *beacon in zone.beacons) {
        if (beacon.location.location.coordinate.latitude > maxLat) {
            maxLat = beacon.location.location.coordinate.latitude;
        }
        if (beacon.location.location.coordinate.latitude < minLat) {
            minLat = beacon.location.location.coordinate.latitude;
        }
        if (beacon.location.location.coordinate.longitude > maxLong) {
            maxLong = beacon.location.location.coordinate.longitude;
        }
        if (beacon.location.location.coordinate.longitude < minLong) {
            minLong = beacon.location.location.coordinate.longitude;
        }
        floor = beacon.location.floor.integerValue;
    }
    
    return [[BCLLocation alloc] initWithLocation:[[CLLocation alloc] initWithLatitude:(minLat + maxLat) / 2.0 longitude:(minLong + maxLong) / 2.0] floor:@(floor)];
}

/*!
 * @brief Stores an action event so that it can be send to the backend at the proper time.
 */
- (void)storeActionEventWithType:(BCLEventType)type beacon:(BCLBeacon *)beacon zone:(BCLZone *)zone action:(BCLAction *)action
{
    BCLActionEvent *event = [[BCLActionEvent alloc] init];
    event.eventType = type;
    
    if (beacon) {
        event.beaconIdentifier = beacon.beaconIdentifier;
    }
    
    if (zone) {
        event.zoneIdentifier = zone.zoneIdentifier;
    }
    
    if (action) {
        event.actionIdentifier = action.identifier.stringValue;
        event.actionName = action.name;
    }
    
    [self.actionEventScheduler storeEvent:event];
}

/*!
 * @brief A shortcut method that finds a proper trigger and action given an action identifier
 */
- (void)getTrigger:(BCLTrigger **)trigger andAction:(BCLAction **)action withActionIdentifier:(NSNumber *)actionIdentifier
{
    __block BCLAction *actionToPerform;
    __block BCLTrigger *triggerToFire;
    
    [self.configuration.beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *beaconStop) {
        [beacon.triggers enumerateObjectsUsingBlock:^(BCLTrigger *trigger, NSUInteger triggerIdx, BOOL *triggerStop) {
            [trigger.actions enumerateObjectsUsingBlock:^(BCLAction *action, NSUInteger actionIdx, BOOL *actionStop) {
                if ([action.identifier isEqual:actionIdentifier]) {
                    actionToPerform = action;
                    triggerToFire = trigger;
                    *beaconStop = *triggerStop = *actionStop = YES;
                }
            }];
        }];
    }];
    
    if (actionToPerform && triggerToFire && trigger && action) {
        *trigger = triggerToFire;
        *action = actionToPerform;
    } else {
        [self.configuration.zones enumerateObjectsUsingBlock:^(BCLZone *zone, BOOL *zoneStop) {
            [zone.triggers enumerateObjectsUsingBlock:^(BCLTrigger *trigger, NSUInteger triggerIdx, BOOL *triggerStop) {
                [trigger.actions enumerateObjectsUsingBlock:^(BCLAction *action, NSUInteger actionIdx, BOOL *actionStop) {
                    if ([action.identifier isEqual:actionIdentifier]) {
                        actionToPerform = action;
                        triggerToFire = trigger;
                        *zoneStop = *triggerStop = *actionStop = YES;
                    }
                }];
            }];
        }];
        
        if (actionToPerform && triggerToFire && trigger && action) {
            *trigger = triggerToFire;
            *action = actionToPerform;
        }
    }
}

/*!
 * @brief Triggers all the relevant actions for a given beacon after an event of given type has occured
 */
- (void)performActionsForBeacon:(BCLBeacon *)beacon eventType:(BCLEventType)eventType
{
    for (BCLTrigger *trigger in beacon.triggers) {
        [self performActionForTrigger:trigger eventType:eventType];
    }
}

/*!
 * @brief Triggers all the relevant actions for a given zone after an event of given type has occured
 */
- (void)performActionsForZone:(BCLZone *)zone eventType:(BCLEventType)eventType
{
    for (BCLTrigger *trigger in zone.triggers) {
        [self performActionForTrigger:trigger eventType:eventType];
    }
}

/*!
 * @brief Performs all relevant actions in a trigger after an event of given type has occured
 */
- (BOOL)performActionForTrigger:(BCLTrigger *)trigger eventType:(BCLEventType)eventType
{
    BOOL triggerOK = YES;
    for (id <BCLCondition> condition in trigger.conditions) {
        triggerOK = triggerOK && trigger.beacon ? [condition evaluateCondition:eventType forBeacon:trigger.beacon] : [condition evaluateCondition:eventType forZone:trigger.zone];
    }
    
    if (triggerOK) {
        for (BCLAction *action in trigger.actions) {
            [self performAction:action withTrigger:trigger withEventType:eventType];
        }
    }
    
    return triggerOK;
}

/*!
 * @brief Performs a given action
 */
- (void)performAction:(BCLAction *)action withTrigger:(BCLTrigger *)trigger withEventType:(BCLEventType)eventType
{
    id <BCLActionHandler> actionHandler = [self.actionHandlerFactory actionHandlerForActionTypeName:action.type];
    
    if (self.isInBackground) {
        BOOL shouldAutomaticallyNotifyAction = YES;
        
        if (actionHandler && self.delegate && [self.delegate respondsToSelector:@selector(shouldAutomaticallyNotifyAction:)]) {
            shouldAutomaticallyNotifyAction = [self.delegate shouldAutomaticallyNotifyAction:action];
        }
        
        if (actionHandler && shouldAutomaticallyNotifyAction) {
            if ([UNUserNotificationCenter class]) {
                UNMutableNotificationContent *content = [UNMutableNotificationContent new];
                content.body = action.name;
                content.userInfo = @{@"action_id": action.identifier};
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[action.identifier stringValue]
                                                                                      content:content.copy
                                                                                      trigger:nil];
                [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
            } else {
                //iOS < 10
                UILocalNotification *notification = [[UILocalNotification alloc] init];
                notification.alertBody = action.name;
                notification.userInfo = @{@"action_id": action.identifier};
                [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
            }
        } else if (self.delegate && [self.delegate respondsToSelector:@selector(notifyAction:)]) {
            [self.delegate notifyAction:action];
        }
        
        return;
    }
    
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(willPerformAction:)]) {
        [self.delegate willPerformAction:action];
    }
    
    BOOL shouldAutomaticallyPerformAction = YES;
    
    if (actionHandler && self.delegate && [self.delegate respondsToSelector:@selector(shouldAutomaticallyPerformAction:)]) {
        shouldAutomaticallyPerformAction = [self.delegate shouldAutomaticallyPerformAction:action];
    }
    
    if (actionHandler && shouldAutomaticallyPerformAction) {
        [actionHandler handleAction:action];
    } else if (action.onActionCallback) {
        action.onActionCallback(action);
    }
    
    [self storeActionEventWithType:eventType beacon:trigger.beacon zone:trigger.zone action:action];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(didPerformAction:)]) {
        [self.delegate didPerformAction:action];
    }
}

/*!
 * @brief Called after a proximity to a given beacon has changed. Fires all the relevant actions.
 */
- (void) beaconProximityDidChange:(BCLBeacon *)beacon
{
    if (!beacon)
        return;
    
    if (beacon.onChangeProximityCallback) {
        beacon.onChangeProximityCallback(beacon);
    }
    
    BCLEventType eventType;
    
    switch (beacon.proximity) {
        case CLProximityFar:
            eventType = BCLEventTypeRangeFar;
            break;
        case CLProximityNear:
            eventType = BCLEventTypeRangeNear;
            break;
        case CLProximityImmediate:
            eventType = BCLEventTypeRangeImmediate;
            break;
        default:
            eventType = BCLEventTypeUnknown;
            break;
    }
    
    for (id <BCLExtension> extension in [self extensions]) {
        [extension event:eventType forBeacon:beacon];
    }
    
    // Triggers with actions
    [self performActionsForBeacon:beacon eventType:eventType];
}

- (void) handleBeaconTimerEvent:(NSNotification *)notification
{
    NSParameterAssert(notification);
    NSParameterAssert(notification.object);
    
    if (!notification.object)
        return;
    
    BCLBeacon *beacon = notification.object;
    
    for (id <BCLExtension> extension in [self extensions]) {
        [extension event:BCLEventTypeTimer forBeacon:beacon];
    }
    
    [self performActionsForBeacon:beacon eventType:BCLEventTypeTimer];
}

/*!
 * @brief Processes enters and leaves from beacons' ranges and fires all the relevant actions
 */
- (void) processRegionState:(CLRegionState)state forRegion:(CLBeaconRegion *)region
{
    if (self.paused) {
#ifdef DEBUG
        NSLog(@"PAUSED");
#endif
        return;
    }
    
    NSParameterAssert(region);
    // search for beacon and call actions
    BCLBeacon *foundBeacon = [[self.observedBeacons filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@",region.identifier]] anyObject];
    
    if (!foundBeacon) {
        return;
    }
    
    // search for trigger
    BCLEventType eventType = BCLEventTypeUnknown;
    switch (state) {
        case CLRegionStateInside:
            eventType = BCLEventTypeEnter;
            break;
        case CLRegionStateOutside:
            eventType = BCLEventTypeLeave;
            break;
        default:
            //@throw [NSException exceptionWithName:@"BLEKitUnknownEvent" reason:@"Unknown event" userInfo:nil];
            break;
    }
    
    if (eventType == BCLEventTypeUnknown) {
        return;
    }
    
    SAMCache *staysCache = [[SAMCache alloc] initWithName:BLEBeaconStaysCacheName(foundBeacon)];
    
    // Schedule
    if (eventType == BCLEventTypeEnter) {
        
        // if leave is scheduled then unschedule leave and do nothing
        if ([self.eventScheduler isScheduledForBeacon:foundBeacon]) {
            [self.eventScheduler cancelForBeacon:foundBeacon];
        } else {
            foundBeacon.proximity = CLProximityFar;
            
            // Stop checking GPS user location for determining beacons to look for
            [self.locationManager stopUpdatingLocation];
            
            [staysCache setObject:[NSDate date] forKey:foundBeacon.identifier];
            
            // perform actual action
            if (foundBeacon.onEnterCallback) {
                foundBeacon.onEnterCallback(foundBeacon);
            }
            
            // Extensions
            for (id <BCLExtension> extension in [self extensions]) {
                [extension event:eventType forBeacon:foundBeacon];
            }
            
            // Triggers with actions
            [self performActionsForBeacon:foundBeacon eventType:eventType];
            
            if (![self.locationManager.rangedRegions containsObject:region]) {
                [self.locationManager startRangingBeaconsInRegion:region];
            }
            
            if (self.isInBackground) {
                self.estimatedUserLocation = foundBeacon.location;
                [self updateMonitoredBeacons];
            }
            
            [self processCurrentZoneChange];
            
            // We want to send enter and leave events for each ranged beacon
            [self storeActionEventWithType:eventType beacon:foundBeacon zone:nil action:nil];
        }
    } else if (eventType == BCLEventTypeLeave) {
        // schedule new leave cancelling old one (re-schedule)
        [self.eventScheduler scheduleEventForBeacon:foundBeacon afterDelay:BCLDelayEventTimeInterval onTime:^(BCLBeacon *scheduledBeacon) {
            // if beacon leave then assume that proximity is unknown (it's FAR FAr Far far away)
            foundBeacon.proximity = CLProximityUnknown;
            NSLog(@"Setting proximity unknown for beacon: %@", foundBeacon);
            foundBeacon.accuracy = 0;
            
            foundBeacon.rssi = 0;
            
            // clear stays cache
            [staysCache removeObjectForKey:foundBeacon.identifier];
            
            if (scheduledBeacon.onExitCallback) {
                scheduledBeacon.onExitCallback(foundBeacon);
            }
            
            // Extensions
            for (id <BCLExtension> extension in [self extensions]) {
                [extension event:eventType forBeacon:foundBeacon];
            }
            
            // Triggers with actions
            [self performActionsForBeacon:foundBeacon eventType:eventType];
            
            [self processCurrentZoneChange];
            
            // We want to send enter and leave events for each ranged beacon
            [self storeActionEventWithType:eventType beacon:foundBeacon zone:nil action:nil];
            
            // Start using GPS to determine which beacons to monitor
            if (![self isInAnyRange]) {
                self.estimatedUserLocation = nil;
                [self.locationManager startUpdatingLocation];
            }
        }];
    }
}

/*!
 * @return YES, if the running application is in background, NO otherwise
 */
- (BOOL) isInBackground
{
    return ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground || [[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive);
}

/*!
 * @return A path to the BeaconCtrl's cache directory
 */
+ (NSString *)cacheDirectoryPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = paths[0];
    return [cacheDirectory stringByAppendingPathComponent:BCLBeaconCtrlCacheDirectoryName];
}


#pragma mark - BCLEncodableObject

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (!self) {
        return nil;
    }
    
    [self finishInitialization];
    
    self.actionEventScheduler = [[BCLActionEventScheduler alloc] initWithBackend:self.backend];
    
    return self;
}

- (NSArray *)propertiesToExcludeFromEncoding
{
    return @[@"eventScheduler",
             @"actionEventScheduler",
             @"actionHandlerFactory",
             @"delegate",
             @"locationManager",
             @"estimatedUserLocation",
             @"beaconBatch"];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
}

#pragma mark - CLLocationManagerDelegate

/**
 *  Not used. For debugging purposed only
 */

/**
 *  Call enter events for beacons that have been ranged at app launch
 */
- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    if ([self.initiallyMonitoredRegions containsObject:region]) {
        if (state == CLRegionStateInside) {
            [self locationManager:manager didEnterRegion:region];
        }
        NSMutableSet *mutableRegions = self.initiallyMonitoredRegions.mutableCopy;
        [mutableRegions removeObject:region];
        self.initiallyMonitoredRegions = mutableRegions.copy;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"location manager did fail with error: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    NSLog(@"location manager did fail to monitor region %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        if (!self.estimatedUserLocation) {
            [self.locationManager startUpdatingLocation];
        }
    }
}

/**
 *  Gather ranged data and every period of time, process gathered data and clear batch
 */
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)rangedBeacons inRegion:(CLBeaconRegion *)region
{
    [self.locationManager stopUpdatingLocation];
    
    if (self.isInBackground)
        return;
    
    
//    if (rangedBeacons.count == 0){
//        [manager stopRangingBeaconsInRegion:region];
//        return;
//    }
    
    if (!self.beaconBatch) {
        self.beaconBatch = [[BCLBeaconRangingBatch alloc] initWithDelegate:self];
    }
    
    [self.beaconBatch add:rangedBeacons forRegion:region];
}

/**
 *  Enter to region
 */
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLBeaconRegion *)region
{
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    [self processRegionState:CLRegionStateInside forRegion:region];
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
#ifdef DEBUG
        NSLog(@"locationManager:didEnterRegion endBackgroundTask");
#endif
    }
}

/**
 *  Leave region
 */
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLBeaconRegion *)region
{
    [self processRegionState:CLRegionStateOutside forRegion:region];
}

- (void) startRangingBeaconsInRegion:(CLBeaconRegion *)region
{
    [self.locationManager startRangingBeaconsInRegion:region];
//    [self processRegionState:CLRegionStateInside forRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    NSLog(@"rangingBeaconsDidFailForRegion, reason: %@", error);
    if ([region.major isEqual:@1] && [region.minor isEqual:@10]) {
        NSLog(@"");
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    //[self.locationManager allowDeferredLocationUpdatesUntilTraveled:10 timeout:5];
    
    NSLog(@"Updated GPS Location!");
    
    CLLocation *lastKnownLocation = locations.lastObject;
    NSNumber *floor;
    if ([lastKnownLocation respondsToSelector:@selector(floor)]) {
        if ([lastKnownLocation performSelector:@selector(floor)]) {
            floor = @(lastKnownLocation.floor.level);
        }
    }
    self.estimatedUserLocation = [[BCLLocation alloc] initWithLocation:lastKnownLocation floor:floor];
    [self updateMonitoredBeacons];
}

#pragma mark - BLEBeaconsRangeBatchDelegate

- (void)processBeaconBatch:(BCLBeaconRangingBatch *)batch beacons:(NSArray *)rangedBeacons
{
    if (self.paused) {
#ifdef DEBUG
        NSLog(@"PAUSED");
#endif
        return;
    }
    
    NSArray *knownRangedBeacons = [rangedBeacons filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"accuracy > 0"]];
    NSArray *rangedBeaconsSorted = [knownRangedBeacons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"accuracy" ascending:YES],[NSSortDescriptor sortDescriptorWithKey:@"rssi" ascending:YES]]];
    
    if (rangedBeaconsSorted.count > 0) {
        [self.observedBeacons enumerateObjectsUsingBlock:^(BCLBeacon *bleBeacon, BOOL *stop) {
            CLBeacon *rangedBeacon = rangedBeaconsSorted[0];
            if ([rangedBeacon.bcl_identifier hasPrefix:bleBeacon.identifier]) {
                if (rangedBeacon.proximity != CLProximityUnknown && rangedBeacon.accuracy > 0) {
                    bleBeacon.accuracy = rangedBeacon.accuracy;
                    bleBeacon.rssi = rangedBeacon.rssi;
                    // Guess the proximty based on accuracy value
                    CLProximity guessedProximity = CLProximityUnknown;
                    if (rangedBeacon.accuracy < 0.5) {
                        guessedProximity = CLProximityImmediate;
                    } else if (rangedBeacon.accuracy <= 3.0) {
                        guessedProximity = CLProximityNear;
                    } else {
                        guessedProximity = CLProximityFar;
                    }
                    
                    if ([bleBeacon canSetProximity:guessedProximity]) {
                        bleBeacon.proximity = guessedProximity;
                        [self beaconProximityDidChange:bleBeacon];
                    }
                } else {
                    bleBeacon.proximity = CLProximityUnknown;
                    bleBeacon.accuracy = 0;
                    bleBeacon.rssi = 0;
                }
                *stop = YES;
            }
        }];
    }
    
    BOOL closestBeaconHasChanged = [self checkIfClosestBeaconHasChanged];
    
    if (closestBeaconHasChanged && !self.isInBackground) {
        [self processCurrentZoneChange];
    }
}

- (void)logout
{
    [self.backend reset];
    [BCLActionEventScheduler clearCache];
}

@end
