//
//  BCLAction.h
//
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "BCLEncodableObject.h"

@class BCLTrigger;

/*!
 * A class representing BeaconCtrl actions in the SDK
*/
@interface BCLAction : BCLEncodableObject

/** @name Properties */

/// An identifier assigned by the backend
@property (strong) NSNumber *identifier;

/// Action's name
@property (strong) NSString *name;

/// Action's type
@property (strong) NSString *type;

/// Is this a test action (a special subtype of a custom action that can be created while adding a beacon in the admin interface)
@property (nonatomic) BOOL isTestAction;

/// An array with custom values assigned to an action in the admin interface
@property (strong) NSArray *customValues;

/// A dictionary with a custom payload of an action (e.g. an URL in case of URL actions)
@property (strong) NSDictionary *payload;

/// A trigger that calls an action
@property (weak) BCLTrigger *trigger;

/// A callback that is called when an action is performed
@property (copy) void(^onActionCallback)(BCLAction *action);

/** @name Methods */

/*!
 * @brief A shortcut method that returns an URL assigned to some types of actions
 *
 * @return An URL object assigned to an action
 */
- (NSURL *)URL;

@end
