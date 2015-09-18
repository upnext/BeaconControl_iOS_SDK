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

- (void)kontaktIOBeaconManagerDidFetchBeaconsToUpdate:(BCLKontaktIOBeaconConfigManager *)manager;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didStartUpdatingBeaconWithUniqueId:(NSString *)uniqueId;
- (void)kontaktIOBeaconManager:(BCLKontaktIOBeaconConfigManager *)manager didFinishUpdatingBeaconWithUniqueId:(NSString *)uniqueId success:(BOOL)success;

@end

@interface BCLKontaktIOBeaconConfigManager : NSObject

@property (nonatomic, weak) id <BCLKontaktIOBeaconConfigManagerDelegate> delegate;

@property (nonatomic, copy) NSMutableDictionary *configsToUpdate;

- (instancetype)initWithApiKey:(NSString *)apiKey;

- (void)startManagement;

@end
