//
//  BCLKontaktIOBeaconConfigManager.m
//  Pods
//
//  Created by Artur Wdowiarski on 18.09.2015.
//
//

#import "BCLKontaktIOBeaconConfigManager.h"
#import <KontaktSDK-OLD/KTKClient.h>
#import <KontaktSDK-OLD/KTKBluetoothManager.h>
#import <KontaktSDK-OLD/KTKBeacon.h>
#import <KontaktSDK-OLD/KTKBeaconDevice.h>
#import <KontaktSDK-OLD/KTKError.h>
#import <KontaktSDK-OLD/KTKPagingBeacons.h>
#import <KontaktSDK-OLD/KTKPagingConfigs.h>
#import <KontaktSDK-OLD/KTKFirmware.h>

@interface BCLKontaktIOBeaconConfigManager () <KTKBluetoothManagerDelegate>

@property (nonatomic, strong) KTKClient *kontaktClient;
@property (nonatomic, strong) KTKBluetoothManager *kontaktBluetoothManager;
@property (nonatomic) BOOL isUpdatingBeacons;

@end

@implementation BCLKontaktIOBeaconConfigManager

- (instancetype)initWithApiKey:(NSString *)apiKey
{
    if (self = [super init]) {
        _kontaktClient = [KTKClient new];
        _kontaktClient.apiKey = apiKey;
        
        _kontaktBluetoothManager = [KTKBluetoothManager new];
        _kontaktBluetoothManager.delegate = self;
        
        _configsToUpdate = @{}.mutableCopy;
    }
    
    return self;
}

- (void)fetchConfiguration:(void (^)(NSError *))completion
{
    NSError *error;
    
    NSArray *configsToChangeArray = [self.kontaktClient configsPaged:[[KTKPagingConfigs alloc] initWithIndexStart:0 andMaxResults:1000] forDevices:KTKDeviceTypeBeacon withError:&error];
    
    if (error) {
        if (completion) {
            completion(error);
        }
        return;
    }
    
    [configsToChangeArray enumerateObjectsUsingBlock:^(KTKBeacon *beacon, NSUInteger idx, BOOL *stop) {
        self.configsToUpdate[beacon.uniqueID] = beacon;
    }];
    
    NSArray *kontaktBeacons = [self.kontaktClient beaconsPaged:[[KTKPagingBeacons alloc] initWithIndexStart:0 andMaxResults:1000] withError:&error];
    
    if (error) {
        if (completion) {
            completion(error);
        }
        return;
    }
    
    NSMutableArray *kontaktBeaconsUniqueIds = @[].mutableCopy;
    
    NSMutableDictionary *kontaktBeaconsDictionary = @{}.mutableCopy;
    [kontaktBeacons enumerateObjectsUsingBlock:^(KTKBeacon *beacon, NSUInteger idx, BOOL *stop) {
        [kontaktBeaconsUniqueIds addObject:beacon.uniqueID];
        kontaktBeaconsDictionary[beacon.uniqueID] = beacon;
    }];
    
    self.kontaktBeaconsDictionary = kontaktBeaconsDictionary;
    
    NSError *firmareUpdatesError;
    self.firmwaresToUpdate = [self.kontaktClient firmwaresLatestForBeaconsUniqueIds:kontaktBeaconsUniqueIds.copy withError:&firmareUpdatesError].mutableCopy;
    
    if (firmareUpdatesError) {
        if (completion) {
            completion(firmareUpdatesError);
        }
        return;
    }
    
    [self.delegate kontaktIOBeaconManagerDidFetchKontaktIOBeacons:self];
    
    if (completion) {
        completion(nil);
    }
}

- (void)startManagement
{
    [self.kontaktBluetoothManager startFindingDevices];
}

- (NSDictionary *)fieldsToUpdateForKontaktBeacon:(KTKBeacon *)beacon
{
    NSMutableDictionary *fieldsToUpdate = @{}.mutableCopy;
    
    KTKBeacon *config = self.configsToUpdate[beacon.uniqueID];
    
    if (config) {
        if (config.interval) {
            fieldsToUpdate[@"interval"] = config.interval;
        }
        
        if (config.power) {
            fieldsToUpdate[@"power"] = config.power;
        }
        
        if (config.proximity) {
            fieldsToUpdate[@"proximity"] = config.proximity;
        }
        
        if (config.major) {
            fieldsToUpdate[@"major"] = config.major;
        }
        
        if (config.minor) {
            fieldsToUpdate[@"minor"] = config.minor;
        }
    }
    
    return fieldsToUpdate.copy;
}

#pragma mark - KTKBluetoothManagerDelegate

- (void)bluetoothManager:(KTKBluetoothManager *)bluetoothManager didChangeDevices:(NSSet *)devices
{
    NSLog(@"Kontakt.io bluetooth manager did change devices: %@", devices);
    if (self.isUpdatingBeacons) {
        return;
    }
    
    [self.delegate kontaktIOBeaconManager:self didMonitorBeaconDevices:[devices allObjects]];
    [self updateKontaktBeaconDevices:devices];
}

#pragma mark - Private

- (void)updateKontaktBeaconDevices:(NSSet *)devices
{
    self.isUpdatingBeacons = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^() {
        [devices enumerateObjectsUsingBlock:^(KTKBeaconDevice *beacon, BOOL *stop) {
            if ([self.configsToUpdate.allKeys containsObject:beacon.uniqueID] || [self.firmwaresToUpdate.allKeys containsObject:beacon.uniqueID]) {
                NSLog(@"Trying update kontakt.io beacon with uniqueId %@", beacon.uniqueID);
                NSString *password;
                NSString *masterPassword;
                KTKError *error;
                [self.kontaktClient beaconPassword:&password andMasterPassword:&masterPassword byUniqueId:beacon.uniqueID withError:&error];
                if (error) {
                    return;
                }
                
                if ([self.configsToUpdate.allKeys containsObject:beacon.uniqueID]) {
                    if ([beacon connectWithPassword:password andError:&error]) {
                        KTKBeacon *newConfig = self.configsToUpdate[beacon.uniqueID];
                        NSError *updateError;
                        [self updateKontaktBeaconDevice:beacon withNewConfig:newConfig error:&updateError];
                        [beacon disconnect];
                    }
                }
                
                if ([self.firmwaresToUpdate.allKeys containsObject:beacon.uniqueID]) {
                    KTKFirmware *newFirmware = self.firmwaresToUpdate[beacon.uniqueID];
                    if ([beacon connectWithPassword:password andError:&error]) {
                        NSError *firmwareUpdateError;
                        [self updateFirmwareForKontaktBeaconDevice:beacon masterPassword:masterPassword newFirmware:newFirmware error:&firmwareUpdateError];
                        [beacon disconnect];
                    }
                }
            }
        }];

        self.isUpdatingBeacons = NO;
    });
}

- (BOOL)updateFirmwareForKontaktBeaconDevice:(KTKBeaconDevice *)beaconDevice masterPassword:(NSString *)masterPassword newFirmware:(KTKFirmware *)newFirmware error:(NSError **)error
{
    NSError *firmwareUpdateError = [beaconDevice updateFirmware:newFirmware usingMasterPassword:masterPassword progressHandler:^(KTKBeaconDeviceFirmwareUpdateState state, int progress) {
        switch (state) {
            case KTKBeaconDeviceFirmwareUpdateStatePreparing:
            {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [self.delegate kontaktIOBeaconManager:self didStartUpdatingFirmwareForBeaconWithUniqueId:beaconDevice.uniqueID];
                });
                break;
            }
            case KTKBeaconDeviceFirmwareUpdateStateUploading:
            {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [self.delegate kontaktIOBeaconManager:self isUpdatingFirmwareForBeaconWithUniqueId:beaconDevice.uniqueID progress:progress];
                });
                break;
            }
        }
    }];
    
    if (firmwareUpdateError) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self.delegate kontaktIOBeaconManager:self didFinishUpdatingFirmwareForBeaconWithUniqueId:beaconDevice.uniqueID newFirwmareVersion:nil success:NO];
        });
        return NO;
    } KTKBeacon *beaconToUpdate = self.kontaktBeaconsDictionary[beaconDevice.uniqueID];
    beaconToUpdate.firmware = newFirmware.version;
    NSError *updateError;
    
    [self.kontaktClient beaconUpdate:beaconToUpdate withError:&updateError];
    
    if (updateError){
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self.delegate kontaktIOBeaconManager:self didFinishUpdatingFirmwareForBeaconWithUniqueId:beaconDevice.uniqueID newFirwmareVersion:nil success:NO];
        });
        return NO;
    }
    
    if (self.firmwaresToUpdate[beaconDevice.uniqueID]) {
        [self.firmwaresToUpdate removeObjectForKey:beaconDevice.uniqueID];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.delegate kontaktIOBeaconManager:self didFinishUpdatingFirmwareForBeaconWithUniqueId:beaconDevice.uniqueID newFirwmareVersion:newFirmware.version success:YES];
    });
    return YES;
}

- (BOOL)updateKontaktBeaconDevice:(KTKBeaconDevice *)beaconDevice withNewConfig:(KTKBeacon *)config error:(NSError **)error
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.delegate kontaktIOBeaconManager:self didStartUpdatingBeaconWithUniqueId:config.uniqueID];
    });
    
    NSError *writeError;
    KTKCharacteristicDescriptor *descriptor;
    BOOL success = YES;
    
    KTKBeacon *kontaktBeacon = self.kontaktBeaconsDictionary[config.uniqueID];
    
    if (success && config.power) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeTxPowerLevel];
        writeError = [beaconDevice writeString:config.power.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        } else {
            kontaktBeacon.power = config.power;
        }
    }
    
    if (success && config.proximity) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeProximityUUID];
        writeError = [beaconDevice writeString:config.proximity forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        } else {
            kontaktBeacon.proximity = config.proximity;
        }
    }
    
    if (success && config.major) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeMajor];
        writeError = [beaconDevice writeString:config.major.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            return NO;
        } else {
            kontaktBeacon.major = config.major;
        }
    }
    
    if (success && config.minor) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeMinor];
        writeError = [beaconDevice writeString:config.minor.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        } else {
            kontaktBeacon.minor = config.minor;
        }
    }
    
    if (success && config.interval) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeAdvertisingInterval];
        writeError = [beaconDevice writeString:config.interval.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        } else {
            kontaktBeacon.interval = config.interval;
        }
    }
    
    if (success) {
        NSError *updateError;
        success = [self.kontaktClient beaconUpdate:config withError:&updateError];
        if (!success) {
            *error = updateError;
            NSLog(@"There was an error while trying to update a kontakt.io beacon in kontakt.io panel: %@", updateError);
        } else if (self.configsToUpdate[beaconDevice.uniqueID]) {
            [self.configsToUpdate removeObjectForKey:beaconDevice.uniqueID];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.delegate kontaktIOBeaconManager:self didFinishUpdatingBeaconWithUniqueId:config.uniqueID newConfig:config success:success];
    });
    
    return success;
}

@end
