//
//  FireflyPairingConfigController.h
//  EthersWallet
//
//  Created by Richard Moore on 2018-01-17.
//  Copyright © 2018 ethers.io. All rights reserved.
//

#import "ConfigController.h"

#import <ethers/Address.h>

@interface FireflyPairingConfigController : ConfigController

+ (instancetype)config;

@property (nonatomic, copy) void (^didCancel)(FireflyPairingConfigController*);
@property (nonatomic, copy) void (^didDetectFirefly)(FireflyPairingConfigController*, Address *address, NSData *pairKey);

@end
