//
//  Signer.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-05-03.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ethers/Address.h>
#import <ethers/Provider.h>
#import <ethers/Transaction.h>


#pragma mark - Notifications

extern const NSNotificationName SignerRemovedNotification;

extern const NSNotificationName SignerNicknameDidChangeNotification;

extern const NSNotificationName SignerBalanceDidChangeNotification;
extern const NSNotificationName SignerHistoryUpdatedNotification;
extern const NSNotificationName SignerTransactionDidChangeNotification;


#pragma mark - Notification Keys

//extern const NSString* SignerNotificationSignerKey;

extern const NSString* SignerNotificationNicknameKey;
extern const NSString* SignerNotificationFormerNicknameKey;

extern const NSString* SignerNotificationBalanceKey;
extern const NSString* SignerNotificationFormerBalanceKey;

extern const NSString* SignerNotificationTransactionKey;


#pragma mark - Signer

@interface Signer : NSObject

- (instancetype)initWithCacheKey: (NSString*)cacheKey address: (Address*)address provider: (Provider*)provider;

@property (nonatomic, readonly) NSString *cacheKey;
@property (nonatomic, assign) NSUInteger accountIndex;
@property (nonatomic, copy) NSString *nickname;

@property (nonatomic, readonly) Address *address;

@property (nonatomic, readonly) Provider *provider;

@property (nonatomic, readonly) NSUInteger blockNumber;

#pragma Blockchain Data

// This purges cached blockchain data, for example, when switching networks
- (void)purgeCachedData;

@property (nonatomic, readonly) BigNumber *balance;
@property (nonatomic, readonly) NSUInteger transactionCount;
@property (nonatomic, readonly) BOOL truncatedTransactionHistory;
@property (nonatomic, readonly) NSArray<TransactionInfo*> *transactionHistory;



// Fingerprint
//  - A wallet only supports fingerprints if the password has previously been entered
@property (nonatomic, readonly) BOOL supportsFingerprintUnlock;
- (void)fingerprintUnlockCallback: (void (^)(Signer*, NSError*))callback;


// Signing
//  - Watch-only wallets (just an address) cannot sign
//  - Signing on Firefly hardware wallets opens a BLECast controller and a QR code scanner
//  - Secret Storage JSON wallets support signing with unlocked signers
@property (nonatomic, readonly) BOOL supportsSign;
//- (void)sign: (Transaction*)transaction callback: (void (^)(Transaction*, NSError*))callback;;

- (void)send: (Transaction*)transaction callback: (void (^)(Transaction*, NSError*))callback;

// Passwords
//   - Watch-only wallets (just an address) do not have passwords
//   - Various hardware wallets may manage their own password requirements
//   - Firefly hardware wallets require a password to decrypt the Firefly private key
//   - Secret Storage JSON wallets require a password to unlock them
@property (nonatomic, readonly) BOOL hasPassword;
@property (nonatomic, readonly) BOOL unlocked;

// Mnemonic Phrase
//   - Watch-only wallets (just an address) do not have (known) mnemonic phrases
//   - Secret storage JSON wallets created by ethers do
@property (nonatomic, readonly) BOOL supportsMnemonicPhrase;

// This is only available if the signer is unlocked
@property (nonatomic, readonly) NSString *mnemonicPhrase;

- (void)lock;
- (void)cancelUnlock;
- (void)unlock: (NSString*)password callback: (void (^)(Signer*, NSError*))callback;

@end
