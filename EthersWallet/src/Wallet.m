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

#import <UIKit/UIKit.h>

#import "Wallet.h"

// This is useful for testing. It prevents us from having to re-type a mnemonic
// phrase to add or delete an account. This is BAD for production.
//#define DEBUG_SKIP_VERIFY_MNEMONIC

// Minimum length for a valid password
#define MIN_PASSWORD_LENGTH       6


#pragma mark - Service Credentials

#define ETHERSCAN_API_KEY                   @"YTCX255XJGH9SCBUDP2K48S4YWACUEFSJX"


@import LocalAuthentication;

#import <ethers/Account.h>
#import <ethers/EtherscanProvider.h>
#import <ethers/FallbackProvider.h>
#import <ethers/InfuraProvider.h>
#import <ethers/Payment.h>
#import <ethers/SecureData.h>

#import "ConfigNavigationController.h"
#import "DebugConfigController.h"
#import "DoneConfigController.h"
#import "FireflyConfigController.h"
#import "FireflyDoneConfigController.h"
#import "FireflyPairingConfigController.h"
#import "GasPriceKeyboardView.h"
#import "MnemonicWarningConfigController.h"
#import "MnemonicConfigController.h"
#import "OptionsConfigController.h"
#import "PasswordConfigController.h"
#import "ScannerConfigController.h"
#import "SigningConfigController.h"
#import "TransactionConfigController.h"

#import "CachedDataStore.h"
#import "CloudKeychainSigner.h"
#import "FireflySigner.h"
#import "ModalViewController.h"
#import "UIColor+hex.h"
#import "Utilities.h"


#pragma mark - Error Domain

NSErrorDomain WalletErrorDomain = @"WalletErrorDomain";


#pragma mark - Notifications

const NSNotificationName WalletAccountAddedNotification                  = @"WalletAccountAddedNotification";
const NSNotificationName WalletAccountRemovedNotification                = @"WalletAccountRemovedNotification";
const NSNotificationName WalletAccountsReorderedNotification             = @"WalletAccountsReorderedNotification";
const NSNotificationName WalletAccountNicknameDidChangeNotification      = @"WalletAccountNicknameDidChangeNotification";

const NSNotificationName WalletAccountBalanceDidChangeNotification       = @"WalletAccountBalanceDidChangeNotification";

const NSNotificationName WalletTransactionDidChangeNotification          = @"WalletTransactionDidChangeNotification";
const NSNotificationName WalletAccountHistoryUpdatedNotification         = @"WalletAccountHistoryUpdatedNotification";

const NSNotificationName WalletActiveAccountDidChangeNotification        = @"WalletActiveAccountDidChangeNotification";

const NSNotificationName WalletDidSyncNotification                       = @"WalletDidSyncNotification";

const NSNotificationName WalletNetworkDidChange                          = @"WalletNetworkDidChange";


#pragma mark - Notification Keys

const NSString* WalletNotificationIndexKey                               = @"WalletNotificationIndexKey";

const NSString* WalletNotificationAddressKey                             = @"WalletNotificationAddressKey";
const NSString* WalletNotificationProviderKey                            = @"WalletNotificationProviderKey";

const NSString* WalletNotificationNicknameKey                            = @"WalletNotificationNicknameKey";

const NSString* WalletNotificationBalanceKey                             = @"WalletNotificationBalanceKey";
const NSString* WalletNotificationTransactionKey                         = @"WalletNotificationTransactionKey";

const NSString* WalletNotificationSyncDateKey                            = @"WalletNotificationSyncDateKey";



#pragma mark - Data Store keys

static NSString *DataStoreKeyEtherPrice                   = @"ETHER_PRICE";

static NSString *DataStoreKeyEnableFirefly                = @"DEBUG_ENABLE_FIREFLY";
static NSString *DataStoreKeyEnableTestnet                = @"DEBUG_ENABLE_TESTNET";

static NSString *DataStoreKeyActiveAccountAddress         = @"ACTIVE_ACCOUNT_ADDRESS";
static NSString *DataStoreKeyActiveAccountChainId         = @"ACTIVE_ACCOUNT_CHAINID";







#pragma mark - Wallet Life-Cycle

@implementation Wallet {
    
    // Maps chainId => Provider
    NSMutableDictionary<NSNumber*, Provider*> *_providers;
    
    // Ordered list of all Signers
    NSMutableArray<Signer*> *_accounts;

    // Storage for application values (NSUserDefaults seems to be flakey; lots of failed writes)
    CachedDataStore *_dataStore;
    
    // Blockchain Data
    BOOL _firstRefreshDone;
    
    IntegerPromise *_refreshPromise;
    
    NSTimer *_refreshKeychainTimer;
}


+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#ifdef DEBUG_SKIP_VERIFY_MNEMONIC
#warning DEBUGGING ENABLED - SKIP VERIFIY MNEMONIC - DO NOT RELASE
            NSLog(@"");
            NSLog(@"**********************************************************");
            NSLog(@"**********************************************************");
            NSLog(@"**********************************************************");
            NSLog(@"**********************************************************");
            NSLog(@"");
            NSLog(@"WARNING! Mnemonic Verify Skipping Enabled - Do NOT release");
            NSLog(@"");
            NSLog(@"**********************************************************");
            NSLog(@"**********************************************************");
            NSLog(@"**********************************************************");
            NSLog(@"**********************************************************");
            NSLog(@"");
#endif
    });
}

+ (instancetype)walletWithKeychainKey:(NSString *)keychainKey {
    return [[Wallet alloc] initWithKeychainKey:keychainKey];
}

- (instancetype)initWithKeychainKey: (NSString*)keychainKey {
    
    self = [super init];
    if (self) {
        
        _keychainKey = keychainKey;
        _dataStore = [CachedDataStore sharedCachedDataStoreWithKey:[@"wallet-" stringByAppendingString:keychainKey]];

        _providers = [NSMutableDictionary dictionary];

        // Start up a mainnet provider to make sure we get ether fiat prices
        [self getProvider:ChainIdHomestead];

        _activeAccountIndex = AccountNotFound;
        [self reloadSigners];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notifyApplicationActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        __weak Wallet *weakSelf = self;
        [NSTimer scheduledTimerWithTimeInterval:4.0f repeats:YES block:^(NSTimer *timer) {
            if (!weakSelf) {
                [timer invalidate];
                return;
            }
            [weakSelf checkForNewAccountsChainId:ChainIdHomestead];
            [weakSelf checkForNewAccountsChainId:ChainIdRopsten];
            [weakSelf checkForNewAccountsChainId:ChainIdRinkeby];
            [weakSelf checkForNewAccountsChainId:ChainIdKovan];
        }];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_refreshKeychainTimer invalidate];
    _refreshKeychainTimer = nil;
}


#pragma mark - Keychain Account Management



- (void)saveAccountOrder {
    NSInteger index = 0;
    for (Signer *signer in _accounts) {
        signer.accountIndex = index++;
    }
}

- (AccountIndex)indexForAddress: (Address*)address chainId: (ChainId)chainId {
    for (NSUInteger i = 0; i < _accounts.count; i++) {
        Signer *signer = [_accounts objectAtIndex:i];
        if ([signer.address isEqualToAddress:address] && signer.provider.chainId == chainId) {
            return i;
        }
    }
    
    return AccountNotFound;
}

#pragma mark - Providers

- (Provider*)getProvider: (ChainId)chainId {
    NSNumber *key = [NSNumber numberWithInteger:chainId];
    
    Provider *provider = [_providers objectForKey:key];
    
    if (!provider) {
        
        // Prepare a new provider
        FallbackProvider *fallbackProvider = [[FallbackProvider alloc] initWithChainId:chainId];
        provider = fallbackProvider;
        
        // Add INFURA and Etherscan unless explicitly disabled
        [fallbackProvider addProvider:[[InfuraProvider alloc] initWithChainId:chainId]];
        [fallbackProvider addProvider:[[EtherscanProvider alloc] initWithChainId:chainId apiKey:ETHERSCAN_API_KEY]];
    
        [provider startPolling];

        if (chainId == ChainIdHomestead) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(notifyEtherPriceChanged:)
                                                         name:ProviderEtherPriceChangedNotification
                                                       object:provider];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notifyBlockNumber:)
                                                     name:ProviderDidReceiveNewBlockNotification
                                                   object:provider];

        [_providers setObject:provider forKey:key];
    }
    
    return provider;
}

- (void)purgeCacheData {
    for (Signer *signer in _accounts) {
        [signer purgeCachedData];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        NSDictionary *userInfo = @{ WalletNotificationSyncDateKey: @(0) };
        [self doNotify:WalletDidSyncNotification signer:nil userInfo:userInfo transform:nil];
    });
}

- (void)addSignerNotifications: (Signer*)signer {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifySignerBalanceDidChange:)
                                                 name:SignerBalanceDidChangeNotification
                                               object:signer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifySignerNicknameDidChange:)
                                                 name:SignerNicknameDidChangeNotification
                                               object:signer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifySignerDidSync:)
                                                 name:SignerSyncDateDidChangeNotification
                                               object:signer];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifySignerHistoryUpdated:)
                                                 name:SignerHistoryUpdatedNotification
                                               object:signer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifySignerRemovedNotification:)
                                                 name:SignerRemovedNotification
                                               object:signer];
    
}

- (void)addCloudKeychainSigners: (NSString*)keychainKey chainId: (ChainId)chainId {
    for (Address *address in [CloudKeychainSigner addressesForKeychainKey:keychainKey]) {
        Signer *signer = [CloudKeychainSigner signerWithKeychainKey:keychainKey address:address provider:[self getProvider:chainId]];
        [_accounts addObject:signer];
        [self addSignerNotifications:signer];
    }
}

- (void)addFireflySigners: (NSString*)keychainKey chainId: (ChainId)chainId {
    for (Address *address in [FireflySigner addressesForKeychainKey:keychainKey]) {
        Signer *signer = [FireflySigner signerWithKeychainKey:keychainKey address:address provider:[self getProvider:chainId]];
        [_accounts addObject:signer];
        [self addSignerNotifications:signer];
    }
}

- (void)checkForNewAccountsChainId: (ChainId)chainId {
    NSMutableSet *accounts = [NSMutableSet set];
    for (Signer *signer in _accounts) {
        if (signer.provider.chainId == chainId) {
            [accounts addObject:signer.address];
        }
    }
    
    NSMutableSet *newAccounts = [NSMutableSet set];
    
    NSString *keychainKey = _keychainKey;
    if (chainId != ChainIdHomestead) {
        keychainKey = [NSString stringWithFormat:@"%@/%@", keychainKey, chainName(chainId)];
    }
    
    for (Address *address in [CloudKeychainSigner addressesForKeychainKey:keychainKey]) {
        if (![accounts containsObject:address]) {
            [newAccounts addObject:address];
        }
    }
    
    // New account! Reload and notify
    if (newAccounts.count) {
        [self reloadSigners];
        
        for (Address *address in newAccounts) {
            AccountIndex index = [self indexForAddress:address chainId:chainId];
            if (index == AccountNotFound) {
                NSLog(@"Huh?! New Account doesn't exist after all??");
                continue;
            }
            
            [self doNotify:WalletAccountAddedNotification signer:[_accounts objectAtIndex:index] userInfo:nil transform:nil];
        }
     }
}

- (void)setActiveAccountAddress: (Address*)address provider: (Provider*)provider {
    AccountIndex accountIndex = [self indexForAddress:address chainId:provider.chainId];
    
    // No matching account, try loading the most recently used account from the data store
    if (accountIndex == AccountNotFound) {
        Address *address = [Address addressWithString:[_dataStore stringForKey:DataStoreKeyActiveAccountAddress]];
        ChainId chainId = [_dataStore integerForKey:DataStoreKeyActiveAccountChainId];
        accountIndex = [self indexForAddress:address chainId:chainId];
    }
    
    // Still no match, use the first account (if it exists)
    if (accountIndex == AccountNotFound && _accounts.count) {
        accountIndex = 0;
    }
    
    [self setActiveAccountIndex:accountIndex];
}

- (void)reloadSigners {
    Address *currentAddress = self.activeAccountAddress;
    Provider *currentProvider = self.activeAccountProvider;
    
    // Unsubscribe to all the old signer objects
    if (_accounts) {
        for (Signer *signer in _accounts) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:signer];
        }
    }
    
    // Remove all existing signers (the provider is no longer valid)
    _accounts = [NSMutableArray array];
    
    [self addCloudKeychainSigners:_keychainKey chainId:ChainIdHomestead];
    [self addCloudKeychainSigners:[_keychainKey stringByAppendingString:@"/ropsten"] chainId:ChainIdRopsten];
    [self addCloudKeychainSigners:[_keychainKey stringByAppendingString:@"/rinkeby"] chainId:ChainIdRinkeby];
    [self addCloudKeychainSigners:[_keychainKey stringByAppendingString:@"/kovan"] chainId:ChainIdKovan];

    [self addFireflySigners:[_keychainKey stringByAppendingString:@"/firefly/homestead"] chainId:ChainIdHomestead];
    [self addFireflySigners:[_keychainKey stringByAppendingString:@"/firefly/ropsten"] chainId:ChainIdRopsten];
    [self addFireflySigners:[_keychainKey stringByAppendingString:@"/firefly/rinkeby"] chainId:ChainIdRinkeby];
    [self addFireflySigners:[_keychainKey stringByAppendingString:@"/firefly/kovan"] chainId:ChainIdKovan];

    // Sort the accounts
    [_accounts sortUsingComparator:^NSComparisonResult(Signer *a, Signer *b) {
        if (a.accountIndex < b.accountIndex) {
            return NSOrderedAscending;
        } else if (a.accountIndex > b.accountIndex) {
            return NSOrderedDescending;
        }
        return [a.address.checksumAddress caseInsensitiveCompare:b.address.checksumAddress];
    }];
    
    NSLog(@"Signers: %@", _accounts);
    
    [self setActiveAccountAddress:currentAddress provider:currentProvider];
    
}

#pragma mark - State

- (void)notifyEtherPriceChanged: (NSNotification*)note {
    float etherPrice = [[note.userInfo objectForKey:@"price"] floatValue];
    if (etherPrice != 0.0f && etherPrice != self.etherPrice) {
        [_dataStore setFloat:etherPrice forKey:DataStoreKeyEtherPrice];
    }
}

- (void)notifyBlockNumber: (NSNotification*)note {
    [self doNotify:WalletTransactionDidChangeNotification signer:nil userInfo:nil transform:nil];
}

- (void)notifyApplicationActive: (NSNotification*)note {
    /*
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer *timer) {
        [self refreshKeychainValues];
    }];
     */
}

- (void)doNotify: (NSNotificationName)notificationName
          signer: (Signer*)signer
        userInfo: (NSDictionary*)userInfo
       transform: (NSDictionary*)transform {
    
    NSMutableDictionary *sendUserInfo = [NSMutableDictionary dictionary];
    
    //Signer *signer = [sendUserInfo objectForKey:SignerNotificationSignerKey];
    if (signer) {
        NSInteger index = [_accounts indexOfObject:signer];
        if (index != NSNotFound) {
            [sendUserInfo setObject:@(index) forKey:WalletNotificationIndexKey];
            [sendUserInfo setObject:signer.address forKey:WalletNotificationAddressKey];
            [sendUserInfo setObject:signer.provider forKey:WalletNotificationProviderKey];
        }
    }
    
    if (transform) {
        for (NSString *key in transform) {
            NSString *value = [userInfo objectForKey:key];
            if (value) {
                [sendUserInfo setObject:value forKey:[transform objectForKey:key]];
            }
        }
    } else if (userInfo) {
        [sendUserInfo addEntriesFromDictionary:userInfo];
    }
    
    __weak Wallet *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:weakSelf userInfo:sendUserInfo];
    });
}

- (void)notifySignerRemovedNotification: (NSNotification*)note {
    [self reloadSigners];
    [self doNotify:WalletAccountRemovedNotification signer:note.object userInfo:note.userInfo transform:@{}];
}

- (void)notifySignerNicknameDidChange: (NSNotification*)note {
    NSDictionary *transform = @{
                                SignerNotificationNicknameKey: WalletNotificationNicknameKey,
                                };
    [self doNotify:WalletAccountNicknameDidChangeNotification signer:note.object userInfo:note.userInfo transform:transform];
}

- (void)notifySignerBalanceDidChange: (NSNotification*)note {
    NSDictionary *transform = @{
                                SignerNotificationBalanceKey: WalletNotificationBalanceKey,
                                };
    [self doNotify:WalletAccountBalanceDidChangeNotification signer:note.object userInfo:note.userInfo transform:transform];
}

- (void)notifySignerHistoryUpdated: (NSNotification*)note {
    [self doNotify:WalletAccountHistoryUpdatedNotification signer:note.object userInfo:note.userInfo transform:nil];
}

- (void)notifySignerDidSync: (NSNotification*)note {
    [self doNotify:WalletDidSyncNotification signer:note.object userInfo:nil transform:nil];
}

- (void)notifySignerTransactionDidChange: (NSNotification*)note {
    NSDictionary *transform = @{
                                SignerNotificationTransactionKey: WalletNotificationTransactionKey,
                                };
    [self doNotify:WalletTransactionDidChangeNotification signer:note.object userInfo:note.userInfo transform:transform];
}


#pragma mark - Accounts

- (NSUInteger)numberOfAccounts {
    return [_accounts count];
}

- (void)moveAccountAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if (fromIndex == toIndex)  { return; }

    Address *currentAddress = self.activeAccountAddress;
    Provider *currentProvider = self.activeAccountProvider;

    Signer *signer = [_accounts objectAtIndex:fromIndex];
    [_accounts removeObjectAtIndex:fromIndex];
    [_accounts insertObject:signer atIndex:toIndex];
    
    [self saveAccountOrder];

    [self setActiveAccountAddress:currentAddress provider:currentProvider];

    [self doNotify:WalletAccountsReorderedNotification signer:nil userInfo:nil transform:nil];
}

- (Address*)addressForIndex: (NSUInteger)index {
    return [_accounts objectAtIndex:index].address;
}

- (BigNumber*)balanceForIndex: (NSUInteger)index {
    return [_accounts objectAtIndex:index].balance;
}

- (ChainId)chainIdForIndex:(AccountIndex)index {
    return [_accounts objectAtIndex:index].provider.chainId;
}

- (NSString*)nicknameForIndex: (NSUInteger)index {
    return [_accounts objectAtIndex:index].nickname;
}

- (void)setNickname: (NSString*)nickname forIndex: (NSUInteger)index {
    [_accounts objectAtIndex:index].nickname = nickname;
}

- (NSArray<TransactionInfo*>*)transactionHistoryForIndex: (NSUInteger)index {
    return [_accounts objectAtIndex:index].transactionHistory;
}

- (Address*)activeAccountAddress {
    if (_activeAccountIndex == AccountNotFound) { return nil; }
    return [self addressForIndex:_activeAccountIndex];
}

- (Provider*)activeAccountProvider {
    if (_activeAccountIndex == AccountNotFound) { return nil; }
    return [_accounts objectAtIndex:_activeAccountIndex].provider;
}

- (NSUInteger)activeAccountBlockNumber {
    if (_activeAccountIndex == AccountNotFound) { return 0; }
    return [_accounts objectAtIndex:_activeAccountIndex].blockNumber;
}

- (void)setActiveAccountIndex:(AccountIndex)activeAccountIndex {
    if (activeAccountIndex == AccountNotFound && _accounts.count) {
        NSLog(@"ERROR: Cannot set activeAccountIndex to NONE");
        return;
    } else if (activeAccountIndex >= _accounts.count) {
        NSLog(@"ERROR: Cannot set activeAccountIndex (%d >= %D)", (int)activeAccountIndex, (int)(_accounts.count));
        return;
    }
    
    Signer *signer = nil;
    if (activeAccountIndex != AccountNotFound) {
        signer = [_accounts objectAtIndex:activeAccountIndex];
    }


    if (signer) {
        [_dataStore setObject:signer.address.checksumAddress forKey:DataStoreKeyActiveAccountAddress];
        [_dataStore setObject:@(signer.provider.chainId) forKey:DataStoreKeyActiveAccountChainId];
    } else {
        [_dataStore setObject:nil forKey:DataStoreKeyActiveAccountAddress];
        [_dataStore setObject:nil forKey:DataStoreKeyActiveAccountChainId];
    }

    NSLog(@"Active Account: %d => %d", (int)_activeAccountIndex, (int)activeAccountIndex);
    
    if (_activeAccountIndex == activeAccountIndex) { return; }

    _activeAccountIndex = activeAccountIndex;

    NSDictionary *userInfo = @{ WalletNotificationIndexKey: @(activeAccountIndex) };
    [self doNotify:WalletActiveAccountDidChangeNotification signer:signer userInfo:userInfo transform:nil];
}


#pragma mark - Account Managment

- (void)addAccountCallback:(void (^)(Address *))callback {

    __weak Wallet *weakSelf = self;
    
    NSArray<NSString*> *messages = @[
                           @"How would you like to add an account?"
                           ];
    
    NSArray<NSString*> *options = nil;
    if (self.fireflyEnabled) {
        options = @[
                    @"Create New Account",
                    @"Import Existing Account",
                    @"Pair Firefly Hardware Wallet",
                    ];

    } else {
        options = @[
                    @"Create New Account",
                    @"Import Existing Account",
                    ];
    }
    
    
    OptionsConfigController *config = [OptionsConfigController configWithHeading:nil subheading:nil messages:messages options:options];

    __block Account *account = nil;
    __block NSString *accountPassword = nil;
    __block ChainId chainId = ChainIdHomestead;
    
    // ***************************
    // STEP 6/5 - Encrypt and return the
    void (^encryptAndFinish)(ConfigController*) = ^(ConfigController *configController) {
        DoneConfigController *config = [DoneConfigController doneWithAccount:account password:accountPassword];
        config.onNext = ^(ConfigController *config) {
            NSString *json = ((DoneConfigController*)config).json;
            Signer *signer = nil;
            
            NSString *keychainKey = weakSelf.keychainKey;
            NSString *nickname = @"ethers.io";
            if (chainId != ChainIdHomestead) {
                keychainKey = [NSString stringWithFormat:@"%@/%@", keychainKey, chainName(chainId)];
                switch (chainId) {
                    case ChainIdKovan:
                        nickname = @"Kovan";
                        break;
                    case ChainIdRinkeby:
                        nickname = @"Rinkeby";
                        break;
                    case ChainIdRopsten:
                        nickname = @"Ropsten";
                        break;
                    default:
                        nickname = @"Testnet";
                        break;
                }
            }
            signer = [CloudKeychainSigner writeToKeychain:keychainKey
                                                 nickname:nickname
                                                     json:json
                                                 provider:[weakSelf getProvider:chainId]];
            
            if (signer) {
                // Make sure account indices are compact
                [weakSelf saveAccountOrder];
                
                // Set the new account's index to the end
                signer.accountIndex = weakSelf.numberOfAccounts;
                
                // Reload signers
                [weakSelf reloadSigners];
                
                [weakSelf doNotify:WalletAccountAddedNotification signer:signer userInfo:nil transform:nil];
                
            } else {
                NSLog(@"Wallet: Error writing signer to Keychain");
            }
            
            [(ConfigNavigationController*)(configController.navigationController) dismissWithResult:signer.address];
        };
        [configController.navigationController pushViewController:config animated:YES];
    };
    
    // ***************************
    // STEP 5/4 - Verify the password
    void (^verifyPassword)(ConfigController*) = ^(ConfigController *configController) {
        NSString *title = @"Confirm Password";
        NSString *message = @"Enter the same password again.";
        
        PasswordConfigController *config = [PasswordConfigController configWithHeading:title message:message note:nil];
        config.nextEnabled = NO;
        config.nextTitle = @"Next";
        config.didChange = ^(PasswordConfigController *config) {
            NSString *password = config.passwordField.textField.text;
            if (password.length == 0) {
                config.passwordField.status = ConfigTextFieldStatusNone;
                config.nextEnabled = NO;
            } else if ([password isEqualToString:accountPassword]) {
                config.passwordField.status = ConfigTextFieldStatusGood;
                config.nextEnabled = YES;
            } else {
                config.passwordField.status = ConfigTextFieldStatusBad;
                config.nextEnabled = NO;
            }
        };
        config.onLoad = ^(ConfigController *config) {
            [((PasswordConfigController*)config).passwordField.textField becomeFirstResponder];
        };
        config.onReturn = ^(PasswordConfigController *config) {
            if (config.passwordField.status == ConfigTextFieldStatusGood && config.onNext) {
                config.onNext(config);
            }
        };
        config.onNext = encryptAndFinish;
        
        [configController.navigationController pushViewController:config animated:YES];
    };
    
    // ***************************
    // STEP 4/3 - Choose a password
    void (^getPassword)(ConfigController*) = ^(ConfigController *configController) {
        NSString *title = @"Choose a Password";
        NSString *message = @">Enter a password to encrypt this account on this device.";
        NSString *note = [NSString stringWithFormat:@"Password must be %d characters or longer.", MIN_PASSWORD_LENGTH];
        
        PasswordConfigController *config = [PasswordConfigController configWithHeading:title message:message note:note];
        config.nextEnabled = NO;
        config.nextTitle = @"Next";
        config.didChange = ^(PasswordConfigController *config) {
            accountPassword = nil;
            NSString *password = config.passwordField.textField.text;
            if (password.length == 0) {
                config.passwordField.status = ConfigTextFieldStatusNone;
                config.nextEnabled = NO;
            } else if (password.length >= MIN_PASSWORD_LENGTH) {
                accountPassword = password;
                config.passwordField.status = ConfigTextFieldStatusGood;
                config.nextEnabled = YES;
            } else {
                config.passwordField.status = ConfigTextFieldStatusBad;
                config.nextEnabled = NO;
            }
        };
        config.onLoad = ^(ConfigController *config) {
            [((PasswordConfigController*)config).passwordField.textField becomeFirstResponder];
        };
        config.onNext = verifyPassword;
        config.onReturn = ^(PasswordConfigController *config) {
            if (config.passwordField.status == ConfigTextFieldStatusGood && config.onNext) {
                config.onNext(config);
            }
        };
        
        [configController.navigationController pushViewController:config animated:YES];
    };
    
    config.onOption = ^(OptionsConfigController *configController, NSUInteger index) {
        //ConfigNavigationController *navigationController = (ConfigNavigationController*)(config.navigationController);
        
        if (index == 0) {

            account = [Account randomMnemonicAccount];
            
            // ***************************
            // STEP 3 - Verify the backup phrase
            void (^verifyBackupPhrase)(ConfigController*) = ^(ConfigController *configController) {
                NSString *title = @"Verify Backup Phrase";
                NSString *message = @"Please verify you have written your backup phrase correctly.";
                
                MnemonicConfigController *config = [MnemonicConfigController mnemonicHeading:title message:message note:nil];
                config.didChange = ^(MnemonicConfigController *config) {
#ifdef DEBUG_SKIP_VERIFY_MNEMONIC
                    config.nextEnabled = YES;
#else
                    config.nextEnabled = [config.mnemonicPhraseView.mnemonicPhrase isEqualToString:account.mnemonicPhrase];
#endif
                };
                config.nextEnabled = NO;
                config.nextTitle = @"Next";
                config.onLoad = ^(ConfigController *config) {
                    MnemonicPhraseView *mnemonicPhraseView = ((MnemonicConfigController*)config).mnemonicPhraseView;
                    mnemonicPhraseView.userInteractionEnabled = YES;
                    
#ifdef DEBUG_SKIP_VERIFY_MNEMONIC
                    mnemonicPhraseView.mnemonicPhrase = account.mnemonicPhrase;
                    config.nextEnabled = YES;
#else
                    [mnemonicPhraseView becomeFirstResponder];
#endif

                };
                config.onNext = getPassword;
                
                [configController.navigationController pushViewController:config animated:YES];
            };
            
            // ***************************
            // STEP 2 - Show the backup phrase
            void (^showBackupPhrase)(ConfigController*) = ^(ConfigController *configController) {
                NSString *title = @"Your Backup Phrase";
                NSString *message = @"Write this down and store it somewhere **safe**.";
                NSString *note = @"//You will need to enter this phrase on the next screen.//";
                
                MnemonicConfigController *config = [MnemonicConfigController mnemonicHeading:title message:message note:note];
                [config setStep:2 totalSteps:6];
                config.nextEnabled = YES;
                config.nextTitle = @"Next";
                config.onLoad = ^(ConfigController *config) {
                    MnemonicPhraseView *mnemonicPhraseView = ((MnemonicConfigController*)config).mnemonicPhraseView;
                    mnemonicPhraseView.mnemonicPhrase = account.mnemonicPhrase;
                };
                config.onNext = verifyBackupPhrase;
                
                [configController.navigationController pushViewController:config animated:YES];
            };
            
            
            // ***************************
            // STEP 1 - Show a warning regarding protecting the backup phrase
            {
                NSString *title = @"Account Backup";
                NSArray<NSString*> *messages = @[
                                                 @"Your account backup is a 12 word phrase.",
                                                 @"You **must** write it down and store it somewhere **safe**.",
                                                 @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                                                 @"**KEEP IT SAFE**"
                                                 ];
                NSString *note = @"//Tap \"I Agree\" to see your backup phrase.//";
                
                MnemonicWarningConfigController *config = [MnemonicWarningConfigController mnemonicWarningTitle:title
                                                                                                       messages:messages
                                                                                                           note:note];
                [config setStep:1 totalSteps:6];
             
                config.onNext = showBackupPhrase;

                [configController.navigationController pushViewController:config animated:YES];
            };
        

        } else if (index == 1) {
            
            // ***************************
            // STEP 2 - Get the backup phrase
            void (^getBackupPhrase)(ConfigController*) = ^(ConfigController *configController) {
                
                NSString *title = @"Enter Phrase";
                NSString *message = @"Please enter your //backup phrase//.";
                
                MnemonicConfigController *config = [MnemonicConfigController mnemonicHeading:title message:message note:nil];
                config.didChange = ^(MnemonicConfigController *config) {
                    NSString *mnemonicPhrase = config.mnemonicPhraseView.mnemonicPhrase;
                    if ([Account isValidMnemonicPhrase:mnemonicPhrase]) {
                        account = [Account accountWithMnemonicPhrase:mnemonicPhrase];
                        config.nextEnabled = YES;
                    } else {
                        config.nextEnabled = NO;
                    }
                };
                config.nextEnabled = NO;
                config.nextTitle = @"Next";
                config.onLoad = ^(ConfigController *config) {
                    MnemonicPhraseView *mnemonicPhraseView = ((MnemonicConfigController*)config).mnemonicPhraseView;
                    mnemonicPhraseView.userInteractionEnabled = YES;
                    [mnemonicPhraseView becomeFirstResponder];
                };
                config.onNext = getPassword;
                
                [configController.navigationController pushViewController:config animated:YES];
            };
            
            // ***************************
            // STEP 1 - Show a warning regarding protecting the backup phrase
            {
                NSString *title = @"Import Account";
                NSArray *messages = @[
                                      @"Your account backup is a 12 word phrase.",
                                      @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                                      @"**KEEP IT SAFE**"
                                      ];
                NSString *note = @"//Tap \"I Agree\" to enter your backup phrase.//";
                
                MnemonicWarningConfigController *config = [MnemonicWarningConfigController mnemonicWarningTitle:title
                                                                                                       messages:messages
                                                                                                           note:note];
                [config setStep:1 totalSteps:5];
                config.onNext = getBackupPhrase;
                
                [configController.navigationController pushViewController:config animated:YES];
            };
        
        } else if (index == 2) {
            NSString *nickname = @"ethers.io";
            NSString *keychainKey = [NSString stringWithFormat:@"%@/firefly/%@", weakSelf.keychainKey, chainName(chainId)];
            switch (chainId) {
                case ChainIdHomestead:
                    nickname = @"Firefly";
                    break;
                case ChainIdKovan:
                    nickname = @"Firefly (Kovan)";
                    break;
                case ChainIdRinkeby:
                    nickname = @"Firefly (Rinkeby)";
                    break;
                case ChainIdRopsten:
                    nickname = @"Firefly (Ropsten)";
                    break;
                default:
                    nickname = @"Firefly (Testnet)";
                    break;
            }
            
            
            FireflyPairingConfigController *config = [FireflyPairingConfigController config];
            config.didCancel = ^(FireflyPairingConfigController *config) {
                [(ConfigNavigationController*)(config.navigationController) dismissWithResult:nil];
            };
            
            config.didDetectFirefly = ^(FireflyPairingConfigController *config, Address *address, NSData *pairKey) {
                Signer *signer = [FireflySigner writeToKeychain:keychainKey
                                                       nickname:nickname
                                                        address:address
                                                      secretKey:pairKey
                                                       provider:[weakSelf getProvider:chainId]];
                
                if (signer) {
                    // Make sure account indices are compact
                    [weakSelf saveAccountOrder];
                    
                    // Set the new account's index to the end
                    signer.accountIndex = weakSelf.numberOfAccounts;
                    
                    // Reload signers
                    [weakSelf reloadSigners];
                    
                    [weakSelf doNotify:WalletAccountAddedNotification signer:signer userInfo:nil transform:nil];
                    
                    FireflyDoneConfigController *config = [FireflyDoneConfigController configWithSigner:nil];
                    
                    [configController.navigationController pushViewController:config animated:YES];
                    
                    config.onNext = ^(ConfigController *config) {
                        [(ConfigNavigationController*)(config.navigationController) dismissWithResult:signer.address];
                    };
                    
                } else {
                    NSLog(@"Wallet: Error writing signer to Keychain");
                }
            };
            
            [configController.navigationController pushViewController:config animated:YES];
        }
        
    };
    
    if (self.testnetEnabled) {
        config.nextTitle = @"Mainnet";
        config.nextEnabled = YES;
        config.onNext = ^(ConfigController *config) {
            NSString *message = @"";
            UIAlertController *options = [UIAlertController alertControllerWithTitle:@"Advanced"
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            void (^useRopsten)(UIAlertAction*) = ^(UIAlertAction *action) {
                config.nextTitle = @"Ropsten";
                chainId = ChainIdRopsten;
            };

            void (^useRinkeby)(UIAlertAction*) = ^(UIAlertAction *action) {
                config.nextTitle = @"Rinkeby";
                chainId = ChainIdRinkeby;
            };

            void (^useKovan)(UIAlertAction*) = ^(UIAlertAction *action) {
                config.nextTitle = @"Kovan";
                chainId = ChainIdKovan;
            };

            void (^useHomestead)(UIAlertAction*) = ^(UIAlertAction *action) {
                config.nextTitle = @"Mainnet";
                chainId = ChainIdHomestead;
            };
            
            [options addAction:[UIAlertAction actionWithTitle:@"Kovan Testnet"
                                                        style:UIAlertActionStyleDefault
                                                      handler:useKovan]];
            [options addAction:[UIAlertAction actionWithTitle:@"Ropsten Testnet"
                                                        style:UIAlertActionStyleDefault
                                                      handler:useRopsten]];
            [options addAction:[UIAlertAction actionWithTitle:@"Rinkeby Testnet"
                                                        style:UIAlertActionStyleDefault
                                                      handler:useRinkeby]];
            [options addAction:[UIAlertAction actionWithTitle:@"Homestead Mainnet"
                                                        style:UIAlertActionStyleCancel
                                                      handler:useHomestead]];
            
            [config.navigationController presentViewController:options animated:YES completion:nil];
        };
    }
    
    ConfigNavigationController *navigationController = [ConfigNavigationController configNavigationController:config];
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)manageAccountAtIndex: (AccountIndex)index callback:(void (^)())callback {
    
    __weak Wallet *weakSelf = self;
    
    Signer *signer = [_accounts objectAtIndex:index];
    
    if (!signer) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback();
        });
        return;
    }
    
    BOOL firefly = [signer isKindOfClass:[FireflySigner class]];
    
    NSString *heading = @"Manage Account";
    NSString *subheading = signer.nickname;
    NSArray<NSString*> *options = @[
                                    @"View Backup Phrase",
                                    @"Delete Account"
                                    ];

    if (firefly) {
        heading = @"Manage Firefly";
        options = @[
                    @"Unpair Firefly Wallet"
                    ];
    }

    void (^onLoad)(ConfigController*) = ^(ConfigController *configController) {
        [((PasswordConfigController*)configController).passwordField.textField becomeFirstResponder];
    };
    
    void (^didChange)(PasswordConfigController*) = ^(PasswordConfigController *configController) {

        [signer cancelUnlock];
        [signer lock];

        configController.nextEnabled = NO;

        NSString *password = configController.passwordField.textField.text;
        if (password.length == 0) {
            configController.passwordField.status = ConfigTextFieldStatusNone;
            return;
        }
        
        configController.passwordField.status = ConfigTextFieldStatusSpinning;
        [signer unlockPassword:password callback:^(Signer *signer, NSError *error) {
            if (![configController.passwordField.textField.text isEqualToString:password]) {
                return;
            }

            if (signer.unlocked) {
                configController.passwordField.status = ConfigTextFieldStatusGood;
                configController.nextEnabled = YES;

            } else {
                configController.passwordField.status = ConfigTextFieldStatusBad;
                configController.nextEnabled = NO;
            }
            
        }];
        
    };
    
    void (^onReturn)(PasswordConfigController*) = ^(PasswordConfigController *configController) {
        if (configController.passwordField.status == ConfigTextFieldStatusGood && configController.onNext) {
            configController.onNext(configController);
        }
    };
    
    void (^dismiss)(ConfigController*) = ^(ConfigController *configController) {
        [(ConfigNavigationController*)(configController.navigationController) dismissWithNil];
    };
    
    OptionsConfigController *config = [OptionsConfigController configWithHeading:heading
                                                                      subheading:subheading
                                                                        messages:nil
                                                                         options:options];

    config.onOption = ^(OptionsConfigController *configController, NSUInteger index) {
        if (firefly && index == 0) {
            // @TODO: Maybe show a warning screen?
            BOOL removed = [(FireflySigner*)signer remove];
            NSLog(@"Removed Account: address=%@ success=%d", signer.address, removed);
            
            [weakSelf reloadSigners];
            [weakSelf saveAccountOrder];
            
            [weakSelf doNotify:WalletAccountRemovedNotification signer:signer userInfo:nil transform:nil];
            
            [(ConfigNavigationController*)(configController.navigationController) dismissWithNil];
            
        } else if (index == 0) {
            // ***************************
            // STEP 3 - Show the backup phrase
            void (^showBackupPhrase)(ConfigController*) = ^(ConfigController *configController) {
                NSString *heading = @"Your Backup Phrase";
                NSString *message = @"Here is your //backup phrase//. Keep it **safe**.";
                
                MnemonicConfigController *config = [MnemonicConfigController mnemonicHeading:heading message:message note:nil];
                config.navigationItem.hidesBackButton = YES;
                config.nextEnabled = YES;
                config.nextTitle = @"Done";
                config.onLoad = ^(ConfigController *config) {
                    MnemonicPhraseView *mnemonicPhraseView = ((MnemonicConfigController*)config).mnemonicPhraseView;
                    mnemonicPhraseView.mnemonicPhrase = signer.mnemonicPhrase;
                };
                config.onNext = dismiss;

                [configController.navigationController pushViewController:config animated:YES];
            };
            
            // ***************************
            // STEP 2 - Show a warning for the backup phrase
            void (^showWarning)(ConfigController*) = ^(ConfigController *configController) {
                NSString *heading = @"View Backup Phrase";
                NSArray *messages = @[
                                      @"Your account backup is a 12 word phrase.",
                                      @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                                      @"**KEEP IT SAFE**"
                                      ];
                NSString *note = @"//Tap \"I Agree\" to see your backup phrase.//";
                MnemonicWarningConfigController *config = [MnemonicWarningConfigController mnemonicWarningTitle:heading
                                                                                                       messages:messages
                                                                                                           note:note];
                config.onNext = showBackupPhrase;
                [configController.navigationController pushViewController:config animated:YES];
            };
            
            // ***************************
            // STEP 1 - Get the password and decrypt the wallet (so we can verify the mnemonic)
            {
                NSString *heading = @"Enter Your Password";
                NSString *message = @">You must unlock your account to view your backup phrase.";
                PasswordConfigController *config = [PasswordConfigController configWithHeading:heading message:message note:nil];
                [config setStep:1 totalSteps:3];
                config.nextEnabled = NO;
                config.nextTitle = @"Next";
                config.didChange = didChange;
                config.onLoad = onLoad;
                config.onNext = showWarning;
                config.onReturn = onReturn;
                
                [configController.navigationController pushViewController:config animated:YES];
            }
            
        } else if (index == 1) {
//            // Debugging to remove pesky accounts during development
//            if (!signer.supportsMnemonicPhrase) {
//                [(CloudKeychainSigner*)signer remove];
//            }
            
            void (^confirmDelete)(ConfigController*) = ^(ConfigController *configController) {
                NSString *heading = @"Delete Account?";
                NSString *subheading = signer.nickname;
                NSArray<NSString*> *messages = @[
                                                 @"This account will be deleted from all your devices.",
                                                 @"You will need to use your //backup phrase// to restore this account."
                                                 ];
                NSArray<NSString*> *options = @[
                                                @"Cancel"
                                                ];
                OptionsConfigController *config = [OptionsConfigController configWithHeading:heading subheading:subheading messages:messages options:options];
                config.navigationItem.rightBarButtonItem.tintColor = [UIColor redColor];
                config.nextEnabled = NO;
                config.nextTitle = @"Delete";
                
                config.onLoad = ^(ConfigController *config) {
                    [NSTimer scheduledTimerWithTimeInterval:3.0f repeats:NO block:^(NSTimer *timer) {
                        config.nextEnabled = YES;
                    }];
                };
                
                config.onNext = ^(ConfigController *config) {
                    BOOL removed = [(CloudKeychainSigner*)signer remove];
                    NSLog(@"Removed Account: address=%@ success=%d", signer.address, removed);
                    
                    [weakSelf reloadSigners];
                    [weakSelf saveAccountOrder];
                    
                    [weakSelf doNotify:WalletAccountRemovedNotification signer:signer userInfo:nil transform:nil];
                    
                    [(ConfigNavigationController*)(configController.navigationController) dismissWithNil];
                };
                
                config.onOption = ^(OptionsConfigController *config, NSUInteger index) {
                    if (index == 0) {
                        [(ConfigNavigationController*)(configController.navigationController) dismissWithNil];
                    }
                };
                
                [configController.navigationController pushViewController:config animated:YES];
            };
            
            void (^getBackupPhrase)(ConfigController*) = ^(ConfigController *configController) {
                NSString *title = @"Verify Backup Phrase";
                NSString *message = @"You must verify you have written your //backup phrase// correctly.";
                
                MnemonicConfigController *config = [MnemonicConfigController mnemonicHeading:title message:message note:nil];
                config.didChange = ^(MnemonicConfigController *config) {
                    NSString *mnemonicPhrase = config.mnemonicPhraseView.mnemonicPhrase;
                    config.nextEnabled = [mnemonicPhrase isEqualToString:signer.mnemonicPhrase];
                };
                config.nextEnabled = NO;
                config.nextTitle = @"Next";
                
                config.onLoad = ^(ConfigController *config) {
                    MnemonicPhraseView *mnemonicPhraseView = ((MnemonicConfigController*)config).mnemonicPhraseView;
                    mnemonicPhraseView.userInteractionEnabled = YES;
                    
#ifdef DEBUG_SKIP_VERIFY_MNEMONIC
                    mnemonicPhraseView.mnemonicPhrase = signer.mnemonicPhrase;
                    config.nextEnabled = YES;
#else
                    [mnemonicPhraseView becomeFirstResponder];
#endif
                    
                };
                
                config.onNext = confirmDelete;
                
                
                [configController.navigationController pushViewController:config animated:YES];
            };
            
            void (^showWarning)(ConfigController*) = ^(ConfigController *configController) {
                NSString *heading = @"";
                NSArray *messages = @[
                                      @"Your account backup is a 12 word phrase.",
                                      @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                                      @"**KEEP A COPY SOMEWHERE SAFE**"
                                      ];
                NSString *note = @"//Tap \"I Agree\" to enter your backup phrase.//";
                MnemonicWarningConfigController *config = [MnemonicWarningConfigController mnemonicWarningTitle:heading
                                                                                                       messages:messages
                                                                                                           note:note];
                
                config.onNext = getBackupPhrase;
                
                [configController.navigationController pushViewController:config animated:YES];
            };
            
            {
                NSString *heading = @"Enter Your Password";
                NSString *message = @"You must unlock your account to delete it. This account will be removed from **all** your devices.";
                PasswordConfigController *config = [PasswordConfigController configWithHeading:heading message:message note:nil];
                [config setStep:1 totalSteps:4];
                config.nextEnabled = NO;
                config.nextTitle = @"Next";
                
                config.didChange = didChange;
                config.onLoad = onLoad;
                config.onNext = showWarning;
                config.onReturn = onReturn;
                
                [configController.navigationController pushViewController:config animated:YES];
            }
        }
        
    };

    ConfigNavigationController *navigationController = [ConfigNavigationController configNavigationController:config];
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}


#pragma mark - Transactions

- (void)scan:(void (^)(Transaction*, NSError*))callback {
    
    if (!self.activeAccountAddress) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            if (callback) { callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorNoAccount userInfo:@{}]); }
        });
        return;
    }
    
    __weak Wallet *weakSelf = self;
    
    Signer *signer = [_accounts objectAtIndex:_activeAccountIndex];
    
    ScannerConfigController *scanner = [ScannerConfigController configWithSigner:signer];
    
    scanner.onNext = ^(ConfigController *configController) {
        ScannerConfigController *scanner = (ScannerConfigController*)configController;
        
        Transaction *transaction = [Transaction transaction];
        transaction.toAddress = scanner.foundAddress;
        if (scanner.foundAmount) {
            transaction.value = scanner.foundAmount;
        }

        TransactionConfigController *config = [TransactionConfigController configWithSigner:signer
                                                                                transaction:transaction
                                                                                   nameHint:scanner.foundName];
        config.etherPrice = weakSelf.etherPrice;
        
        config.onSign = ^(TransactionConfigController *configController, Transaction *transaction) {
            [(ConfigNavigationController*)(configController.navigationController) dismissWithResult:transaction];
        };
        [configController.navigationController pushViewController:config animated:YES];
    };

    __weak ScannerConfigController *weakScanner = scanner;
    void (^onComplete)() = ^() {
        dispatch_async(dispatch_get_main_queue(), ^() {
            [weakScanner startScanningAnimated:YES];
        });
    };
    
    ConfigNavigationController *navigationController = [ConfigNavigationController configNavigationController:scanner];
    navigationController.onDismiss = ^(NSObject *result) {
        if (![result isKindOfClass:[Transaction class]]) {
            [signer cancel];
            if (callback) {
                callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorSendCancelled userInfo:@{}]);
            }
        } else if (callback){
            callback((Transaction*)result, nil);
        }
    };

    [ModalViewController presentViewController:navigationController
                                      animated:YES
                                    completion:onComplete];
}

- (void)sendPayment:(Payment *)payment callback:(void (^)(Transaction*, NSError*))callback {
    Transaction *transaction = [Transaction transaction];
    transaction.toAddress = payment.address;
    transaction.value = payment.amount;

    [self sendTransaction:transaction firm:payment.firm callback:callback];
}

- (void)sendTransaction: (Transaction*)transaction callback:(void (^)(Transaction*, NSError*))callback {
    [self sendTransaction:transaction firm:YES callback:callback];
}

- (void)sendTransaction: (Transaction*)transaction firm: (BOOL)firm callback:(void (^)(Transaction*, NSError*))callback {

    // No signer is an automatic cancel
    if (_activeAccountIndex == AccountNotFound) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorSendCancelled userInfo:@{}]);
        });
        return;
    }

    Signer *signer = [_accounts objectAtIndex:_activeAccountIndex];
    
    TransactionConfigController *config = [TransactionConfigController configWithSigner:signer transaction:transaction nameHint:nil];
    config.etherPrice = [self etherPrice];
    
    config.onSign = ^(TransactionConfigController *configController, Transaction *transaction) {
        [(ConfigNavigationController*)(configController.navigationController) dismissWithResult:transaction];
    };

    ConfigNavigationController *navigationController = [ConfigNavigationController configNavigationController:config];
    navigationController.onDismiss = ^(NSObject *result) {
        if (![result isKindOfClass:[Transaction class]]) {
            [signer cancel];
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorSendCancelled userInfo:@{}]);
        } else {
            callback((Transaction*)result, nil);
        }
    };

    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)overrideTransaction:(TransactionInfo *)oldTransaction
                     action:(WalletTransactionAction)action
                   callback:(void (^)(Transaction *, NSError *))callback {
    
    // No signer is an automatic cancel
    if (_activeAccountIndex == AccountNotFound) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorSendCancelled userInfo:@{}]);
        });
        return;
    }

    Signer *signer = [_accounts objectAtIndex:_activeAccountIndex];

    if (![oldTransaction.fromAddress isEqualToAddress:signer.address]) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorNoAccount userInfo:@{}]);
        });
        return;
    }
    
    Transaction *transaction = [Transaction transaction];
    
    if (action == WalletTransactionActionCancel) {
        // New Gas Price is (ceil(150% oldGasPrice) + 1 wei)
        BigNumber *halfCeil = [[oldTransaction.gasPrice add:[BigNumber constantOne]] div:[BigNumber constantTwo]];
        BigNumber *gasPrice = [[oldTransaction.gasPrice add:halfCeil] add:[BigNumber constantOne]];
        
        // If it is less than a medium priced transaction, use the medium gas price instead
        BigNumber *safeGasPrice = [GasPriceKeyboardView safeReplacementGasPrice];
        if ([gasPrice lessThan:safeGasPrice]) { gasPrice = safeGasPrice; }

        transaction.toAddress = signer.address;
        transaction.nonce = oldTransaction.nonce;
        transaction.gasPrice = gasPrice;
        
        transaction.gasLimit = [BigNumber bigNumberWithInteger:21000];
        transaction.value = [BigNumber constantZero];
    
    } else {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorNotImplemented userInfo:@{}]);
        });
        return;
    }

    
    TransactionConfigController *config = [TransactionConfigController configWithSigner:signer
                                                                            transaction:transaction
                                                                                 action:action];
    config.etherPrice = [self etherPrice];
    
    config.onSign = ^(TransactionConfigController *configController, Transaction *transaction) {
        [(ConfigNavigationController*)(configController.navigationController) dismissWithResult:transaction];
    };
    
    ConfigNavigationController *navigationController = [ConfigNavigationController configNavigationController:config];
    navigationController.onDismiss = ^(NSObject *result) {
        if (![result isKindOfClass:[Transaction class]]) {
            [signer cancel];
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorSendCancelled userInfo:@{}]);
        } else {
            callback((Transaction*)result, nil);
        }
    };
    
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)signMessage: (NSData*)message callback:(void (^)(Signature*, NSError*))callback {
    
    // No signer is an automatic cancel
    if (_activeAccountIndex == AccountNotFound) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorSendCancelled userInfo:@{}]);
        });
        return;
    }
    
    Signer *signer = [_accounts objectAtIndex:_activeAccountIndex];
    SigningConfigController *config = [SigningConfigController configWithSigner:signer message:message];
    
    config.onSign = ^(SigningConfigController *configController, Signature *signature) {
        [(ConfigNavigationController*)(configController.navigationController) dismissWithResult:signature];
    };
    
    ConfigNavigationController *navigationController = [ConfigNavigationController configNavigationController:config];
    navigationController.onDismiss = ^(NSObject *result) {
        if (![result isKindOfClass:[Signature class]]) {
            [signer cancel];
            callback(nil, [NSError errorWithDomain:WalletErrorDomain code:WalletErrorSendCancelled userInfo:@{}]);
        } else {
            callback((Signature*)result, nil);
        }
    };
    
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Debugging

- (BOOL)fireflyEnabled {
    return [_dataStore boolForKey:DataStoreKeyEnableFirefly];
}

- (void)setFireflyEnabled:(BOOL)enabled {
    [_dataStore setBool:enabled forKey:DataStoreKeyEnableFirefly];
}

- (BOOL)testnetEnabled {
    return [_dataStore boolForKey:DataStoreKeyEnableTestnet];
}

- (void)setTestnetEnabled:(BOOL)enabled {
    [_dataStore setBool:enabled forKey:DataStoreKeyEnableTestnet];
}

- (void)showDebuggingOptions:(WalletOptionsType)walletOptionsType callback:(void (^)())callback {
    ConfigController *config = nil;
    
    switch (walletOptionsType) {
        case WalletOptionsTypeDebug:
            config = [DebugConfigController configWithWallet:self];
            break;
        case WalletOptionsTypeFirefly:
            config = [FireflyConfigController configWithWallet:self];
            break;
        default:
            if (callback) {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    callback();
                });
            }
            return;
    }
    
    ConfigNavigationController *navigationController = [ConfigNavigationController configNavigationController:config];
    navigationController.onDismiss = ^(NSObject *result) {
        if (callback) { callback(); }
    };
    
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}


#pragma mark - Blockchain


// The oldest sync date for any account
- (NSTimeInterval)syncDate {
    BOOL found = NO;
    NSTimeInterval syncDate = 0.0f;
    for (Signer *signer in _accounts) {
        NSTimeInterval signerSyncDate = signer.syncDate;
        if (!found || signerSyncDate < syncDate) {
            syncDate = signerSyncDate;
            found = YES;
        }
    }
    return syncDate;
}

- (float)etherPrice {
    return [_dataStore floatForKey:DataStoreKeyEtherPrice];
}

- (void)refresh:(void (^)(BOOL))callback {
    NSMutableArray *promises = [NSMutableArray arrayWithCapacity:_accounts.count];
    
    for (Signer *signer in _accounts) {
        [promises addObject:[Promise promiseWithSetup:^(Promise *promise) {
            [signer refresh:^(BOOL changed) {
                [promise resolve:@(changed)];
            }];
        }]];
    }
    
    [[Promise all:promises] onCompletion:^(ArrayPromise *promise) {
        if (callback) { callback(YES); }
    }];
}

@end
