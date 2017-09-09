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

extern const NSNotificationName SignerSyncDateDidChangeNotification;


#pragma mark - Notification Keys

extern const NSString* SignerNotificationNicknameKey;
extern const NSString* SignerNotificationFormerNicknameKey;

extern const NSString* SignerNotificationBalanceKey;
extern const NSString* SignerNotificationFormerBalanceKey;

extern const NSString* SignerNotificationTransactionKey;

extern const NSString* SignerNotificationSyncDateKey;

#pragma mark - Errors

extern NSErrorDomain SignerErrorDomain;

typedef enum SignerError {
    SignerErrorNotImplemented                 = -1,
    SignerErrorUnsupported                    = -2,
    SignerErrorCancelled                      = -10,
    
    SignerErrorAccountLocked                  = -40,

    SignerErrorFailed                         = -50,
    
} SignerError;

#pragma mark - Signer

@interface Signer : NSObject

- (instancetype)initWithCacheKey: (NSString*)cacheKey address: (Address*)address provider: (Provider*)provider;

@property (nonatomic, readonly) NSString *cacheKey;
@property (nonatomic, assign) NSUInteger accountIndex;
@property (nonatomic, copy) NSString *nickname;

@property (nonatomic, readonly) Address *address;

@property (nonatomic, readonly) Provider *provider;



#pragma Blockchain Data

// This purges cached blockchain data, for example, when switching networks
- (void)purgeCachedData;

@property (nonatomic, readonly) BigNumber *balance;
@property (nonatomic, readonly) NSUInteger transactionCount;
@property (nonatomic, readonly) BOOL truncatedTransactionHistory;
@property (nonatomic, readonly) NSArray<TransactionInfo*> *transactionHistory;

@property (nonatomic, readonly) NSUInteger blockNumber;

@property (nonatomic, readonly) NSTimeInterval syncDate;

- (void)refresh: (void (^)(BOOL))callback;

#pragma mark - Signing

// Biometric-Based Unlocking
//  - A wallet only supports fingerprints if the password has previously been entered
@property (nonatomic, readonly) BOOL supportsBiometricUnlock;
- (void)unlockBiometricCallback: (void (^)(Signer*, NSError*))callback;

// Password-Based Unlocking
//   - Watch-only wallets (just an address) do not have passwords
//   - Various hardware wallets may manage their own password requirements
//   - Firefly hardware wallets require a password to decrypt the Firefly private key
//   - Secret Storage JSON wallets require a password to unlock them
@property (nonatomic, readonly) BOOL supportsPasswordUnlock;
- (void)unlockPassword: (NSString*)password callback: (void (^)(Signer*, NSError*))callback;


// Send
//  - Watch-only wallets (just an address) cannot sign
//  - Signing on Firefly hardware wallets opens a BLECast controller and a QR code scanner
//  - Secret Storage JSON wallets support signing with unlocked signers
//@property (nonatomic, readonly) BOOL supportsSign;

- (void)send: (Transaction*)transaction callback: (void (^)(Transaction*, NSError*))callback;


// Mnemonic Phrase
//   - Watch-only wallets (just an address) do not have (known) mnemonic phrases
//   - Secret storage JSON wallets created by ethers do
@property (nonatomic, readonly) BOOL supportsMnemonicPhrase;

// This is only available if the signer is unlocked and supports mnemonic phrases
@property (nonatomic, readonly) NSString *mnemonicPhrase;


@property (nonatomic, readonly) BOOL unlocked;

// Lock and cancel any in-flight unlock
- (void)lock;

// Cancel any unlock in progress
- (void)cancelUnlock;


#pragma mark - Subclass support functions

// Sub-classes can use these to update the cached state
- (void)addTransaction: (Transaction*)transaction;

- (NSString*)dataStoreValueForKey: (NSString*)key;
- (void)setDataStoreValue: (NSString*)value forKey: (NSString*)key;


@end
