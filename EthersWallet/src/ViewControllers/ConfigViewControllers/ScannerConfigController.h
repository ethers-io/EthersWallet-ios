//
//  ScannerConfigController.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-08-23.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "ConfigController.h"

#import "Signer.h"

@interface ScannerConfigController : ConfigController

+ (instancetype)configWithSigner: (Signer*)signer;

@property (nonatomic, readonly) Signer *signer;


- (void)startScanningAnimated:(BOOL)animated;

@property (nonatomic, readonly) NSString *foundName;
@property (nonatomic, readonly) Address *foundAddress;
@property (nonatomic, readonly) BigNumber *foundAmount;

@end
