//
//  BCLBackend.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLBackend.h"

#import "BCLActionEvent.h"
#import "BCLBeaconCtrl.h"
#import "BCLBeacon.h"
#import "NSHTTPURLResponse+BCLHTTPCodes.h"
#import "BCLZone.h"
#import "NSUserDefaults+BCLiCloud.h"

static NSString * const BeaconCtrlUserIdKey = @"BeaconCtrlUserId";

@interface BCLBackend ()
@property (copy, readwrite) NSString *pushEnvironment;
@property (copy, readwrite) NSString *pushToken;

@end

@implementation BCLBackend

@synthesize userId = _userId;

- (instancetype) initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret pushEnvironment:(NSString *)pushEnvironment pushToken:(NSString *)pushToken
{
    if (self = [super initWithClientId:clientId clientSecret:clientSecret]) {
        _pushEnvironment = pushEnvironment;
        _pushToken = pushToken;
    }
    return self;
}

- (NSString *)userId
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (!_userId) {
        _userId = [defaults objectForKey:BeaconCtrlUserIdKey iCloudSync:YES];
    }
    
    if (!_userId) {
        _userId = [[NSUUID UUID] UUIDString];
        [defaults setObject:_userId forKey:BeaconCtrlUserIdKey iCloudSync:YES];
        [defaults synchronizeWithiCloud];
    }
    
    return _userId;
}

- (void)setUserId:(NSString *)userId
{
    _userId = userId;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_userId forKey:BeaconCtrlUserIdKey iCloudSync:YES];
    [defaults synchronizeWithiCloud];
}

+ (NSString *) baseURLString
{
    NSString *baseURLAPI = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BCLBaseURLAPI"];
    
    if (baseURLAPI) {
        return [NSString stringWithFormat:@"%@/api/v1", baseURLAPI];
    }
    
    return @"https://admin.beaconctrl.com/api/v1";
}

- (NSDictionary *)authenticationParameters
{
    
    NSMutableDictionary *params = [@{
                                     @"client_id": self.clientId,
                                     @"client_secret": self.clientSecret,
                                     @"grant_type": @"password",
                                     @"user_id": self.userId,
                                     @"os": @"ios"
                                     } mutableCopy];
    
    if (self.pushEnvironment) {
        params[@"environment"] = self.pushEnvironment;
    }
    
    if (self.pushToken) {
        params[@"push_token"] = self.pushToken;
    }
    
    return [params copy];
}

- (void)fetchConfiguration:(void(^)(BCLConfiguration *configuration, NSError *error))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/configurations", [BCLBackend baseURLString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      if ([self shouldFurtherProcessResponse:response completion:^(NSError *processingError) {
                                          if (processingError) {
                                              if(completion) completion(nil, processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(fetchConfiguration:) sender:self parameters:@[completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      BCLConfiguration *configuration = [[BCLConfiguration alloc] initWithJSON:data];
                                      if (!configuration) {
                                          if (completion) {
                                              completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidDataErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Unable to fetch configuration"}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (completion) {
                                          completion(configuration, nil);
                                      }
                                  }];
    [task resume];
}

- (void) sendEvents:(NSArray *)events completion:(void(^)(NSError *error))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion([NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    if (!events || (events.count == 0)) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/events", [BCLBackend baseURLString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"events"] = [NSMutableArray arrayWithCapacity:events.count];
    for (BCLActionEvent *event in events) {
        NSMutableDictionary *eventDict = [NSMutableDictionary dictionary];
        
        eventDict = [@{@"timestamp": @(event.timestamp)} mutableCopy];
        
        if (event.beaconIdentifier) {
            eventDict[@"range_id"] = event.beaconIdentifier;
        }
        
        if (event.zoneIdentifier) {
            eventDict[@"zone_id"] = event.zoneIdentifier;
        }
        
        if (event.eventTypeName) {
            eventDict[@"event_type"] = event.eventTypeName;
        }
        
        if (event.actionName) {
            eventDict[@"action_name"] = event.actionName;
        }
        
        if (event.actionIdentifier) {
            eventDict[@"action_id"] = event.actionIdentifier;
        }
        
        [payload[@"events"] addObject:[eventDict copy]];
    }
    
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
    
#ifdef DEBUG
    NSLog(@"sendEvents\n%@",[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
#endif
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      if ([self shouldFurtherProcessResponse:response completion:^(NSError *processingError) {
                                          if (processingError) {
                                              if(completion) completion(processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(sendEvents:completion:) sender:self parameters:@[events, completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          completion(nil);
                                      }
                                  }];
    [task resume];
}

#pragma mark - Backend IntegrationPresence

- (void)fetchUsersInRangesOfBeacons:(NSSet *)beacons zones:(NSSet *)zones completion:(void (^)(NSDictionary *, NSError *))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSMutableArray *beaconIdList = [NSMutableArray array];
    [beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
        [beaconIdList addObject:[NSString stringWithFormat:@"%@", beacon.beaconIdentifier]];
    }];
    
    NSMutableArray *zoneIdList = [NSMutableArray array];
    [zones enumerateObjectsUsingBlock:^(BCLZone *zone, BOOL *stop) {
        [zoneIdList addObject:[NSString stringWithFormat:@"%@", zone.zoneIdentifier]];
    }];
    
    NSString *pathString = [NSString stringWithFormat:@"%@/presence", [BCLBackend baseURLString]];
    
    NSMutableString *queryString = [NSMutableString string];
    if (beacons.count || zones.count) {
        if (beacons.count) {
            [beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
                [queryString appendFormat:@"&ranges[]=%@", beacon.beaconIdentifier];
            }];
            
            [queryString deleteCharactersInRange:NSMakeRange(0, 1)];
        }
        
        if (zones.count) {
            [zones enumerateObjectsUsingBlock:^(BCLZone *zone, BOOL *stop) {
                [queryString appendFormat:@"&zones[]=%@", zone.zoneIdentifier];
            }];
            
            if (!beacons.count) {
                [queryString deleteCharactersInRange:NSMakeRange(0, 1)];
            }
        }
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", pathString, queryString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      if ([self shouldFurtherProcessResponse:response completion:^(NSError *processingError) {
                                          if (processingError) {
                                              if(completion) completion(nil, processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(fetchUsersInRangesOfBeacons:zones:completion:) sender:self parameters:@[beacons ? : [NSNull null], zones ? : [NSNull null], completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
                                          resultDictionary[@"ranges"] = [NSMutableDictionary dictionary];
                                          resultDictionary[@"zones"] = [NSMutableDictionary dictionary];
                                          [beacons enumerateObjectsUsingBlock:^(BCLBeacon *beacon, BOOL *stop) {
                                              if (responseDictionary[@"ranges"][beacon.beaconIdentifier]) {
                                                  resultDictionary[@"ranges"][beacon] = responseDictionary[@"ranges"][beacon.beaconIdentifier];
                                              }
                                          }];
                                          
                                          [zones enumerateObjectsUsingBlock:^(BCLZone *zone, BOOL *stop) {
                                              if (responseDictionary[@"zones"][zone.zoneIdentifier]) {
                                                  resultDictionary[@"zones"][zone] = responseDictionary[@"zones"][zone.zoneIdentifier];
                                              }
                                          }];
                                          
                                          completion([resultDictionary copy], nil);
                                      }
                                  }];
    [task resume];
}

@end
