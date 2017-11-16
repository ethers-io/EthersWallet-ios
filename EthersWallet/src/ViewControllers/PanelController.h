//
//  NavigationController.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-11-16.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PanelController : UIViewController

@property (nonatomic, readonly) UINavigationBar *navigationBar;

@property (nonatomic, readonly) BOOL focused;

@property (nonatomic, readonly) CGFloat navigationBarHeight;

- (void)didUpdateNavigationBar: (CGFloat)marginTop;

@end
