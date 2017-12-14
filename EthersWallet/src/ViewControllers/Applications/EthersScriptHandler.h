//
//  EthersScriptHandler.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-12-11.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Wallet.h"

@import WebKit;

@class EthersScriptHandler;


@protocol EthersScriptHandlerDelegate <NSObject>

- (void)ethersScriptHandler: (EthersScriptHandler*)ethersScriptHandler evaluateJavaScript: (NSString*)script;

@end


@interface EthersScriptHandler : NSObject <WKScriptMessageHandler>

- (instancetype)initWithName: (NSString*)name wallet: (Wallet*)wallet;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) Wallet *wallet;

@property (nonatomic, weak) NSObject<EthersScriptHandlerDelegate> *delegate;

@end
