//
//  SecretStorageSigner.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-08-12.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import <ethers/Provider.h>
#import "Signer.h"

@interface CloudKeychainSigner : Signer

+ (NSArray<Address*>*)addressesForKeychainKey: (NSString*)keychainKey;

+ (instancetype)writeToKeychain: (NSString*)keychainKey
                       nickname: (NSString*)nickname
                           json: (NSString*)json
                       provider: (Provider*)provider;;

+ (instancetype)signerWithKeychainKey: (NSString*)keychainKey
                              address: (Address*)address
                             provider: (Provider*)provider;

@property (nonatomic, readonly) NSString *keychainKey;

// Account must be unlocked to remove it
- (BOOL)remove;

@end
