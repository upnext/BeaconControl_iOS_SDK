//
//  BCLKontaktIOBeaconConfigManager.h
//  Pods
//
//  Created by Artur Wdowiarski on 18.09.2015.
//
//

#import <Foundation/Foundation.h>

@class BCLKontaktIOBeaconConfigManager;

@protocol BCLKontaktIOBeaconConfigManagerDelegate <NSObject>

- (void)kontaktIOBeaconManagerDidFetchKontaktIOBeacons:(BCLKontaktIOBeaconConfigManager *)manager;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didMonitorBeaconDevices:(NSArray *)devices;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didStartUpdatingBeaconWithUniqueId:(NSString *)uniqueId;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didFinishUpdatingBeaconWithUniqueId:(NSString *)uniqueId success:(BOOL)success;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didStartUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager isUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId progress:(NSUInteger)progress;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didFinishUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId success:(BOOL)success;

@end

@interface BCLKontaktIOBeaconConfigManager : NSObject

@property (nonatomic, weak) id <BCLKontaktIOBeaconConfigManagerDelegate> delegate;

@property (nonatomic, copy) NSMutableDictionary *configsToUpdate;

@property (nonatomic, copy) NSMutableDictionary *firmwaresToUpdate;

@property (nonatomic, strong) NSMutableDictionary *kontaktBeaconsDictionary;

- (instancetype)initWithApiKey:(NSString *)apiKey;

- (void)startManagement;

@end
