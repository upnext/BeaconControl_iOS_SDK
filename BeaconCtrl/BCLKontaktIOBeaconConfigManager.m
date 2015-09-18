//
//  BCLKontaktIOBeaconConfigManager.m
//  Pods
//
//  Created by Artur Wdowiarski on 18.09.2015.
//
//

#import "BCLKontaktIOBeaconConfigManager.h"
#import <KontaktSDK/KTKClient.h>
#import <KontaktSDK/KTKBluetoothManager.h>
#import <KontaktSDK/KTKBeacon.h>
#import <KontaktSDK/KTKBeaconDevice.h>
#import <KontaktSDK/KTKError.h>
#import <KontaktSDK/KTKPagingBeacons.h>
#import <KontaktSDK/KTKPagingConfigs.h>

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

- (void)startManagement
{
    NSError *error;
    
    NSArray *configsToChangeArray = [self.kontaktClient configsPaged:[[KTKPagingConfigs alloc] initWithIndexStart:0 andMaxResults:200] forDevices:KTKDeviceTypeBeacon withError:&error];
    
    NSArray *kontaktBeacons = [self.kontaktClient beaconsPaged:[[KTKPagingBeacons alloc] initWithIndexStart:0 andMaxResults:200] withError:&error];
    
    [kontaktBeacons enumerateObjectsUsingBlock:^(KTKBeacon *beacon, NSUInteger idx, BOOL *stop) {
        if ([beacon.uniqueID isEqualToString:@"em82"]) {
            NSLog(@"%@", error);
        }
    }];
    
    [configsToChangeArray enumerateObjectsUsingBlock:^(KTKBeacon *beacon, NSUInteger idx, BOOL *stop) {
        if ([beacon.uniqueID isEqualToString:@"em82"]) {
            NSLog(@"");
        }
        self.configsToUpdate[beacon.uniqueID] = beacon;
    }];
    
    [self.delegate kontaktIOBeaconManagerDidFetchBeaconsToUpdate:self];
    
    [self.kontaktBluetoothManager startFindingDevices];
}

#pragma mark - KTKBluetoothManagerDelegate

- (void)bluetoothManager:(KTKBluetoothManager *)bluetoothManager didChangeDevices:(NSSet *)devices
{
    NSLog(@"Kontakt.io bluetooth manager did change devices: %@", devices);
    if (self.isUpdatingBeacons) {
        return;
    }
    [self updateKontaktBeaconDevices:devices];
}

#pragma mark - Private

- (void)updateKontaktBeaconDevices:(NSSet *)devices
{
    self.isUpdatingBeacons = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^() {
        [devices enumerateObjectsUsingBlock:^(KTKBeaconDevice *beacon, BOOL *stop) {
            NSLog(@"");
            if ([self.configsToUpdate.allKeys containsObject:beacon.uniqueID]) {
                NSLog(@"Trying update kontakt.io beacon with uniqueId %@", beacon.uniqueID);
                NSString *password;
                NSString *masterPassword;
                KTKError *error;
                [self.kontaktClient beaconPassword:&password andMasterPassword:&masterPassword byUniqueId:beacon.uniqueID withError:&error];
                if (error) {
                    return;
                }
                if ([beacon connectWithPassword:password andError:&error]) {
                    KTKBeacon *newConfig = self.configsToUpdate[beacon.uniqueID];
                    NSError *updateError;
                    BOOL success = [self updateKontaktBeaconDevice:beacon withNewConfig:newConfig error:&updateError];
                    NSLog(@"Tried to update beacon device with uniqueId %@. Result: %lu", beacon.uniqueID, success);
                } else {
                    NSLog(@"Can't connect with beacon device with uniqueId %@", beacon.uniqueID);
                }
            }
        }];
        self.isUpdatingBeacons = NO;
    });
}

- (BOOL)updateKontaktBeaconDevice:(KTKBeaconDevice *)beaconDevice withNewConfig:(KTKBeacon *)config error:(NSError **)error
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.delegate kontaktIOBeaconManager:self didStartUpdatingBeaconWithUniqueId:config.uniqueID];
    });
    
    NSError *writeError;
    KTKCharacteristicDescriptor *descriptor;
    BOOL success = YES;
    
    if (success && config.power) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeTxPowerLevel];
        writeError = [beaconDevice writeString:config.power.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        }
    }
    
    if (success && config.proximity) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeProximityUUID];
        writeError = [beaconDevice writeString:config.proximity forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        }
    }
    
    if (success && config.major) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeMajor];
        writeError = [beaconDevice writeString:config.major.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            return NO;
        }
    }
    
    if (success && config.minor) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeMinor];
        writeError = [beaconDevice writeString:config.minor.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        }
    }
    
    if (success && config.interval) {
        descriptor = [beaconDevice characteristicDescriptorWithType:kKTKCharacteristicDescriptorTypeAdvertisingInterval];
        writeError = [beaconDevice writeString:config.interval.stringValue forCharacteristicWithDescriptor:descriptor];
        if (writeError) {
            *error = writeError;
            success = NO;
        }
    }
    
    if (success) {
        NSError *updateError;
        success = [self.kontaktClient beaconUpdate:config withError:&updateError];
        if (success) {
            *error = updateError;
        } else if (self.configsToUpdate[beaconDevice.uniqueID]) {
            [self.configsToUpdate removeObjectForKey:beaconDevice.uniqueID];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.delegate kontaktIOBeaconManager:self didFinishUpdatingBeaconWithUniqueId:config.uniqueID success:success];
    });
    
    return success;
}

@end
