//
//  FireflyDoneConfigController.m
//  EthersWallet
//
//  Created by Richard Moore on 2018-01-19.
//  Copyright © 2018 ethers.io. All rights reserved.
//

#import "FireflyDoneConfigController.h"

#import "Utilities.h"


@interface FireflyDoneConfigController ()

@end

@implementation FireflyDoneConfigController

+ (instancetype)configWithSigner:(FireflySigner *)fireflySigner {
    return [[FireflyDoneConfigController alloc] initWithSigner:fireflySigner];
}

- (instancetype)initWithSigner: (FireflySigner*)fireflySigner {
    self = [super init];
    if (self) {
        _signer = fireflySigner;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    self.navigationItem.hidesBackButton = YES;
    self.nextTitle = @"I Agree";
    self.nextEnabled = YES;
    self.navigationItem.title = @"Firefly Paired";
    
    [self addFlexibleGap];
    
    [self addText:ICON_LOGO_FIREFLY font:[UIFont fontWithName:FONT_ETHERS size:100.0f]];
    [self addText:@"Version 0" fontSize:14.0f];

    [self addFlexibleGap];
    
    [self addMarkdown:@"The Firefly Hardware Wallet is still an **experimental** product and is in a very early stage of development."
             fontSize:15.0f];
    
    [self addMarkdown:@"Please do **NOT** use it for large amounts of ether and consider using a testnet instead of mainnet." fontSize:15.0f];
    
    [self addMarkdown:@"The v0 protocol stores the private key **unencrypted** on the Firefly which could be recovered using standard developer tools." fontSize:15.0f];

    [self addFlexibleGap];

    [self addGap:44.0f];
}

@end
