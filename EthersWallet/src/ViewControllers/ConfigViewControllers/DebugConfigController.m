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

#import "DebugConfigController.h"

#import "ConfigNavigationController.h"
#import "Utilities.h"

@implementation DebugConfigController

+ (instancetype)configWithWallet:(Wallet *)wallet {
    return [[DebugConfigController  alloc] initWithWallet:wallet];
}

- (instancetype)initWithWallet:(Wallet*)wallet {
    self = [super init];
    if (self) {
        _wallet = wallet;
    }
    return self;
}
    
- (void)loadView {
    [super loadView];
    
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.titleView = [Utilities navigationBarLogoTitle];

    __weak DebugConfigController *weakSelf = self;
    
    self.nextTitle = @"Done";
    self.nextEnabled = YES;
    self.onNext = ^(ConfigController *config) {
        [(ConfigNavigationController*)(config.navigationController) dismissWithNil];
    };
    
    [self addGap:44.0f];
    
    [self addHeadingText:@"Debug Options"];
    
    [self addGap:10.0f];
    
    [self addMarkdown:@"This page is for developers working on //Ethereum// projects. If you are here by accident, tap Done." fontSize:15.0f];
    
    [self addFlexibleGap];

    [self addSeparator];
    ConfigToggle *allowTestnets = [self addToggle:@"Enable Testnets"];
    allowTestnets.on = _wallet.testnetEnabled;
    allowTestnets.didChange = ^(ConfigToggle *toggle) {
        weakSelf.wallet.testnetEnabled = toggle.on;
    };
    [self addSeparator];
    [self addNoteText:@"Allow new (created and imported) accounts to be optionally attached to a testnet."];

    [self addFlexibleGap];

    [self addFlexibleGap];
    
    [self addButton:@"Purge Cached Data" action:^(UIButton *button) {
        [weakSelf.wallet purgeCacheData];
        [weakSelf.wallet refresh:nil];
    }];
    
    [self addGap:44.0f];

    /**
     *  Other things to add here one day:
     *  - Rinkeby Network (requires changing the Provider API)
     *  - Custom nodes (Add name, chain ID and custom node)
     *  - Light Client toggle
     *  - Debuggin console to assist CS contacts (without revealing data)
     */
    
}
@end
