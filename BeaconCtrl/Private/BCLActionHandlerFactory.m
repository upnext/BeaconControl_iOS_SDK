//
//  BCLActionHandlerFactory.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLActionHandlerFactory.h"
#import "BCLActionHandler.h"
#import <objc/runtime.h>

static NSDictionary *_actionHandlerMapping;

@implementation BCLActionHandlerFactory

- (id)init
{
    if (self = [super init]) {
        if (!_actionHandlerMapping) {
            _actionHandlerMapping = [BCLActionHandlerFactory mappingDictionary];
        }
    }
    
    return self;
}

- (id<BCLActionHandler>)actionHandlerForActionTypeName:(NSString *)actionTypeName
{
    return _actionHandlerMapping[actionTypeName.lowercaseString];
}

#pragma mark - Private

+ (NSDictionary *)mappingDictionary
{
    int numberOfClasses = objc_getClassList(NULL, 0);
    Class classList[numberOfClasses];
    numberOfClasses = objc_getClassList(classList, numberOfClasses);
    
    NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
    
    for (int i = 0; i < numberOfClasses; i++) {
        Class aClass = classList[i];

        if (class_getClassMethod(aClass, @selector(conformsToProtocol:)) && [aClass conformsToProtocol:@protocol(BCLActionHandler)]) {
            mapping[[aClass handledActionTypeName]] = [[aClass alloc] init];
        }
    }
    
    return [mapping copy];
}

@end
