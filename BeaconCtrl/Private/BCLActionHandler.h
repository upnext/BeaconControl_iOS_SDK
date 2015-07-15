//
//  BCLActionHandler.h
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLAction.h"

@protocol BCLActionHandler <NSObject>

+ (NSString *)handledActionTypeName;

- (void)handleAction:(BCLAction *)action;

@end
