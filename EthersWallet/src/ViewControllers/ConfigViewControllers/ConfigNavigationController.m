/**
 *  MIT License
 *
 *  Copyright (c) 2017 Richard Moore <me@ricmoo.com>
 *
 *  Permission is hereby granted, free of charge, to any person obtaining
 *  a copy of this software and associated documentation files (the
 *  "Software"), to deal in the Software without restriction, including
 *  without limitation the rights to use, copy, modify, merge, publish,
 *  distribute, sublicense, and/or sell copies of the Software, and to
 *  permit persons to whom the Software is furnished to do so, subject to
 *  the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included
 *  in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 *  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

#import "ConfigNavigationController.h"


#import "UIColor+hex.h"

#pragma mark -
#pragma mark - AnimatedTransaction

// This provides a nice transition for View Controllers which have transparent backgrounds

@interface AnimatedTransition : NSObject <UIViewControllerAnimatedTransitioning> {
    UINavigationControllerOperation _operation;
    CGFloat _width;
}
@end


@implementation AnimatedTransition

- (instancetype)initWithOperation: (UINavigationControllerOperation)operation width: (CGFloat)width {
    self = [super init];
    if (self) {
        _operation = operation;
        _width = width;
    }
    return self;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    BOOL push = (_operation == UINavigationControllerOperationPush);
    
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    
    fromViewController.view.alpha = 1.0f;
    fromViewController.view.transform = CGAffineTransformIdentity;
    fromViewController.view.userInteractionEnabled = NO;
    
    toViewController.view.alpha = 0.0f;
    toViewController.view.transform = CGAffineTransformMakeTranslation((push ? _width: -_width / 3.0f), 0.0f);
    toViewController.view.userInteractionEnabled = NO;
    
    [transitionContext.containerView addSubview:toViewController.view];
    
    void (^animations)() = ^() {
        fromViewController.view.alpha = 0.0f;
        fromViewController.view.transform = CGAffineTransformMakeTranslation((push ? -_width / 3.0f: _width), 0.0f);
        
        toViewController.view.alpha = 1.0f;
        toViewController.view.transform = CGAffineTransformIdentity;
    };
    
    void (^animationsComplete)(BOOL) = ^(BOOL complete) {
        toViewController.view.userInteractionEnabled = YES;
        fromViewController.view.transform = CGAffineTransformIdentity;
        [transitionContext completeTransition:YES];
    };
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:animations
                     completion:animationsComplete];
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.3f;
}

@end


#pragma mark -
#pragma mark - ConfigNavigationController

@interface ConfigNavigationController () <UINavigationControllerDelegate>

@end


@implementation ConfigNavigationController

+ (instancetype)configNavigationController: (ConfigController*)rootViewController {
    return [[self alloc] initWithRootViewController:rootViewController];
}

- (instancetype)initWithRootViewController: (ConfigController*)rootViewController {
    
    self = [super initWithRootViewController:rootViewController];
    if (self) {
        
        self.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationBar.tintColor = [UIColor colorWithHex:0x5ca2fe];
        
        self.delegate = self;
        
        rootViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                            target:self
                                                                                                            action:@selector(dismissWithNil)];
    }
    return self;
}


- (void)loadView {
    [super loadView];

    // Add the background to the navigation
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    visualEffectView.frame = self.view.bounds;
    visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:visualEffectView atIndex:0];
}


- (void)pushViewController: (ConfigController*)viewController animated:(BOOL)animated {
    ConfigController *top = (ConfigController*)(self.topViewController);
    
    if ([top isKindOfClass:[ConfigController class]] && top.step && [viewController isKindOfClass:[ConfigController class]]) {
        [viewController setStep:top.step + 1 totalSteps:top.totalSteps];
    }
    
    [super pushViewController:viewController animated:animated];
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    
    if (![toVC isKindOfClass:[ConfigController class]] || ![fromVC isKindOfClass:[ConfigController class]]) {
        return nil;
    }
    
    switch (operation) {
        case UINavigationControllerOperationPush:
        case UINavigationControllerOperationPop:
            return [[AnimatedTransition alloc] initWithOperation:operation width:self.view.frame.size.width];
        case UINavigationControllerOperationNone:
        default:
            break;
    }
    return nil;
}

- (void)dismissWithNil {
    [self dismissWithResult:nil];
}

- (void)dismissWithResult:(NSObject *)result {
    __weak ConfigNavigationController *weakSelf = self;
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^() {
        if (weakSelf.onDismiss) {
            weakSelf.onDismiss(result);
        }
        
        // Warn if the dismiss left any view controllers living
        [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer *timer) {
            if (weakSelf) {
                NSLog(@"WARNING: ConfigNavigationController did not release - %@", weakSelf);
            }
        }];
    }];
}

@end
