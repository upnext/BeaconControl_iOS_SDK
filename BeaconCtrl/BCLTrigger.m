//
//  BCLTrigger.m
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLTrigger.h"
#import "BCLCondition.h"
#import "BCLConfiguration.h"
#import "BCLActionEvent.h"
#import "BCLBeaconCtrlDelegate.h"
#import "UNCodingUtil.h"

@implementation BCLTrigger

- (instancetype) init
{
    if (self = [super init]) {
        self.conditions = (NSArray <BCLCondition> *)[NSArray array];
        self.actions = [NSArray array];
    }
    return self;
}

- (void)updatePropertiesFromDictionary:(NSDictionary *)dictionary
{
    // load conditions
    for (NSDictionary *conditionDictionary in dictionary[@"conditions"]) {
        // parameters without key "type"
        NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
        NSArray *parameterKeys = [conditionDictionary.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@",@"type"]];
        for (NSString *key in parameterKeys) {
            parameters[key] = conditionDictionary[key];
        }

        Class conditionClass = [BCLConfiguration classForName:conditionDictionary[@"type"] protocol:@protocol(BCLCondition) selector:@selector(bcl_conditionType)];
        if (conditionClass) {
            id <BCLCondition> conditionImpl = [[conditionClass alloc] initWithParameters:parameters];
            self.conditions = (NSArray <BCLCondition> *)[self.conditions arrayByAddingObject:conditionImpl];
        }
    }
    
    BCLAction *action = [[BCLAction alloc] init];
    action.identifier = dictionary[@"action"][@"id"];
    action.name = dictionary[@"action"][@"name"];
    action.type = dictionary[@"action"][@"type"];
    action.isTestAction = [dictionary[@"test"] boolValue];
    
    action.customValues = dictionary[@"action"][@"custom_attributes"];
    action.payload = dictionary[@"action"][@"payload"];
    action.trigger = self;
    self.actions = [self.actions arrayByAddingObject:action];
}

@end
