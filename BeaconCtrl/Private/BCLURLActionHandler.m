//
//  BCLURLActionHandler.m
//  BeaconCtrl
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import "BCLURLActionHandler.h"
#import "UIWindow+BCLVisibleViewController.h"

@interface BCLURLActionHandler ()

@property (nonatomic, weak, readonly) UIWebView *webView;
@property (nonatomic) BOOL isPresenting;
@property (nonatomic) BOOL isDismissing;
@property (nonatomic, strong) NSMutableArray *navigationControllers;

@end

@implementation BCLURLActionHandler

- (instancetype)init
{
    if (self = [super init]) {
        _navigationControllers = [@[] mutableCopy];
    }
    
    return self;
}

+ (NSString *)handledActionTypeName
{
    return @"url";
}

- (void)handleAction:(BCLAction *)action
{
    NSLog(@"Is going to explicitly perform coupon action: %@", action);
    
    if (self.isPresenting || self.isDismissing) {
        [self performSelector:@selector(handleAction:) withObject:action afterDelay:0.3];
        return;
    }
    
    UIViewController *visibleViewController = [[UIApplication sharedApplication].keyWindow bcl_visibleViewController];
    
    if (![self canPresentURLOnViewController:visibleViewController]) {
        [self performSelector:@selector(handleAction:) withObject:action afterDelay:5];
        return;
    }
    
    UIViewController *webViewController = [[UIViewController alloc] init];
    webViewController.view.frame = visibleViewController.view.frame;
    UIWebView *webView = [[UIWebView alloc] initWithFrame:webViewController.view.frame];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [webViewController.view addSubview:webView];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    [self.navigationControllers addObject:navigationController];
    
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissCoupon:)];
    webViewController.navigationItem.rightBarButtonItem = barButtonItem;
    
    self.isPresenting = YES;
    dispatch_async(dispatch_get_main_queue(), ^() {
        [visibleViewController presentViewController:navigationController animated:YES completion:^() {
            self.isPresenting = NO;
            [webView loadRequest:[NSURLRequest requestWithURL:action.URL]];
        }];
    });
}

- (void)dismissCoupon:(id)sender
{
    UINavigationController *navigationController = (UINavigationController *)[[[sender nextResponder] nextResponder] nextResponder];
    
    if ([navigationController.visibleViewController.navigationItem.rightBarButtonItem isEqual:sender]) {
        self.isDismissing = YES;
        [navigationController dismissViewControllerAnimated:YES completion:^() {
            self.isDismissing = NO;
        }];
    }
    
    if ([self.navigationControllers containsObject:navigationController]) {
        [self.navigationControllers removeObject:navigationController];
    }
}

- (BOOL)canPresentURLOnViewController:(UIViewController *)viewController
{
    return ![viewController isKindOfClass:[UIAlertController class]];
}

@end
