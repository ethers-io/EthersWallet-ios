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

/**
 *  Wallet
 *
 *  This is the entire encapsulation of the Ethereum Wallet. No private keys
 *  exist or accessible outside this class. The ModalViewController class is
 *  used extensively to interact with the user.
 *
 *  User Interactions
 *    - Approve signing (and sending) transactions
 *    - Adding or removing accounts
 *    - Viewing account backup mnemonic phrases
 *    - Setting user settings
 */

#import <Foundation/Foundation.h>

#import <ethers/Address.h>
#import <ethers/BigNumber.h>
#import <ethers/Payment.h>
#import <ethers/Provider.h>
#import <ethers/Transaction.h>
#import <ethers/TransactionInfo.h>


typedef NSUInteger AccountIndex;

#define AccountNotFound          NSIntegerMax


#pragma mark - Notifications

extern const NSNotificationName WalletAccountAddedNotification;
extern const NSNotificationName WalletAccountRemovedNotification;
extern const NSNotificationName WalletAccountsReorderedNotification;

// Nickname of any account changes
extern const NSNotificationName WalletAccountNicknameDidChangeNotification;

// If the balance for any account changes
extern const NSNotificationName WalletAccountBalanceDidChangeNotification;

// If the active account transactions change (including confirmation count)
extern const NSNotificationName WalletTransactionDidChangeNotification;
extern const NSNotificationName WalletAccountHistoryUpdatedNotification;

extern const NSNotificationName WalletActiveAccountDidChangeNotification;

extern const NSNotificationName WalletDidSyncNotification;


#pragma mark - Notification Keys

extern const NSString* WalletNotificationAddressKey;
extern const NSString* WalletNotificationProviderKey;
extern const NSString* WalletNotificationIndexKey;

extern const NSString* WalletNotificationNicknameKey;

extern const NSString* WalletNotificationBalanceKey;
extern const NSString* WalletNotificationTransactionKey;

extern const NSString* WalletNotificationSyncDateKey;


#pragma mark - Errors

extern NSErrorDomain WalletErrorDomain;

typedef enum WalletError {
    WalletErrorNetwork                   =  -1,
    WalletErrorUnknown                   =  -5,
    WalletErrorSendCancelled             = -11,
    WalletErrorSendInsufficientFunds     = -12,
    WalletErrorNoAccount                 = -40,
} WalletError;


#pragma mark - Wallet

@interface Wallet : NSObject

+ (instancetype)walletWithKeychainKey: (NSString*)keychainKey;

@property (nonatomic, readonly) NSString *keychainKey;

@property (nonatomic, readonly) NSTimeInterval syncDate;

@property (nonatomic, readonly) float etherPrice;

- (void)refresh: (void (^)(BOOL))callback;


#pragma mark - Accounts

@property (nonatomic, assign) AccountIndex activeAccountIndex;

@property (nonatomic, readonly) Address *activeAccountAddress;
@property (nonatomic, readonly) Provider *activeAccountProvider;

@property (nonatomic, assign) NSUInteger activeAccountBlockNumber;


@property (nonatomic, readonly) NSUInteger numberOfAccounts;

- (Address*)addressForIndex: (AccountIndex)index;
- (BigNumber*)balanceForIndex: (AccountIndex)index;
- (ChainId)chainIdForIndex: (AccountIndex)index;
- (NSString*)nicknameForIndex: (AccountIndex)index;
- (void)setNickname: (NSString*)nickname forIndex: (AccountIndex)index;
- (NSArray<TransactionInfo*>*)transactionHistoryForIndex: (AccountIndex)index;

- (void)moveAccountAtIndex: (NSUInteger)fromIndex toIndex: (NSUInteger)toIndex;


#pragma mark - Account Management (Modal UI)

- (void)addAccountCallback: (void (^)(Address *address))callback;
- (void)manageAccountAtIndex: (AccountIndex)index callback: (void (^)())callback;


#pragma mark - Transactions (Modal UI)

- (void)scan: (void (^)(Transaction*, NSError*))callback;

- (void)sendPayment: (Payment*)payment callback: (void (^)(Transaction*, NSError*))callback;
- (void)sendTransaction: (Transaction*)transaction callback:(void (^)(Transaction*, NSError*))callback;


#pragma mark - Debug (Modal UI)

- (void)showDebuggingOptionsCallback: (void (^)())callback;


#pragma mark - Debugging Options

@property (nonatomic, assign) BOOL testnetEnabled;
- (void)purgeCacheData;


@end
