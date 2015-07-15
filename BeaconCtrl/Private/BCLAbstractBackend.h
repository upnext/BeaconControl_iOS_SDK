//
//  BCLAbstractBackend.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "UNCoding.h"

@interface BCLAbstractBackend : NSObject <UNCoding>

@property (nonatomic, copy) NSString *clientId;
@property (nonatomic, copy) NSString *clientSecret;

@property (copy, readonly) NSString *accessToken;

- (instancetype) initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret;

+ (NSString *) baseURLString;
+ (NSString *) authenticationURLString;

- (void) setupURLRequest:(NSMutableURLRequest *)mutableRequest;
- (BOOL)shouldFurtherProcessResponse:(NSURLResponse *)response completion:(void(^)(NSError *error))completion;
- (BOOL) retrySelector:(SEL)selector sender:(id)sender parameters:(NSArray *)parameters;
- (void) refetchToken:(void(^)(NSString *token, NSError *error))completion;
- (NSDictionary *)authenticationParameters;
- (void) reset;

@end
