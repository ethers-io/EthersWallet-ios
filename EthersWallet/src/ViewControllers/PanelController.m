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
    CGFloat _bottomMargin, _topMargin;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        static UIImage *blank = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            blank = [[UIImage alloc] init];
        });

        _navigationBarBackground = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 64.0f)];

        // Adjusted for panel view clouds background
        UIColor *navigationBarColor = [UIColor colorWithHex:0x3f83e4];
        _navigationBarBackground.backgroundColor = navigationBarColor;
        
        _navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0f, 20.0f, 320.0f, 44.0f)];
        _navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [_navigationBar setBackgroundImage:blank forBarMetrics:UIBarMetricsDefault];
        _navigationBar.items = @[ self.navigationItem ];
        
        [_navigationBarBackground addSubview:_navigationBar];
    }
        
    return self;
}

- (void)loadView {
    [super loadView];
    [self.view addSubview:_navigationBarBackground];
}

- (void)updateTopMargin:(CGFloat)topMargin bottomMargin:(CGFloat)bottomMargin {
    NSLog(@"Update Panel: %f %f %d", topMargin, bottomMargin, [self isViewLoaded]);
    _bottomMargin = bottomMargin;
    _topMargin = topMargin;
    if (![self isViewLoaded]) { return; }
    _navigationBarBackground.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, topMargin + 44.0f);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view bringSubviewToFront:_navigationBarBackground];
    _navigationBarBackground.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, _topMargin + 44.0f);
}

@end
