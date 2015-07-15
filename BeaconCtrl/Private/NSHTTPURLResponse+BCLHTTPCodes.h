//
//  NSHTTPURLResponse+BCLHTTPCodes.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

@interface NSHTTPURLResponse (BCLHTTPCodes)

@property (readonly) BOOL isInformational;
@property (readonly) BOOL isSuccess;
@property (readonly) BOOL isRedirect;
@property (readonly) BOOL isClientError;
@property (readonly) BOOL isServerError;

@end
