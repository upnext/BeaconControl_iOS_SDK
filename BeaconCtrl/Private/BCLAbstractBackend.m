//
//  BCLAbstractBackend.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLAbstractBackend.h"
#import "NSObject+BCLAdditions.h"
#import "NSHTTPURLResponse+BCLHTTPCodes.h"
#import "BCLBeaconCtrl.h"
#import "UNCodingUtil.h"

@interface BCLAbstractBackend ()

@property (strong, nonatomic) NSMutableDictionary *retries;

@property (copy, readwrite) NSString *accessToken;

@end

@implementation BCLAbstractBackend

- (instancetype)initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret
{
    if (self = [super init]) {
        _clientId = clientId;
        _clientSecret = clientSecret;
    }
    
    return self;
}

- (NSMutableDictionary *)retries
{
    @synchronized(self) {
        if (!_retries) {
            _retries = [NSMutableDictionary dictionary];
        }
        return _retries;
    }
}

/**
 *  Retry selector
 *
 *  @param selector   selector
 *  @param sender     sender
 *  @param parameters parameters
 *
 *  @return YES if retry is possible (due tu maximum retry count)
 */
- (BOOL) retrySelector:(SEL)selector sender:(id)sender parameters:(NSArray *)parameters
{
    @synchronized(self) {
        NSString *selectorString = NSStringFromSelector(selector);
        NSNumber *retryCount = self.retries[selectorString];
        
        if (!retryCount) {
            retryCount = @(0);
        } else {
            retryCount = @(retryCount.integerValue + 1);
        }
        
        self.retries[selectorString] = retryCount;
        
        if (retryCount.integerValue > 3)
            return NO;
        
        [sender bcl_performSelector:selector withParameters:parameters];
        [self.retries removeObjectForKey:selectorString];
        return YES;
    }
}

- (void) setupURLRequest:(NSMutableURLRequest *)mutableRequest
{
    if (self.accessToken) {
        [mutableRequest addValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    }
}

- (NSDictionary *)authenticationParameters
{
    NSAssert(NO, @"This method needs to be implemented in a subclass");
    return nil;
}

+ (NSString *)baseURLString
{
    NSAssert(NO, @"This method needs to be implemented in a subclass");
    return nil;
}

+ (NSString *)authenticationURLString
{
    return [NSString stringWithFormat:@"%@/oauth/token", [self baseURLString]];
}

- (void) refetchToken:(void(^)(NSString *token, NSError *error))completion
{
    NSString *urlString = [[self class] authenticationURLString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self setupURLRequest:request];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSDictionary *params = [self authenticationParameters];
    
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:nil]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      
                                      NSError *jsonError = nil;
                                      NSDictionary *responseDictionary = nil;
                                      if (data) {
                                          responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                      }
                                      
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                      if (error || ![httpResponse isSuccess]) {
                                          if (completion) {
                                              completion(nil, error ?: [NSError errorWithDomain:BCLErrorDomain code:BCLErrorHTTPError userInfo:@{NSLocalizedDescriptionKey: [httpResponse description], @"BCLResponseDictionaryKey": responseDictionary ? : [NSNull null]}]);
                                          }
                                          return;
                                      }
                                      
                                      
                                      if (!responseDictionary && jsonError) {
                                          if (completion) {
                                              completion(nil, jsonError);
                                          }
                                          return;
                                      }
                                      
                                      NSString *accessToken = responseDictionary[@"access_token"];
                                      
                                      if (!accessToken && completion) {
                                          completion(nil, [NSError errorWithDomain:BCLErrorDomain code:BCLInvalidDataErrorCode userInfo:@{NSLocalizedDescriptionKey: @"Unable to fetch token"}]);
                                      }
                                      
                                      self.accessToken = accessToken;
                                      
                                      if (completion) {
                                          completion(self.accessToken, nil);
                                      }
                                  }];
    
    [task resume];
}

- (BOOL)shouldFurtherProcessResponse:(NSURLResponse *)response completion:(void(^)(NSError *error))completion
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    if (httpResponse.statusCode == 401) {
        // need authorization
        [self refetchToken:^(NSString *token, NSError *error) {
            if (completion) {
                completion(error);
            }
        }];
        return YES;
    }
    return NO;
}

- (void)reset
{
    self.accessToken = nil;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (!self) {
        return nil;
    }
    [UNCodingUtil decodeObject:self withCoder:aDecoder];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [UNCodingUtil encodeObject:self withCoder:aCoder];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

#pragma mark UNCoding

- (instancetype) initWithDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        [[[UNCodingUtil alloc] initWithObject:self] loadDictionaryRepresentation:dictionary];
    }
    return self;
}

- (NSDictionary *) dictionaryRepresentation
{
    return [[[UNCodingUtil alloc] initWithObject:self] dictionaryRepresentation];
}



@end
