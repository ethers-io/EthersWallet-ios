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

#import "FireflyConfigController.h"

#import "ConfigNavigationController.h"
#import "Utilities.h"


@implementation FireflyConfigController

+ (instancetype)configWithWallet:(Wallet *)wallet {
    return [[FireflyConfigController  alloc] initWithWallet:wallet];
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
    self.navigationItem.title = @"Firefly";
    
    __weak FireflyConfigController *weakSelf = self;
    
    self.nextTitle = @"Done";
    self.nextEnabled = YES;
    self.onNext = ^(ConfigController *config) {
        [(ConfigNavigationController*)(config.navigationController) dismissWithNil];
    };
    
    [self addFlexibleGap];
    
    [self addText:ICON_LOGO_FIREFLY font:[UIFont fontWithName:FONT_ETHERS size:100.0f]];
    
    [self addGap:10.0f];
    
    [self addMarkdown:@"The Firefly Hardware Wallet is still an **experimental** product and is in a very early stage of development."
             fontSize:15.0f];
    
    [self addMarkdown:@"Please do **NOT** use it for large amounts of ether and consider using a testnet instead of mainnet." fontSize:15.0f];
    
    [self addMarkdown:@"The v0 protocol stores the private key **unencrypted** on the Firefly which could be recovered using standard developer tools." fontSize:15.0f];

    [self addFlexibleGap];
    
    [self addSeparator];
    ConfigToggle *allowFirefly = [self addToggle:@"Enable Firefly"];
    allowFirefly.on = _wallet.fireflyEnabled;
    allowFirefly.didChange = ^(ConfigToggle *toggle) {
        weakSelf.wallet.fireflyEnabled = toggle.on;
    };
    [self addSeparator];
    [self addNoteText:@"Allow new Firefly Hardware Wallets (v0) to be paired and added as accounts."];
    
    [self addFlexibleGap];
    
    [self addGap:44.0f];
}

@end
