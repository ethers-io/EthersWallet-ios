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

#import "ModalViewController.h"

#import "AsyncOperation.h"


@interface ModalViewController ()

@property (nonatomic, strong) UIWindow *window;

@property (nonatomic, copy) void (^viewControllerReady)();

@end


@implementation ModalViewController

static NSMutableArray<ModalViewController*> *ModalViewControllers = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ModalViewControllers = [NSMutableArray arrayWithCapacity:1];
    });
}

+ (ModalViewController*)presentViewController: (UIViewController*)viewController animated: (BOOL)animated completion: (void (^)())completion {
    ModalViewController *presentingViewController = [[ModalViewController alloc] initWithNibName:nil bundle:nil];

    // Set this up before making the window visible
    __weak ModalViewController *weakPresentingViewController = presentingViewController;
    presentingViewController.viewControllerReady = ^() {
        [weakPresentingViewController presentViewController:viewController animated:animated completion:completion];
    };

    // Create our temporary window for this modal view controller
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.rootViewController = presentingViewController;
    [window makeKeyAndVisible];

    // Retain the window so it doesn't die
    presentingViewController.window = window;
    
    // Track this modal view controller for dismissAll
    [ModalViewControllers addObject:presentingViewController];
    
    return presentingViewController;
}

+ (void)dismissAll {
    [self dismissAllCompletionCallback:nil];
}

+ (void)dismissAllCompletionCallback:(void (^)())completionCallback {
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    
    while ([ModalViewControllers count]) {
        AsyncOperation *asyncOperation = [AsyncOperation asyncOperationWithSetup:^(AsyncOperation *asyncOperation) {}];
        [operationQueue addOperation:asyncOperation];
        
        [[ModalViewControllers lastObject] dismissViewControllerAnimated:NO completion:^() {
            [asyncOperation done:nil];
        }];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        [operationQueue waitUntilAllOperationsAreFinished];
        if (completionCallback) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                completionCallback();
            });
        }
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_viewControllerReady) {
        _viewControllerReady();
        _viewControllerReady = nil;
    }
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    [ModalViewControllers removeObject:self];

    __weak ModalViewController *weakSelf = self;
    void (^completionCallback)() = ^() {
        
        // Release our hold on the window so it can die in peace
        weakSelf.window = nil;
        
        if (completion) { completion(); }
    };
    
    // If we still have a presented view controller, dismiss it first (some things
    // like the UIActivityViewControll remove themselves for us).
    if (self.presentedViewController) {
        [super dismissViewControllerAnimated:flag completion:completionCallback];
    
    } else {
        completionCallback();
    }
}

@end
