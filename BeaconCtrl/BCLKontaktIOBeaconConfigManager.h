//
//  BCLKontaktIOBeaconConfigManager.h
//  Pods
//
//  Created by Artur Wdowiarski on 18.09.2015.
//
//

#import <Foundation/Foundation.h>

@class BCLKontaktIOBeaconConfigManager;
@class KTKBeacon;

@protocol BCLKontaktIOBeaconConfigManagerDelegate <NSObject>

- (void)kontaktIOBeaconManagerDidFetchKontaktIOBeacons:(BCLKontaktIOBeaconConfigManager *)manager;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didMonitorBeaconDevices:(NSArray *)devices;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didStartUpdatingBeaconWithUniqueId:(NSString *)uniqueId;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didFinishUpdatingBeaconWithUniqueId:(NSString *)uniqueId newConfig:(KTKBeacon *)config success:(BOOL)success;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didStartUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager isUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId progress:(NSUInteger)progress;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didFinishUpdatingFirmwareForBeaconWithUniqueId:(NSString *)uniqueId newFirwmareVersion:(NSString *)firmwareVersion success:(BOOL)success;

@end

@interface BCLKontaktIOBeaconConfigManager : NSObject

@property (nonatomic, weak) id <BCLKontaktIOBeaconConfigManagerDelegate> delegate;

@property (nonatomic, copy) NSMutableDictionary *configsToUpdate;

@property (nonatomic, copy) NSMutableDictionary *firmwaresToUpdate;

@property (nonatomic, strong) NSMutableDictionary *kontaktBeaconsDictionary;

- (instancetype)initWithApiKey:(NSString *)apiKey;

- (void)fetchConfiguration:(void(^)(NSError *error))completion;

- (void)startManagement;

- (NSDictionary *)fieldsToUpdateForKontaktBeacon:(KTKBeacon *)beacon;

@end
