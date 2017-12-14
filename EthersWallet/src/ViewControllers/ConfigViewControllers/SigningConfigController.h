//
//  SigningConfigController.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-12-12.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "ConfigController.h"

#import "Signer.h"

@interface SigningConfigController : ConfigController

+ (instancetype)configWithSigner: (Signer*)signer message: (NSData*)message;

@property (nonatomic, readonly) Signer *signer;
@property (nonatomic, readonly) NSData *message;

@property (nonatomic, copy) void (^onSign)(SigningConfigController*, Signature*);

@end
