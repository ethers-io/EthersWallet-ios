//
//  NavigationController.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-11-16.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "PanelController.h"
#import "UIColor+hex.h"
#import "Utilities.h"

@interface PanelController ()

@end

@implementation PanelController {
    UIView *_navigationBarBackground;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        static UIImage *blank = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            blank = [[UIImage alloc] init];
        });
        
        _navigationBarHeight = -1.0f;
        
        _navigationBarBackground = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 64.0f)];

        {
            // Adjusted for panel view clouds background
            UIColor *navigationBarColor = [UIColor colorWithHex:0x3f83e4];
            _navigationBarBackground.backgroundColor = navigationBarColor;
            
            /*
             Does not match Panel view well b/c of white background
            UIView *color = [[UIView alloc] initWithFrame:_navigationBarBackground.bounds];
            color.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            color.backgroundColor = navigationBarColor;
            [_navigationBarBackground addSubview:color];

            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
            blur.frame = _navigationBarBackground.bounds;
            blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_navigationBarBackground addSubview:blur];
             */
            
            /*
             UIToolbar does not animate frame
            UIToolbar *blur = [[UIToolbar alloc] initWithFrame:_navigationBarBackground.bounds];
            blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            blur.barTintColor = navigationBarColor;
            [_navigationBarBackground addSubview:blur];
            */
        }
        
        _navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0f, 20.0f, 320.0f, 44.0f)];
        _navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [_navigationBar setBackgroundImage:blank forBarMetrics:UIBarMetricsDefault];
        _navigationBar.items = @[ self.navigationItem ];
        
        [_navigationBarBackground addSubview:_navigationBar];
        

        __weak PanelController *weakSelf = self;
        [NSTimer scheduledTimerWithTimeInterval:5.0f repeats:YES block:^(NSTimer *timer) {
            if (!weakSelf) {
                [timer invalidate];
                return;
            }
            
            [weakSelf _didUpdateNavigationBar];
        }];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [self.view addSubview:_navigationBarBackground];
}

- (void)setFocused:(BOOL)focused animated: (BOOL)animated {
    _focused = focused;

    void (^animate)() = ^() {
        [self _didUpdateNavigationBar];
    };

    if (animated) {
        if (focused) {
            [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:animate completion:nil];
        } else {
            [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseOut animations:animate completion:nil];
        }
    } else {
        animate();
    }
}

- (void)_didUpdateNavigationBar {
    if (![self isViewLoaded]) { return; }

    CGFloat height = 44.0f;
    if (_focused) {
        height += [UIApplication sharedApplication].statusBarFrame.size.height;
    }

    NSLog(@"Focused: %d %f", _focused, height);

    if (_navigationBarBackground.frame.size.height == height) {
        NSLog(@"No change");
        return;
    }

    [self didUpdateNavigationBar:height];
}

- (void)didUpdateNavigationBar: (CGFloat)marginTop {
    NSLog(@"didUpdate: %f", marginTop);
    _navigationBarBackground.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, marginTop);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view bringSubviewToFront:_navigationBarBackground];
    NSLog(@"ViewWillAppear: %@", self.view.subviews);
    [self _didUpdateNavigationBar];
}

@end
