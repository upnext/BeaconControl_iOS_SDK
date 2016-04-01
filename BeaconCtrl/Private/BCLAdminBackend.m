//
//  BCLAdminBackend.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLAdminBackend.h"
#import "BCLBeaconCtrl.h"
#import "BCLBeacon.h"
#import "BCLZone.h"
#import "BCLLocation.h"
#import "NSHTTPURLResponse+BCLHTTPCodes.h"
#import "UIColor+Hex.h"

@interface BCLAdminBackend ()

@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *password;

@end

@implementation BCLAdminBackend

+ (NSString *) baseURLString
{
    NSString *baseURLAPI = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BCLBaseURLAPI"];
    
    if (baseURLAPI) {
        return [NSString stringWithFormat:@"%@/s2s_api/v1",baseURLAPI];
    }
    
    return @"https://admin.beaconctrl.com/s2s_api/v1";
}

- (NSDictionary *)authenticationParameters
{
    return @{
             @"client_id": self.clientId,
             @"client_secret": self.clientSecret,
             @"grant_type": @"password",
             @"email": self.email,
             @"password": self.password
             };
}

- (void)authenticateUserWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(BOOL, NSError *))completion
{
    self.email = email;
    self.password = password;
    
    [self refetchToken:^(NSString *token, NSError *error) {
        if (completion) {
            completion(token != nil, error);
        }
    }];
}

- (void)registerNewUserWithEmail:(NSString *)email password:(NSString *)password passwordConfirmation:(NSString *)passwordConfirmation completion:(void (^)(BOOL, NSError *))completion
{
    self.email = email;
    self.password = password;
    
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/admins", [[self class] baseURLString]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSDictionary *params = @{
                             @"client_id": self.clientId,
                             @"client_secret": self.clientSecret,
                             @"admin" : @{
                                     @"email": self.email,
                                     @"password": self.password
                                     }
                             };
    
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:nil]];
    
    __weak typeof(self) weakSelf = self;
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description], @"BCLResponseDictionaryKey": responseDictionary}]);
                                          }
                                          return;
                                      }
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      [weakSelf refetchToken:^(NSString *token, NSError *authenticationError) {
                                          if (completion) {
                                              completion(token != nil, authenticationError);
                                          }
                                      }];
                                  }];
    [task resume];
}

- (void)fetchTestApplicationCredentials:(void (^)(NSString *, NSString *, NSError *))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/applications", [[self class] baseURLString]];
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
                                              if(completion) completion(nil, nil, processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(fetchConfiguration:) sender:self parameters:@[completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          __block NSDictionary *testAppDict;
                                          
                                          [responseDictionary[@"applications"] enumerateObjectsUsingBlock:^(NSDictionary *appDict, NSUInteger idx, BOOL *stop) {
                                              if ([appDict[@"test"] isEqualToNumber:@1]) {
                                                  testAppDict = appDict;
                                                  *stop = YES;
                                              }
                                          }];
                                          
                                          NSString *applicationClientId = testAppDict[@"uid"];
                                          NSString *applicationClientSecret = testAppDict[@"secret"];
                                          
                                          completion(applicationClientId, applicationClientSecret, nil);
                                      }
                                  }];
    [task resume];
}

- (void)fetchVendors:(void (^)(NSArray *vendors, NSError *error))completion
{
    NSString *urlString = [NSString stringWithFormat:@"%@/vendors", [[self class] baseURLString]];
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
                                          
                                      }]) {
                                          return;
                                      }
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          NSArray *vendors;
                                          if ([responseDictionary respondsToSelector:@selector(objectForKey:)]) {
                                              vendors = responseDictionary[@"vendors"];
                                          }
                                          
                                          completion(vendors, nil);
                                      }
                                  }];
    [task resume];
}

- (void)createBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BCLBeacon *, NSError *))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/beacons", [[self class] baseURLString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSMutableDictionary *params = [@{
                                     @"client_id": self.clientId,
                                     @"client_secret": self.clientSecret
                                     } mutableCopy];
    
    NSMutableDictionary *beaconDict = [[NSMutableDictionary alloc] init];
    if (beacon.name) beaconDict[@"name"] = beacon.name;
    if (beacon.proximityUUID.UUIDString) beaconDict[@"uuid"] = beacon.proximityUUID.UUIDString;
    if (beacon.major) beaconDict[@"major"] = beacon.major;
    if (beacon.minor) beaconDict[@"minor"] = beacon.minor;
    
    if (beacon.location) {
        beaconDict[@"lat"] = @(beacon.location.location.coordinate.latitude);
        beaconDict[@"lng"] = @(beacon.location.location.coordinate.longitude);
        if (beacon.location.floor) {
            beaconDict[@"floor"] = beacon.location.floor;
        }
    }
    
    if (beacon.zone) {
        beaconDict[@"zone_id"] = beacon.zone.zoneIdentifier;
    }
    
    if (beacon.vendor) {
        beaconDict[@"vendor"] = beacon.vendor;
    }
    
    if (testActionName) {
        beaconDict[@"activity"] = @{
                                    @"name": testActionName,
                                    @"trigger_attributes" : @{
                                            @"test": @"true",
                                            @"event_type": [self triggerNameForEventType:trigger]
                                            },
                                    @"custom_attributes_attributes": testActionAttributes
                                    };
    }
    
    params[@"beacon"] = beaconDict.copy;
    
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:nil]];
    
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
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      NSLog(@"Response dictionary: %@", responseDictionary);
                                      NSLog(@"Is success: %lu", httpResponse.isSuccess);
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description], @"BCLResponseDictionaryKey": responseDictionary}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          BCLBeacon *newBeacon = [[BCLBeacon alloc] init];
                                          [newBeacon updatePropertiesFromDictionary:responseDictionary[@"range"]];
                                          
                                          completion(newBeacon, nil);
                                      }
                                  }];
    [task resume];
}

- (void)updateBeacon:(BCLBeacon *)beacon testActionName:(NSString *)testActionName testActionTrigger:(BCLEventType)trigger testActionAttributes:(NSArray *)testActionAttributes completion:(void (^)(BOOL, NSError *))completion
{
    if (!self.clientId || !self.clientSecret || !beacon.beaconIdentifier) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/beacons/%@", [[self class] baseURLString], beacon.beaconIdentifier];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"PUT";
    [self setupURLRequest:request];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSMutableDictionary *params = [@{
                                     @"client_id": self.clientId,
                                     @"client_secret": self.clientSecret
                                     } mutableCopy];
    
    NSMutableDictionary *beaconDict = [[NSMutableDictionary alloc] init];
    if (beacon.name) beaconDict[@"name"] = beacon.name;
    if (beacon.proximityUUID.UUIDString) beaconDict[@"uuid"] = beacon.proximityUUID.UUIDString;
    if (beacon.major) beaconDict[@"major"] = beacon.major;
    if (beacon.minor) beaconDict[@"minor"] = beacon.minor;
    
    if (beacon.location) {
        beaconDict[@"lat"] = @(beacon.location.location.coordinate.latitude);
        beaconDict[@"lng"] = @(beacon.location.location.coordinate.longitude);
        if (beacon.location.floor) {
            beaconDict[@"floor"] = beacon.location.floor;
        }
    }
    
    if (beacon.vendor) {
        beaconDict[@"vendor"] = beacon.vendor;
    }
    
    if (beacon.zone) {
        beaconDict[@"zone_id"] = beacon.zone.zoneIdentifier;
    } else {
        beaconDict[@"zone_id"] = @"null";
    }
    
    if (testActionName) {
        beaconDict[@"activity"] = @{
                                    @"name": testActionName,
                                    @"trigger_attributes" : @{
                                            @"test": @"true",
                                            @"event_type": [self triggerNameForEventType:trigger]
                                            },
                                    @"custom_attributes_attributes": testActionAttributes
                                    };
    }
    
    params[@"beacon"] = beaconDict.copy;
    
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:nil]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      if ([self shouldFurtherProcessResponse:response completion:^(NSError *processingError) {
                                          if (processingError) {
                                              if(completion) completion(NO, processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(fetchConfiguration:) sender:self parameters:@[completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(NO, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (httpResponse.statusCode == 204 && completion) {
                                          completion(YES, nil);
                                      }
                                  }];
    [task resume];
    
}

- (void)deleteBeacon:(BCLBeacon *)beacon completion:(void (^)(BOOL, NSError *))completion
{
    if (!self.clientId || !self.clientSecret || !beacon.beaconIdentifier) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/beacons/%@", [[self class] baseURLString], beacon.beaconIdentifier];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"DELETE";
    [self setupURLRequest:request];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      if ([self shouldFurtherProcessResponse:response completion:^(NSError *processingError) {
                                          if (processingError) {
                                              if(completion) completion(NO, processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(fetchConfiguration:) sender:self parameters:@[completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(NO, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          completion(YES, nil);
                                      }
                                  }];
    [task resume];
    
}

- (void)fetchBeacons:(void (^)(NSSet *beacons, NSError *error))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/beacons", [[self class] baseURLString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"GET";
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
                                      
                                      NSError *jsonError = nil;
                                      
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          NSMutableSet *beaconsSet = [NSMutableSet set];
                                          
                                          for (NSDictionary *beaconDictionary in responseDictionary[@"ranges"]) {
                                              BCLBeacon *beacon = [[BCLBeacon alloc] init];
                                              [beacon updatePropertiesFromDictionary:beaconDictionary];
                                              [beaconsSet addObject:beacon];
                                          }
                                          
                                          completion([beaconsSet copy], nil);
                                      }
                                  }];
    [task resume];
}

- (void)syncBeacon:(BCLBeacon *)beacon completion:(void (^)(NSError *))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion([NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/beacons/%@/sync", [BCLAdminBackend baseURLString], beacon.beaconIdentifier];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"PUT";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
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
                                          
                                          [self retrySelector:@selector(syncBeacon:completion:) sender:self parameters:@[beacon, completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
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
                                              completion(jsonError);
                                          }
                                          return;
                                      }
                                      
                                      [beacon updatePropertiesFromDictionary:responseDictionary[@"range"]];
                                      
                                      if (completion) {
                                          completion(nil);
                                      }
                                  }];
    [task resume];
}

- (void)fetchZones:(NSSet *)beacons completion:(void (^)(NSSet *zones, NSError *error))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/zones", [[self class] baseURLString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"GET";
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
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          NSMutableSet *zonesSet = [NSMutableSet set];
                                          
                                          for (NSDictionary *zoneDictionary in responseDictionary[@"zones"]) {
                                              BCLZone *zone = [[BCLZone alloc] init];
                                              [zone updatePropertiesFromDictionary:zoneDictionary beacons:beacons];
                                              [zonesSet addObject:zone];
                                          }
                                          
                                          completion([zonesSet copy], nil);
                                      }
                                  }];
    [task resume];
}

- (void)fetchZoneColors:(void (^)(NSArray *zoneColors, NSError *error))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/zone_colors", [[self class] baseURLString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"GET";
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
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          NSMutableArray *mutableColors = @[].mutableCopy;
                                          
                                          [responseDictionary[@"colors"] enumerateObjectsUsingBlock:^(NSDictionary *colorDict, NSUInteger idx, BOOL *stop) {
                                              [mutableColors addObject:colorDict[@"color"]];
                                          }];
                                          
                                          completion(mutableColors.copy, nil);
                                      }
                                  }];
    [task resume];
    
}

- (void)createZone:(BCLZone *)zone completion:(void (^)(BCLZone *, NSError *))completion
{
    if (!self.clientId || !self.clientSecret) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/zones", [[self class] baseURLString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSMutableDictionary *params = [@{
                                     @"client_id": self.clientId,
                                     @"client_secret": self.clientSecret
                                     } mutableCopy];
    
    NSMutableDictionary *zoneDict = [@{
                                       @"name": zone.name
                                       } mutableCopy];
    
    if (zone.beacons.count) {
        NSMutableArray *beaconIds = [@[] mutableCopy];
        for (BCLBeacon *beacon in zone.beacons) {
            [beaconIds addObject:beacon.beaconIdentifier];
        }
        
        zoneDict[@"beacon_ids"] = [beaconIds copy];
    }
    
    if (zone.color) {
        zoneDict[@"color"] = [zone.color hexString].uppercaseString;
    }
    
    params[@"zone"] = zoneDict.copy;
    
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:nil]];
    
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
                                      
                                      NSError *jsonError = nil;
                                      
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description], @"BCLResponseDictionaryKey": responseDictionary}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          NSMutableSet *beaconsSet = [NSMutableSet set];
                                          
                                          for (NSDictionary *beaconDictionary in responseDictionary[@"zone"][@"beacons"]) {
                                              BCLBeacon *beacon = [[BCLBeacon alloc] init];
                                              [beacon updatePropertiesFromDictionary:beaconDictionary];
                                              [beaconsSet addObject:beacon];
                                          }
                                          
                                          BCLZone *newZone = [[BCLZone alloc] init];
                                          [newZone updatePropertiesFromDictionary:responseDictionary[@"zone"] beacons:beaconsSet];
                                          
                                          completion(newZone, nil);
                                      }
                                  }];
    [task resume];
    
}

- (void)updateZone:(BCLZone *)zone completion:(void (^)(BOOL, NSError *))completion
{
    if (!self.clientId || !self.clientSecret || !zone.zoneIdentifier) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/zones/%@", [[self class] baseURLString], zone.zoneIdentifier];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"PUT";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSMutableDictionary *params = [@{
                                     @"client_id": self.clientId,
                                     @"client_secret": self.clientSecret
                                     } mutableCopy];
    
    NSMutableDictionary *zoneDict = [@{
                                       @"name": zone.name,
                                       } mutableCopy];
    
    if (zone.beacons.count) {
        NSMutableArray *beaconIds = [@[] mutableCopy];
        for (BCLBeacon *beacon in zone.beacons) {
            [beaconIds addObject:beacon.beaconIdentifier];
        }
        
        zoneDict[@"beacon_ids"] = [beaconIds copy];
        if (zone.color) {
            zoneDict[@"color"] = [zone.color hexString];
        }
    }
    
    params[@"zone"] = zoneDict.copy;
    
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:nil]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      if ([self shouldFurtherProcessResponse:response completion:^(NSError *processingError) {
                                          if (processingError) {
                                              if(completion) completion(NO, processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(fetchConfiguration:) sender:self parameters:@[completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(NO, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description], @"BCLResponseDictionaryKey": responseDictionary}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (httpResponse.statusCode == 204 && completion) {
                                          completion(YES, nil);
                                      }
                                  }];
    [task resume];
    
}

- (void)deleteZone:(BCLZone *)zone completion:(void (^)(BOOL, NSError *))completion
{
    if (!self.clientId || !self.clientSecret || !zone.zoneIdentifier) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidParametersErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid backend integration"}]);
        }
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/zones/%@", [[self class] baseURLString], zone.zoneIdentifier];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"DELETE";
    [self setupURLRequest:request];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      
                                      if ([self shouldFurtherProcessResponse:response completion:^(NSError *processingError) {
                                          if (processingError) {
                                              if(completion) completion(NO, processingError);
                                              return;
                                          }
                                          
                                          [self retrySelector:@selector(fetchConfiguration:) sender:self parameters:@[completion]];
                                      }]) {
                                          return;
                                      }
                                      
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(NO, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description]}]);
                                          }
                                          return;
                                      }
                                      
                                      if (completion) {
                                          completion(YES, nil);
                                      }
                                  }];
    [task resume];
}

#pragma mark - Private

- (NSString *)triggerNameForEventType:(BCLEventType)eventType
{
    switch (eventType) {
        case BCLEventTypeEnter:
            return @"enter";
            break;
        case BCLEventTypeLeave:
            return @"leave";
        case BCLEventTypeRangeImmediate:
            return @"immediate";
            break;
        case BCLEventTypeRangeNear:
            return @"near";
            break;
        case BCLEventTypeRangeFar:
            return @"far";
            break;
        default:
            return nil;
            break;
    }
}

@end
