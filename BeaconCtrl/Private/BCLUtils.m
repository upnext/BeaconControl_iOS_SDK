//
//  BCLUtils.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLUtils.h"

NSArray* AllocNotRetainedArray() {
    CFArrayRef arrayRef = NULL;
    CFArrayCallBacks notRetainedCallbacks = kCFTypeArrayCallBacks;
    notRetainedCallbacks.retain = NULL;
    notRetainedCallbacks.release = NULL;
    arrayRef = CFArrayCreate(kCFAllocatorDefault, 0, 0, &notRetainedCallbacks);
    return (__bridge NSArray *)arrayRef;
}

NSSet* AllocNotRetainedSet() {
    CFSetRef setRef = NULL;
    CFSetCallBacks notRetainedCallbacks = kCFTypeSetCallBacks;
    notRetainedCallbacks.retain = NULL;
    notRetainedCallbacks.release = NULL;
    setRef = CFSetCreate(kCFAllocatorDefault, 0, 0, &notRetainedCallbacks);
    return (__bridge NSSet *)setRef;
}
