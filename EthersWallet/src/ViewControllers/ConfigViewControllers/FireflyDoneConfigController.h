//
//  FireflyDoneConfigController.h
//  EthersWallet
//
//  Created by Richard Moore on 2018-01-19.
//  Copyright © 2018 ethers.io. All rights reserved.
//

#import "ConfigController.h"

#import "FireflySigner.h"

@interface FireflyDoneConfigController : ConfigController

+ (instancetype)configWithSigner: (FireflySigner*)fireflySigner;

@property (nonatomic, readonly) FireflySigner *signer;

@end
