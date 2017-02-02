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
#define DEBUG_SKIP_VERIFY_MNEMONIC    YES


// @TODO: These should prolly live in the ethers Framework
#define CHAIN_ID_HOMESTEAD             0x01
#define CHAIN_ID_MORDEN                0x02
#define CHAIN_ID_ROPSTEN               0x03


//@import CoreText;
@import LocalAuthentication;

#import <ethers/Account.h>
#import <ethers/EtherscanProvider.h>
#import <ethers/FallbackProvider.h>
#import <ethers/InfuraProvider.h>
#import <ethers/Payment.h>
#import <ethers/SecureData.h>

#import "CachedDataStore.h"
#import "InfoViewController.h"
#import "RegEx.h"
#import "ModalViewController.h"
#import "UIColor+hex.h"
#import "Utilities.h"


#pragma mark - Service Credentials

#define ETHERSCAN_API_KEY                   @"YTCX255XJGH9SCBUDP2K48S4YWACUEFSJX"
#define INFURA_ACCESS_TOKEN                 @"VOSzw3GAef7pxbSbpYeL"


#pragma mark - Error Domain

NSErrorDomain WalletErrorDomain = @"WalletErrorDomain";


#define MIN_PASSWORD_LENGTH       6

NSString *shortAddress(Address *address) {
    NSString *hex = address.checksumAddress;
    return [NSString stringWithFormat:@"%@\u2026%@", [hex substringToIndex:9], [hex substringFromIndex:hex.length - 7]];
}

NSString *getNickname(NSString *label) {

    static NSRegularExpression *regexLabel = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        regexLabel = [NSRegularExpression regularExpressionWithPattern:@"[^(]*\\((.*)\\)" options:0 error:&error];
        if (error) {
            NSLog(@"Error: %@", error);
        }
    });
    
    NSTextCheckingResult *result = [regexLabel firstMatchInString:label options:0 range:NSMakeRange(0, label.length)];
    
    if ([result numberOfRanges] && [result rangeAtIndex:1].location != NSNotFound) {
        return [label substringWithRange:[result rangeAtIndex:1]];
    }
    
    return @"ethers.io";
}


#pragma mark - Keychain helpers

NSString* getKeychainValue(NSString *keychainKey, Address *address) {
    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnData: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: address.checksumAddress,
                            (id)kSecAttrService: @"ethers.io",
                            };
    
    NSString *value = nil;
    
    {
        CFDataRef data = nil;
        
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&data);
        if (status == noErr) {
            value = [[NSString alloc] initWithBytes:[(__bridge NSData*)data bytes]
                                             length:[(__bridge NSData*)data length]
                                           encoding:NSUTF8StringEncoding];
        }
        
        if (data) { CFRelease(data); }
    }
    
    
    return value;
}

BOOL addKeychainVaue(NSString *keychainKey, Address *address, NSString *nickname, NSString *value) {
    
    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: address.checksumAddress,
                            (id)kSecAttrService: @"ethers.io",
                            };
    
    CFDictionaryRef existingEntry = nil;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&existingEntry);
    if (status == noErr) {
        
        NSMutableDictionary *updateQuery = [(__bridge NSDictionary *)existingEntry mutableCopy];
        [updateQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
        
        NSDictionary *updateEntry = @{
                                      (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                                      
                                      (id)kSecAttrAccount: address.checksumAddress,
                                      (id)kSecAttrService: @"ethers.io",
                                      (id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding],
                                      
                                      (id)kSecAttrLabel: [NSString stringWithFormat:@"Ethers Account (%@)", nickname],
                                      (id)kSecAttrDescription: @"Encrypted JSON Wallet",
                                      (id)kSecAttrComment: @"This is managed by Ethers and contains an encrypted copy of your JSON wallet.",
                                      };
        
        status = SecItemUpdate((__bridge CFDictionaryRef)updateQuery, (__bridge CFDictionaryRef)updateEntry);
        if (status != noErr) {
            NSLog(@"ERROR: Failed to update %@ - %d", address, (int)status);
        }
        
    } else {
        NSDictionary *addEntry = @{
                                   (id)kSecClass: (id)kSecClassGenericPassword,
                                   (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                                   (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                                   
                                   (id)kSecAttrAccount: address.checksumAddress,
                                   (id)kSecAttrService: @"ethers.io",
                                   (id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding],
                                   (id)kSecAttrLabel: [NSString stringWithFormat:@"Ethers Account (%@)", nickname],
                                   (id)kSecAttrDescription: @"Encrypted JSON Wallet",
                                   (id)kSecAttrComment: @"This is managed by Ethers and contains an encrypted copy of your JSON wallet.",
                                   };
        
        status = SecItemAdd((__bridge CFDictionaryRef)addEntry, NULL);
        if (status != noErr) {
            NSLog(@"Error: Failed to add %@ - %d", address, (int)status);
        }
        
    }
    
    if (existingEntry) { CFRelease(existingEntry); }
    
    return (status == noErr);
}

BOOL removeKeychainValue(NSString *keychainKey, Address *address) {
    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: address.checksumAddress,
                            (id)kSecAttrService: @"ethers.io",
                            };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status != noErr) {
        NSLog(@"Error deleting");
    }
    
    return (status == noErr);
}

NSDictionary<Address*, NSString*> *getKeychainNicknames(NSString *keychainKey) {
    NSMutableDictionary<Address*, NSString*> *values = [NSMutableDictionary dictionaryWithCapacity:4];
    
    NSDictionary *query = @{
                            (id)kSecMatchLimit: (id)kSecMatchLimitAll,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue
                            
                            };
    
    CFMutableArrayRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&result);
    
    if (status == noErr) {
        for (NSDictionary *entry in ((__bridge NSArray*)result)) {
            [values setObject:getNickname([entry objectForKey:(id)kSecAttrLabel])
                       forKey:[Address addressWithString:[entry objectForKey:(id)kSecAttrAccount]]];
        }
        
    } else if (status == errSecItemNotFound) {
        // No problem... No exisitng entries
        NSLog(@"Keychain Empty");
        
    } else {
        NSLog(@"Keychain Error: %d", (int)status);
        return nil;
    }
    
    /*
     CachedDataStore *dataStore = [[CachedDataStore alloc] initWithKey:@"debug"];
     NSMutableArray *calls = [[dataStore arrayForKey:@"status"] mutableCopy];
     if (!calls) { calls = [NSMutableArray array]; }
     [calls addObject:@(status)];
     [dataStore setArray:calls forKey:@"status"];
     
     NSLog(@"Calls: %@", calls);
     */
    
    if (result) { CFRelease(result); }
    
    return values;
}

void resetKeychain(NSString *keychainKey) {
    NSLog(@"Resetting Keychain...");
    
    for (Address *address in getKeychainNicknames(keychainKey)) {
        removeKeychainValue(keychainKey, address);
    }
}


#pragma mark - Notifications

const NSNotificationName WalletAddedAccountNotification                  = @"WalletAddedAccountNotification";
const NSNotificationName WalletRemovedAccountNotification                = @"WalletRemovedAccountNotification";
const NSNotificationName WalletReorderedAccountsNotification             = @"WalletReorderedAccountsNotification";

const NSNotificationName WalletBalanceChangedNotification                = @"WalletBalanceChangedNotification";
const NSNotificationName WalletTransactionChangedNotification            = @"WalletTransactionChangedNotification";
const NSNotificationName WalletAccountTransactionsUpdatedNotification    = @"WalletAccountTransactionsUpdatedNotification";

const NSNotificationName WalletChangedNicknameNotification               = @"WalletChangedNicknameNotification";

const NSNotificationName WalletChangedActiveAccountNotification          = @"WalletChangedActiveAccountNotification";

const NSNotificationName WalletDidSyncNotification                       = @"WalletDidSyncNotification";

const NSNotificationName WalletDidChangeNetwork                          = @"WalletDidChangeNetwork";


#pragma mark - Data Store keys

static NSString *DataStoreKeyAccountPrefix                = @"ACCOUNT_";

static NSString *DataStoreKeyAccountBalancePrefix         = @"ACCOUNT_BALANCE_";
static NSString *DataStoreKeyAccountNicknamePrefix        = @"ACCOUNT_NAME_";
static NSString *DataStoreKeyAccountNoncePrefix           = @"ACCOUNT_NONCE_";

static NSString *DataStoreKeyAccountTxBlockNoncePrefix    = @"ACCOUNT_TX_BLOCK_";
static NSString *DataStoreKeyAccountTxsPrefix             = @"ACCOUNT_TXS_";


static NSString *DataStoreKeyNetworkPrefix                = @"NETWORK_";

static NSString *DataStoreKeyNetworkGasPrice              = @"NETWORK_GAS_PRICE";
static NSString *DataStoreKeyNetworkBlockNumber           = @"NETWORK_BLOCK_NUMBER";

static NSString *DataStoreKeyNetworkEtherPrice            = @"NETWORK_ETHER_PRICE";

static NSString *DataStoreKeyNetworkSyncDate              = @"NETWORK_SYNC_DATE";


static NSString *DataStoreKeyUserPrefix                   = @"USER_";

static NSString *DataStoreKeyUserActiveAccount            = @"USER_ACTIVE_ACCOUNT";
static NSString *DataStoreKeyUserAccounts                 = @"USER_ACCOUNTS";

static NSString *DataStoreKeyUserEnableTestnet            = @"USER_ENABLE_TESTNET";
static NSString *DataStoreKeyUserEnableLightClient        = @"USER_ENABLE_LIGHTCLIENT";
static NSString *DataStoreKeyUserDisableFallback          = @"USER_DISABLE_FALLBACK";
static NSString *DataStoreKeyUserCustomNode               = @"USER_CUSTOM_NODE";



#pragma mark - Wallet Life-Cycle

@implementation Wallet {
    
    // Cached account data
    NSMutableDictionary<Address*, NSString*> *_jsonWallets;
    NSMutableDictionary<Address*, Account*> *_accounts;
    //NSMutableDictionary<Address*, NSString*> *_nicknames;
    NSMutableArray<Address*> *_orderedAddresses;
    NSMutableDictionary<Address*, NSMutableArray<TransactionInfo*>*> *_transactions;
    
    // Storage for application values (NSUserDefaults seems to be flakey; lots of failed writes)
    CachedDataStore *_dataStore;
    
    // Blockchain Data
    BOOL _firstRefreshDone;
    
    IntegerPromise *_refreshPromise;
    
    UILabel *_etherPriceLabel;
    
    NSTimer *_refreshKeychainTimer;
    //    BOOL _enableLightClient, _disableFallback, _enableTestnet;
    //    NSString *_customNode;
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ((DEBUG_SKIP_VERIFY_MNEMONIC)) {
#warning DEBUGGING ENABLED - SKIP VERIFIY MNEMONIC - DO NOT RELASE
            NSLog(@"WARNING! Mnemonic Verify Skipping Enabled - Do NOT release");
        }
    });
}

+ (instancetype)walletWithKeychainKey:(NSString *)keychainKey {
    return [[Wallet alloc] initWithKeychainKey:keychainKey];
}

- (instancetype)initWithKeychainKey: (NSString*)keychainKey {
    
    self = [super init];
    if (self) {
        
        _keychainKey = keychainKey;
        _dataStore = [[CachedDataStore alloc] initWithKey:keychainKey];

        _accounts = [NSMutableDictionary dictionary];

        _jsonWallets = [NSMutableDictionary dictionary];
        _transactions = [NSMutableDictionary dictionary];

        _orderedAddresses = [NSMutableArray array];
        NSArray<NSString*> *addresses = [_dataStore arrayForKey:DataStoreKeyUserAccounts];
        for (NSString *addressString in addresses) {
            Address *address = [Address addressWithString:addressString];
            if (!addresses) {
                NSLog(@"Error: Invalid DataStore Address (%@)", addressString);
                continue;
            }
            
            [_orderedAddresses addObject:address];
            
            [_transactions setObject:[self transactionsForAddress:address] forKey:address];
        }

        _activeAccount = nil;
        Address *activeAccount = [Address addressWithString:[_dataStore stringForKey:DataStoreKeyUserActiveAccount]];;
        if (activeAccount) {
            _activeAccount = activeAccount;
        } else if (_orderedAddresses.count) {
            _activeAccount = [_orderedAddresses firstObject];
        }
        
        _etherPriceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 44.0f)];
        _etherPriceLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        _etherPriceLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
        _etherPriceLabel.font = [UIFont fontWithName:FONT_BOLD size:14.0f];
        [self updateEtherPriceLabel];

        [self setupProvider:NO];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notifyApplicationActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        _refreshKeychainTimer = [NSTimer scheduledTimerWithTimeInterval:60.0f
                                                                 target:self
                                                               selector:@selector(refreshKeychainValues)
                                                               userInfo:@{}
                                                                repeats:YES];
        [self refreshKeychainValues];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_refreshKeychainTimer invalidate];
    _refreshKeychainTimer = nil;
}


#pragma mark - NSUserDefaults helpers

- (id)_objectForKeyPrefix: (NSString*)keyPrefix address: (Address*)address {
    return [_dataStore objectForKey:[keyPrefix stringByAppendingString:address.checksumAddress]];
}

- (NSInteger)_integerForKeyPrefix: (NSString*)keyPrefix address: (Address*)address {
    return [_dataStore integerForKey:[keyPrefix stringByAppendingString:address.checksumAddress]];
}

- (void)_setObject: (NSObject*)object forKeyPrefix: (NSString*)keyPrefix address: (Address*)address {
    [_dataStore setObject:object forKey:[keyPrefix stringByAppendingString:address.checksumAddress]];
}

- (void)_setInteger: (NSInteger)value forKeyPrefix: (NSString*)keyPrefix address: (Address*)address {
    [_dataStore setInteger:value forKey:[keyPrefix stringByAppendingString:address.checksumAddress]];
}


#pragma mark - Keychain Account Management

- (void)addAccount: (Account*)account json: (NSString*)json {
    addKeychainVaue(_keychainKey, account.address, @"ethers.io", json);
    [self _setObject:@"ethers.io" forKeyPrefix:DataStoreKeyAccountNicknamePrefix address:account.address];
    
    [_jsonWallets setObject:json forKey:account.address];
    [_transactions setObject:[self transactionsForAddress:account.address] forKey:account.address];
    
    [_orderedAddresses addObject:account.address];
    [self saveAccountOrder];
    
    [self refreshActiveAccount];

    dispatch_async(dispatch_get_main_queue(), ^() {
        NSDictionary *userInfo = @{ @"address": account.address };
        [[NSNotificationCenter defaultCenter] postNotificationName:WalletAddedAccountNotification
                                                            object:self
                                                          userInfo:userInfo];
        
        [self refreshActiveAccount];
    });
}

- (void)removeAccount: (Account*)account {
    removeKeychainValue(_keychainKey, account.address);
    
    [_accounts removeObjectForKey:account.address];

    [_jsonWallets removeObjectForKey:account.address];
    [_transactions removeObjectForKey:account.address];

    [_orderedAddresses removeObject:account.address];
    [self saveAccountOrder];

    [self refreshActiveAccount];
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        NSDictionary *userInfo = @{ @"address": account.address };
        [[NSNotificationCenter defaultCenter] postNotificationName:WalletRemovedAccountNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

- (NSString*)getJSON: (Address*)address {
    NSString *json = [_jsonWallets objectForKey:address];
    if (!json) {
        json = getKeychainValue(_keychainKey, address);
        if (!json) {
            NSLog(@"ERROR: Missing JSON (%@)", address);
        }
        [_jsonWallets setObject:json forKey:address];
    }
    return json;
}

- (void)saveAccountOrder {
    NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:_orderedAddresses.count];
    for (Address *address in _orderedAddresses) {
        [addresses addObject:address.checksumAddress];
    }
    [_dataStore setArray:addresses forKey:DataStoreKeyUserAccounts];
}

- (void)refreshActiveAccount {
    Address *activeAccount = _activeAccount;
    
    if (activeAccount) {
        if ([_orderedAddresses containsObject:activeAccount]) {
            return;
        } else {
            activeAccount = nil;
        }
    }

    if (_orderedAddresses.count) {
        activeAccount = [_orderedAddresses firstObject];
    }
    
    [self setActiveAccount:activeAccount];
}

- (void)refreshKeychainValues {
    
    // Try loading the keychain entries (only works if teh device is unlocked)
    NSDictionary<Address*, NSString*> *accountNicknames = getKeychainNicknames(_keychainKey);
    if (accountNicknames) {
        NSMutableSet *newAccounts = [NSMutableSet set];
        
        for (Address *address in accountNicknames) {

            // Already a loaded account
            if ([_jsonWallets objectForKey:address]) {
                [newAccounts addObject:address];

            } else {
                NSString *json = getKeychainValue(_keychainKey, address);
                if (!json) {
                    NSLog(@"Error - Refresh Keychain Values: Missing JSON (%@)", address);
                    continue;
                }
                
                NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
                
                NSError *error = nil;
                NSDictionary *account = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
                if (error) {
                    NSLog(@"Error - Refresh Keychain Values: Invalid JSON (%@)", json);
                    continue;
                }
                
                Address *jsonAddress = [Address addressWithString:[account objectForKey:@"address"]];
                if (!jsonAddress || ![address isEqualToAddress:jsonAddress]) {
                    NSLog(@"Error - Refresh Keychain Values: Address Mismatch (jsonAddress=%@, address=%@)", jsonAddress, address);
                    continue;
                }

                [_jsonWallets setObject:json forKey:address];

                [_transactions setObject:[self transactionsForAddress:address] forKey:address];
                
                // Loaded a new valid account
                [newAccounts addObject:address];
            }
            
            NSString *nickname = [accountNicknames objectForKey:address];
            if (![nickname isEqualToString:[self nicknameForAccount:address]]) {
                [self _setNickname:nickname address:address];
            }
        }

        NSMutableSet *oldAccounts = [NSMutableSet setWithArray:_orderedAddresses];
        
        // Added accounts
        for (Address *account in newAccounts) {
            if (![oldAccounts containsObject:account]) {
                [_orderedAddresses addObject:account];
                [_transactions setObject:[self transactionsForAddress:account] forKey:account];
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [[NSNotificationCenter defaultCenter] postNotificationName:WalletAddedAccountNotification
                                                                        object:self
                                                                      userInfo:@{@"address": account}];
                });
            }
        }
        
        // Removed accounts
        for (Address *account in oldAccounts) {
            if (![newAccounts containsObject:account]) {
                [_orderedAddresses removeObject:account];
                [_transactions removeObjectForKey:account];
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [[NSNotificationCenter defaultCenter] postNotificationName:WalletRemovedAccountNotification
                                                                        object:self
                                                                      userInfo:@{@"address": account}];
                });
            }
        }
        
        [self saveAccountOrder];
    }

    // Make sure our active account makes sense (if deleted, select a new account; if none, set to nil)
    [self refreshActiveAccount];
}


#pragma mark - State


- (void)notifyEtherPrice: (NSNotification*)note {
    float etherPrice = [[note.userInfo objectForKey:@"price"] floatValue];
    if (etherPrice != 0.0f && etherPrice != self.etherPrice) {
        [self setEtherPrice:etherPrice];
    }
    [self updateEtherPriceLabel];
}

- (void)notifyBlockNumber: (NSNotification*)note {
    [self refresh:nil];
}

- (void)notifyApplicationActive: (NSNotification*)note {
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer *timer) {
        [self refreshKeychainValues];
    }];
}

- (void)setupProvider: (BOOL)purge {
    
    // Purge provider dependent data (e.g. changing testnet to mainnet means different transactions exist)
    if (purge) {
        
        // Delete cached data the provider ever provided us (account and network data; keep user data)
        [_dataStore filterData:^BOOL(CachedDataStore *dataStore, NSString *key) {
            return [key hasPrefix:DataStoreKeyUserPrefix];
        }];

        // This will create empty entries for each address
        [_transactions removeAllObjects];
        for (Address *address in _transactions) {
            [_transactions setObject:[self transactionsForAddress:address] forKey:address];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            NSDictionary *userInfo = nil;
            for (Address *address in _orderedAddresses) {
                userInfo = @{ @"address": address, @"balance": [BigNumber constantZero] };
                [[NSNotificationCenter defaultCenter] postNotificationName:WalletBalanceChangedNotification
                                                                    object:self
                                                                  userInfo:userInfo];
                userInfo = @{ @"address": address, @"highestBlockNumber": @(0) };
                [[NSNotificationCenter defaultCenter] postNotificationName:WalletAccountTransactionsUpdatedNotification
                                                                    object:self
                                                                  userInfo:userInfo];
            }
            
            userInfo = @{ @"syncDate": @(0) };
            [[NSNotificationCenter defaultCenter] postNotificationName:WalletDidSyncNotification
                                                                object:self
                                                              userInfo:userInfo];
        });
    }
    
    if (_provider) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:ProviderEtherPriceChangedNotification object:_provider];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:ProviderDidReceiveNewBlockNotification object:_provider];

        [_provider stopPolling];
    }
    
    BOOL enableTestnet = [_dataStore boolForKey:DataStoreKeyUserEnableTestnet];

    // Prepare a provider
    FallbackProvider *fallbackProvider = [[FallbackProvider alloc] initWithTestnet:enableTestnet];
    if ([_dataStore boolForKey:DataStoreKeyUserEnableLightClient]) {
        //[fallbackProvider addProvider:[[LightClient alloc] initWithTestnet:enableTestnet]];
    }
  
    NSString *customNode = [_dataStore stringForKey:DataStoreKeyUserCustomNode];
    if (customNode) {
        [fallbackProvider addProvider:[[JsonRpcProvider alloc] initWithTestnet:enableTestnet url:[NSURL URLWithString:customNode]]];
    }
    
    if (![_dataStore boolForKey:DataStoreKeyUserDisableFallback] || fallbackProvider.count == 0) {
        [fallbackProvider addProvider:[[InfuraProvider alloc] initWithTestnet:enableTestnet accessToken:INFURA_ACCESS_TOKEN]];
        [fallbackProvider addProvider:[[EtherscanProvider alloc] initWithTestnet:enableTestnet apiKey:ETHERSCAN_API_KEY]];
    }
    
    _provider = fallbackProvider;

    //_provider = [TestProvider testCrazyTransactionTurmoil];
    [_provider startPolling];
    
    NSLog(@"Provider: %@", _provider);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyEtherPrice:)
                                                 name:ProviderEtherPriceChangedNotification
                                               object:_provider];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyBlockNumber:)
                                                 name:ProviderDidReceiveNewBlockNotification
                                               object:_provider];
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        [[NSNotificationCenter defaultCenter] postNotificationName:WalletDidChangeNetwork
                                                            object:self
                                                          userInfo:@{}];
    });
    
    [self refresh:^(BOOL updated) { }];
}

- (void)debugSetCustomNode: (NSString*)url {
    [_dataStore setString:url forKey:DataStoreKeyUserCustomNode];
    [self setupProvider:YES];
}

- (void)debugSetEnableLightClient: (BOOL)enableLightClient {
    [_dataStore setBool:enableLightClient forKey:DataStoreKeyUserEnableLightClient];
    [self setupProvider:YES];
}

- (void)debugSetEnableFallback: (BOOL)enableFallback {
    [_dataStore setBool:!enableFallback forKey:DataStoreKeyUserDisableFallback];
    [self setupProvider:YES];
}

- (void)debugSetTestnet: (BOOL)testnet {
    [_dataStore setBool:testnet forKey:DataStoreKeyUserEnableTestnet];
    [self setupProvider:YES];
}


#pragma mark - Index operations

- (NSUInteger)numberOfAccounts {
    return [_orderedAddresses count];
}

- (void)notifyReorderedAccounts {
    dispatch_async(dispatch_get_main_queue(), ^() {
        [[NSNotificationCenter defaultCenter] postNotificationName:WalletReorderedAccountsNotification
                                                            object:self
                                                          userInfo:@{}];
    });
}

- (void)exchangeAccountAtIndex: (NSUInteger)fromIndex withIndex: (NSUInteger)toIndex {
    [_orderedAddresses exchangeObjectAtIndex:fromIndex withObjectAtIndex:toIndex];
    
    [self saveAccountOrder];
    
    [self notifyReorderedAccounts];
}

- (void)moveAccountAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if (fromIndex == toIndex)  { return; }
    
    Address *address = [_orderedAddresses objectAtIndex:fromIndex];
    [_orderedAddresses removeObjectAtIndex:fromIndex];
    [_orderedAddresses insertObject:address atIndex:toIndex];
    
    [self saveAccountOrder];

    [self notifyReorderedAccounts];
}

- (Address*)addressAtIndex: (NSUInteger)index {
    return [_orderedAddresses objectAtIndex:index];
}

- (NSUInteger)indexForAddress: (Address*)address {
    return [_orderedAddresses indexOfObject:address];
}


#pragma mark - User Interface

- (void)updateEtherPriceLabel {
    NSLog(@"Ether Price: $%.02f/ether", self.etherPrice);
    _etherPriceLabel.text = [NSString stringWithFormat:@"$%.02f\u2009/\u2009ether", self.etherPrice];
}


#pragma mark Root-Level Screens

- (void)addAccountCallback:(void (^)(Address *))callback {
    
    void (^completionCallback)(NSObject*) = ^(NSObject *result) {
        if ([result isKindOfClass:[Account class]]) {
            callback(((Account*)result).address);
        } else {
            callback(nil);
        }
        
    };
    
    InfoNavigationController *navigationController = [InfoViewController rootInfoViewControllerWithCompletionCallback:completionCallback];
    
    navigationController.rootInfoViewController.setupView = ^(InfoViewController *info) {
        [info addFlexibleGap];
        [info addText:ICON_NAME_LOGO font:[UIFont fontWithName:FONT_ETHERS size:100.0f]];
        [info addText:@"How would you like to add an account?" fontSize:17.0f];
        [info addFlexibleGap];
        [info addFlexibleGap];
        [info addButton:@"Create New Account" action:^() {
            [self infoCreateAccount:navigationController];
        }];
        [info addButton:@"Import Existing Account" action:^() {
            [self infoImportAccount:navigationController];
        }];
        [info addGap:44.0f];
    };
    
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}


- (void)manageAccount:(Address *)address callback:(void (^)())callback {
    
    void (^completionCallback)(NSObject*) = ^(NSObject *result) {
        if (callback) {
            callback();
        }
    };
    
    InfoNavigationController *navigationController = [InfoViewController rootInfoViewControllerWithCompletionCallback:completionCallback];

    navigationController.rootInfoViewController.setupView = ^(InfoViewController *info) {
        [info addFlexibleGap];
        
        [info addHeadingText:@"Manage Account"];
        
        [info addText:[self nicknameForAccount:address] font:[UIFont fontWithName:FONT_ITALIC size:17.0f]];
        
        [info addFlexibleGap];
        [info addFlexibleGap];
        
        [info addButton:@"View Backup Phrase" action:^() {
            [self infoViewAccount:navigationController address:address];
        }];
        
        [info addButton:@"Delete Account" action:^() {
            [self infoRemoveAccount:navigationController address:address];
        }];
        
        [info addGap:44.0f];
        
        info.navigationItem.titleView = [Utilities navigationBarLogoTitle];
    };
    
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}


- (void)sendPayment:(Payment *)payment callback:(void (^)(Hash*, NSError*))callback {
    Transaction *transaction = [Transaction transaction];
    transaction.toAddress = payment.address;
    transaction.value = payment.amount;

    [self sendTransaction:transaction firm:payment.firm callback:callback];
}

- (void)sendTransaction: (Transaction*)transaction callback:(void (^)(Hash*, NSError*))callback {
    [self sendTransaction:transaction firm:YES callback:callback];
}

- (void)sendTransaction: (Transaction*)transaction firm: (BOOL)firm callback:(void (^)(Hash*, NSError*))callback {
    Address *activeAccount = _activeAccount;
    
    if (!transaction.gasLimit) {
        transaction.gasLimit = [BigNumber bigNumberWithDecimalString:@"1000000"];
    }
   
    if (!transaction.gasPrice) {
        transaction.gasPrice = self.gasPrice;
    }
    
    if (!transaction.value) {
        transaction.value = [BigNumber constantZero];
    }
    
    transaction.nonce = [self nonceForAddress:activeAccount];
    transaction.chainId = (_provider.testnet ? CHAIN_ID_ROPSTEN: CHAIN_ID_HOMESTEAD);

    NSLog(@"Transaction: %@", transaction);

    __block NSError *completionError = nil;
    
    void (^completionCallback)(NSObject*) = ^(NSObject *result) {
        if (!callback) { return; }
        
        if (result) {
            callback((Hash*)result, nil);
       
        } else {
            if (completionError) {
                callback(nil, completionError);
            } else {
                callback(nil, [NSError errorWithDomain:WalletErrorDomain code:kWalletErrorSendCancelled userInfo:@{}]);
            }
        }
    };
    
    InfoNavigationController *navigationController = [InfoViewController rootInfoViewControllerWithCompletionCallback:completionCallback];
    
    navigationController.rootInfoViewController.setupView = ^(InfoViewController *info) {
        __block Account* (^getAccount)(NSString*) = nil;
        
        [info addGap:44.0f];
        [info addHeadingText:@"Send Payment"];
        [info addText:[self nicknameForAccount:activeAccount] font:[UIFont fontWithName:FONT_ITALIC size:17.0f]];
        [info addFlexibleGap];
        [info addSeparator:0.5f];
        UILabel *toLabel = [info addLabel:@"To" value:transaction.toAddress.checksumAddress];
        [info addSeparator:0.5f];
        BlockTextField *amountTextField = [info addTextEntry:@"Amount" callback:^(BlockTextField *textField) { }];
        [info addSeparator:0.5f];
        UITextView *feeTextView = [info addText:@"(estimating fee...)" font:[UIFont fontWithName:FONT_ITALIC size:12.0f]];
        [info addFlexibleGap];
        [info addSeparator:0.5f];
        BlockTextField *passwordTextField = [info addPasswordEntryCallback:^(BlockTextField *textField) { }];
        [info addSeparator:0.5f];
        [info addFlexibleGap];
        UIButton *buttonSend = [info addButton:@"Send Payment" action:^() {
            NSLog(@"Sending: account=%@ tx=%@", [_accounts objectForKey:activeAccount], transaction);
            [[_accounts objectForKey:activeAccount] sign:transaction];
            NSData *signedTransaction = [transaction serialize];
            NSLog(@"Signed: %@", signedTransaction);
            [[_provider sendTransaction:signedTransaction] onCompletion:^(HashPromise *promise) {
                NSLog(@"Sent Transaction: %@ %@ %@", promise.result, promise.value, promise.error);
                if (promise.error) {
                    NSDictionary *userInfo = @{ @"reason": [promise.error description] };
                    completionError = [NSError errorWithDomain:WalletErrorDomain
                                                          code:kWalletErrorUnknown
                                                      userInfo:userInfo];
                } else {
                    TransactionInfo *transactionInfo = [TransactionInfo transactionInfoWithPendingTransaction:transaction hash:promise.value];
//                    NSLog(@"Add TX: %@", transactionInfo);
                    [self addTransactionInfos:@[transactionInfo] address:activeAccount];
                    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer *timer) {
                        [self refresh:nil];
                    }];
                }
                [navigationController dismissWithResult:promise.value];
            }];
        }];
        [info addGap:44.0f];
        
        Account *account = [_accounts objectForKey:activeAccount];
        if (account) {

            LAContext *context = [[LAContext alloc] init];
            NSError *error = nil;
            
            BOOL fingerprintReady = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
            
            if (error) {
                NSLog(@"Error: %@", error);
                fingerprintReady = NO;
            }
            
            if (fingerprintReady) {
                void (^acceptFingerprint)() = ^() {
                    info.nextEnabled = NO;
                    passwordTextField.userInteractionEnabled = NO;

                    passwordTextField.text = @"password";
                    passwordTextField.status = BlockTextFieldStatusGood;

                    buttonSend.enabled = YES;
                    
                };
                
                void (^rejectFingerprint)() = ^() {
                    info.nextEnabled = NO;
                    [passwordTextField pulse];
                };
                
                [info setNextIcon:ICON_NAME_FINGERPRINT action:^() {
                    if (amountTextField.isFirstResponder) { [amountTextField resignFirstResponder]; }
                    if (passwordTextField.isFirstResponder) { [passwordTextField resignFirstResponder]; }
                    
                    void (^handleFingerprintReply)(BOOL, NSError*) = ^(BOOL success, NSError *error) {
                        // Fingerprint was good
                        if (success) {
                            dispatch_async(dispatch_get_main_queue(), ^() {
                                acceptFingerprint();
                            });
                            
                        } else {
                            NSLog(@"Error1: %@", error);
                            
                            switch (error.code) {
                                    // Cases we need to verify by asking the user
                                case kLAErrorTouchIDNotEnrolled:
                                case kLAErrorPasscodeNotSet:
                                case kLAErrorTouchIDNotAvailable:
                                case kLAErrorTouchIDLockout:
                                case kLAErrorUserFallback: {
                                    dispatch_async(dispatch_get_main_queue(), ^() {
                                        rejectFingerprint();
                                    });
                                    break;
                                }
                                    
                                    // Cases where we have failed outright, but acceptably so
                                case kLAErrorSystemCancel:
                                case kLAErrorUserCancel: {
                                    
//                                    dispatch_async(dispatch_get_main_queue(), ^() {
//                                        callback(nil);
//                                    });
                                    break;
                                }
                                    
                                    // Cases where we have failed, but maybe for not a happy reason
                                case kLAErrorAuthenticationFailed:
                                default: {
                                    // @TODO: Show an error
                                    dispatch_async(dispatch_get_main_queue(), ^() {
                                        rejectFingerprint();
                                    });
                                    break;
                                }
                            }
                            
                        }
                    };
                    NSString *reason = [NSString stringWithFormat:@"Unlock account:\n%@", [self nicknameForAccount:activeAccount]];
                    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                                localizedReason:reason
                                            reply:handleFingerprintReply];
                }];
                info.nextEnabled = YES;
            }
        }
        
        info.navigationItem.titleView = [Utilities navigationBarLogoTitle];
        
        UIView *inputView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, info.view.frame.size.width, 44.0f)];
        inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        {
            UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:inputView.bounds];
            toolbar.items = @[
                              [[UIBarButtonItem alloc] initWithCustomView:_etherPriceLabel],
                              [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil],
                              [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                            target:amountTextField
                                                                            action:@selector(resignFirstResponder)],
                              ];
            [inputView addSubview:toolbar];
            
            UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 43.5f, inputView.frame.size.width, 0.5f)];
            separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            separator.backgroundColor = [UIColor colorWithWhite:0.8f alpha:1.0f];
            [inputView addSubview:separator];
        }

        toLabel.font = [UIFont fontWithName:FONT_MONOSPACE_SMALL size:14.0f];
        toLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        
        amountTextField.didBeginEditing = ^(BlockTextField *textField) {
            // Trim off the units
            if ([textField.text hasPrefix:@"Ξ\u2009"]) {
                textField.text = [textField.text substringFromIndex:2];
            }
            
            // If there is no meaningful amount, clear the whole field
            if ([[Payment parseEther:textField.text] isEqual:[BigNumber constantZero]]) {
                textField.text = @"";
            }
        };
        amountTextField.didChangeText = ^(BlockTextField *textField) {
            NSLog(@"Changed: %@", textField.text);
            transaction.value = [Payment parseEther:textField.text];
        };
        amountTextField.didEndEditing = ^(BlockTextField *textField) {
            BigNumber *value = [Payment parseEther:textField.text];
            if (!value) { value = [BigNumber constantZero]; }
            textField.text = [@"Ξ\u2009" stringByAppendingString:[Payment formatEther:value]];
        };
        amountTextField.inputAccessoryView = inputView;
        amountTextField.keyboardType = UIKeyboardTypeDecimalPad;
        amountTextField.text = [@"Ξ\u2009" stringByAppendingString:[Payment formatEther:transaction.value]];
        amountTextField.shouldChangeText = ^BOOL(BlockTextField *textField, NSRange range, NSString *string) {
            NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
            
            return (newText.length == 0 || [newText isEqualToString:@"."] || [Payment parseEther:newText] != nil);
        };
        amountTextField.shouldReturn = ^BOOL(BlockTextField *textField) {
            if (passwordTextField.userInteractionEnabled) {
                [passwordTextField becomeFirstResponder];
            } else {
                [textField resignFirstResponder];
            }
            return YES;
        };
        
        if (firm) {
            amountTextField.userInteractionEnabled = NO;
        }
        
        BigNumberPromise *estimateGasPromise = [_provider estimateGas:transaction];
        [estimateGasPromise onCompletion:^(BigNumberPromise *promise) {
            NSLog(@"Estimate: %@ %@", promise.value, promise.error);
            if (promise.error) { return; }
            NSString *feeEther = [Payment formatEther:[promise.value mul:self.gasPrice]
                                              options:(EtherFormatOptionCommify | EtherFormatOptionApproximate)];
            feeTextView.text = [NSString stringWithFormat:@"(estimated fee: Ξ\u2009%@)", feeEther];
        }];

        
        getAccount = [self setupCheckAddress:activeAccount passwordTextField:passwordTextField];
        
        passwordTextField.didChangeText = ^(BlockTextField *textField) {
            if (textField.shouldReturn(textField)) {
                Account *account = getAccount(textField.text);
                [_accounts setObject:account forKey:account.address];

                // Stop typing
                if ([textField isFirstResponder]) {
                    [textField resignFirstResponder];
                }
                
                // Allow sending
                buttonSend.enabled = YES;
                
                // Valid password; no need for Touch ID or any more typing
                info.nextEnabled = NO;
                textField.userInteractionEnabled = NO;
            
            } else {
                
                // Wrong password; Allow Touch ID
                info.nextEnabled = YES;
            }
        };

        buttonSend.enabled = NO;

    };
    
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}


- (void)showDebuggingOptionsCallback: (void (^)())callback {
    
    void (^completionCallback)(NSObject*) = ^(NSObject *result) {
        if (callback) { callback(); }
    };

    InfoNavigationController *navigationController = [InfoViewController rootInfoViewControllerWithCompletionCallback:completionCallback];
    
    navigationController.rootInfoViewController.setupView = ^(InfoViewController *info) {
        [info addGap:44.0f];
        [info addHeadingText:@"Debug Options"];
        [info addGap:10.0f];
        [info addMarkdown:@"This page is mainly for developers working on //Ethereum// projects. If you are here by accident, tap Done." fontSize:15.0f];
        [info addFlexibleGap];
        [info addGap:44.0f];
        [info addSeparator:0.5f];
        UISwitch *testnetToggle = [info addToggle:@"Test Network" callback:^(BOOL value) {
            [self debugSetTestnet:value];
        }];
        [info addSeparator:0.5f];
        [info addNoteText:@"The testnet network is only for devopers. Only enable this if you know what you are doing."];
        [info addGap:44.0f];
        [info addSeparator:0.5f];
        UISwitch *lightClientToggle = [info addToggle:@"Light Client" callback:^(BOOL value) {
            [self debugSetEnableLightClient:value];
        }];
        [info addSeparator:0.5f];
        BlockTextField *customNodeTextField = [info addTextEntry:@"Custom Node" callback:^(BlockTextField *textField) {
            if ([textField isFirstResponder]) { [textField resignFirstResponder]; }
        }];
        [info addSeparator:0.5f];
        UISwitch *fallbackToggle = [info addToggle:@"Etherscan Fallback" callback:^(BOOL value) {
            [self debugSetEnableFallback:value];
        }];
        [info addSeparator:0.5f];
        [info addNoteText:@"The light client is highly experimental. If no providers are selected, Etherscan is used."];
        [info addGap:44.0f];
        [info addFlexibleGap];
        
        // Disable for now... The light client still has a long way to go.
        lightClientToggle.enabled = NO;
        
        customNodeTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        customNodeTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        customNodeTextField.keyboardType = UIKeyboardTypeURL;
        customNodeTextField.placeholder = @"e.g. https://127.0.0.1:8545";
        customNodeTextField.returnKeyType = UIReturnKeyDone;
        customNodeTextField.textContentType = UITextContentTypeURL;

        customNodeTextField.shouldReturn = ^BOOL(BlockTextField *textField) {
            return YES;
        };
        
        __block NSTimer *typingTimer = nil;
        
        customNodeTextField.didChangeText = ^(BlockTextField *textField) {
            if (typingTimer) {
                [typingTimer invalidate];
                typingTimer = nil;
            }
            
            NSString *customNode = textField.text;
            
            if (customNode.length == 0) {
                textField.status = BlockTextFieldStatusNone;
                return;
            }
            
            textField.status = BlockTextFieldStatusSpinning;
            typingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer *timer) {
                if (timer != typingTimer) { return; }
                
                BOOL enableTestnet = [_dataStore boolForKey:DataStoreKeyUserEnableTestnet];
                
                Provider *provider = [[JsonRpcProvider alloc] initWithTestnet:enableTestnet url:[NSURL URLWithString:customNode]];
                [[provider getBlockNumber] onCompletion:^(IntegerPromise *promise) {
                    NSLog(@"Test Network: %@", promise);
                    if (promise.result && [textField.text isEqualToString:customNode]) {
                        textField.status = BlockTextFieldStatusGood;
                        [self debugSetCustomNode:customNode];
                        
                    } else {
                        textField.status = BlockTextFieldStatusBad;
                    }
                }];
            }];
        };
        
        info.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                              target:navigationController
                                                                                              action:@selector(dismissWithNil)];
        
        testnetToggle.on = [_dataStore boolForKey:DataStoreKeyUserEnableTestnet];
        lightClientToggle.on = [_dataStore boolForKey:DataStoreKeyUserEnableLightClient];
        fallbackToggle.on = ![_dataStore boolForKey:DataStoreKeyUserDisableFallback];
    };

    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}


#pragma mark Workflow Start Screens

- (void)infoCreateAccount: (InfoNavigationController*)navigationController {
    
    Account *account = [Account randomMnemonicAccount];
    
    // Step 2: Show the mnemonic
    void (^showMnemonic)() = ^() {
        
        // Step 3: Verify the mnemonic
        void (^verifyMnemonic)() = ^() {
            
            // Step 4 & 5: Get then verify a password
            void (^getPassword)(NSString*) = ^(NSString *mnemonicPhrase) {

                // Step 6: Encrypt and save the account
                void (^encryptAccount)(NSString*) = ^(NSString *password) {
                    [self infoComplete:navigationController account:account password:password];
                };
                
                [self infoGetAndConfirmPassword:navigationController callback:encryptAccount];
            };

            BOOL (^checkMnemonic)(NSString*) = ^BOOL(NSString *mnemonicPhrase) {
                if ((DEBUG_SKIP_VERIFY_MNEMONIC)) {
                    return YES;
                }
                return [mnemonicPhrase isEqualToString:account.mnemonicPhrase];
            };

            [self infoGetMnemonic:navigationController
                            title:@"Verify Backup Phrase"
                          message:@"Please verify you have written your backup phrase correctly."
              checkMnemonicPhrase:checkMnemonic
                         callback:getPassword];
        };
        
        void (^setup)(InfoViewController*) = ^(InfoViewController *info) {
            [info setNextTitle:@"Next" action:verifyMnemonic];
        };
        
        [self infoShowMnemonic:navigationController
                 setupCallback:setup
                       message:@"Write this down and store it somewhere **safe**."
                          note:@"//You will need to enter this phrase on the next screen.//"
                      mnemonic:account.mnemonicPhrase];
    };
    
    NSArray *messages = @[
                          @"Your account backup is a 12 word phrase.",
                          @"You **must** write it down and store it somewhere **safe**.",
                          @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                          @"**KEEP IT SAFE**"
                          ];
    
    void (^setup)(InfoViewController*) = ^(InfoViewController *info) {
        [info setNextTitle:@"I Agree" action:showMnemonic];
    };
    
    // Step 1: Agree to warning
    [self infoMnemonicWarning:navigationController
                setupCallback:setup
                        title:@"Account Backup"
                     messages:messages
                         note:@"//Tap \"I Agree\" to see your backup phrase.//"];
    
    navigationController.totalSteps = 6;
}

- (void)infoImportAccount: (InfoNavigationController*)navigationController {

    // Step 2: Enter the mnemonic
    void (^getMnemonic)() = ^() {
        
        // Step 3 & 4: Get and verify a password
        void (^getPassword)(NSString*) = ^(NSString *mnemonicPhrase) {
            
            // Step 5: Encrypt and save the account
            void (^encryptAccount)(NSString*) = ^(NSString *password) {
                Account *account = [Account accountWithMnemonicPhrase:mnemonicPhrase];
                [self infoComplete:navigationController account:account password:password];
            };

            [self infoGetAndConfirmPassword:navigationController
                                   callback:encryptAccount];
        };

        BOOL (^checkMnemonic)(NSString*) = ^BOOL(NSString *mnemonicPhrase) {
            return [Account isValidMnemonicPhrase:mnemonicPhrase];
        };

        [self infoGetMnemonic:navigationController
                        title:@"Enter Phrase"
                      message:@"Please enter your //backup phrase//."
          checkMnemonicPhrase:checkMnemonic
                     callback:getPassword];
    };
    
    NSArray *messages = @[
                          @"Your account backup is a 12 word phrase.",
                          @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                          @"**KEEP IT SAFE**"
                          ];

    void (^setup)(InfoViewController*) = ^(InfoViewController *info) {
        [info setNextTitle:@"I Agree" action:getMnemonic];
    };
    
    // Step 1: Agree to warning
    [self infoMnemonicWarning:navigationController
                setupCallback:setup
                        title:@"Import Account"
                     messages:messages
                         note:@"//Tap \"I Agree\" to enter your backup phrase.//"];
    
    navigationController.totalSteps = 5;
}

- (void)infoViewAccount: (InfoNavigationController*)navigationController
                address: (Address*)address {
    
    // Step 2: Agree to warning
    void (^showWarning)(Account*) = ^(Account *account) {
        
        // Step 3: Show mnemonic
        void (^showMnemonic)() = ^() {
            
            void (^setup)(InfoViewController*) = ^(InfoViewController *info) {
                info.navigationItem.hidesBackButton = YES;

                [info setNextTitle:@"Done" action:^() {
                    [navigationController dismissWithResult:nil];
                }];
            };
            
            [self infoShowMnemonic:navigationController
                     setupCallback:setup
                           message:@"Here is your //backup phrase//. Keep it **safe**."
                              note:@""
                          mnemonic:account.mnemonicPhrase];
        };
        
        NSArray *messages = @[
                              @"Your account backup is a 12 word phrase.",
                              @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                              @"**KEEP IT SAFE**"
                              ];
        
        void (^setup)(InfoViewController*) = ^(InfoViewController *info) {
            [info setNextTitle:@"I Agree" action:showMnemonic];
        };
        
        [self infoMnemonicWarning:navigationController
                    setupCallback:setup
                            title:@"View Backup Phrase"
                         messages:messages
                             note:@"//Tap \"I Agree\" to see your backup phrase.//"];

    };
    
    // Step 1: Unlock account with password
    [self infoCheckPassword:navigationController
                    message:@">You must unlock your account to view your backup phrase."
                    address:address
                   callback:showWarning];
    
    navigationController.totalSteps = 3;
}

- (void)infoRemoveAccount: (InfoNavigationController*)navigationController
                  address: (Address*)address {
    
    // Step 2: Agree to warning
    void (^showWarning)(Account*) = ^(Account *account) {
        
        // Step 3: Get mnemonic
        void (^getMnemonic)() = ^() {
            
            // Step 4: Confirm
            void (^confirmDelete)() = ^() {
                InfoViewController *info = [[InfoViewController alloc] init];
                info.setupView = ^(InfoViewController *info) {
                    [info addFlexibleGap];

                    [info addHeadingText:@"Delete Account?"];
                    
                    [info addText:[self nicknameForAccount:address] font:[UIFont fontWithName:FONT_ITALIC size:17.0f]];

                    [info addGap:64.0f];
                    [info addMarkdown:@"This account will be deleted from all your devices." fontSize:17.0f];
                    [info addMarkdown:@"You will need to use your //backup phrase// to restore this account." fontSize:17.0f];

                    [info addFlexibleGap];
                    [info addFlexibleGap];
                    
                    [info addButton:@"Cancel" action:^() {
                        [navigationController dismissWithResult:nil];
                    }];
                    
                    [info addGap:44.0f];
                    
                    [info setNextTitle:@"Delete" action:^() {
                        [self removeAccount:account];
                        [navigationController dismissWithResult:@(YES)];
                    }];
                    
                    [NSTimer scheduledTimerWithTimeInterval:2.0f repeats:NO block:^(NSTimer *timer) {
                        info.nextEnabled = YES;
                    }];
                };
                
                [navigationController pushViewController:info animated:YES];
            };
            
            BOOL (^checkMnemonic)(NSString*) = ^BOOL(NSString *mnemonicPhrase) {
                if ((DEBUG_SKIP_VERIFY_MNEMONIC)) {
                    return YES;
                }
                return ([mnemonicPhrase isEqualToString:account.mnemonicPhrase]);
            };
            
            [self infoGetMnemonic:navigationController
                            title:@"Verify Backup Phrase"
                          message:@"You must verify you have written your //backup phrase// correctly."
              checkMnemonicPhrase:checkMnemonic
                         callback:confirmDelete];
        };
        
        NSArray *messages = @[
                              @"Your account backup is a 12 word phrase.",
                              @"Anyone who steals this phrase can steal your //ether//. Without it your account **cannot** be restored.",
                              @"**KEEP A COPY SOMEWHERE SAFE**"
                              ];
        
        void (^setup)(InfoViewController*) = ^(InfoViewController *info) {
            [info setNextTitle:@"I Agree" action:getMnemonic];
        };
        
        [self infoMnemonicWarning:navigationController
                    setupCallback:setup
                            title:@"Verify Backup Phrase"
                         messages:messages
                             note:@"//Tap \"I Agree\" to enter your backup phrase.//"];
        
    };

    // Step 1: Unlock account with password
    [self infoCheckPassword:navigationController
                    message:@"You must unlock your account to delete it. This account will be removed from **all** your devices."
                    address:address
                   callback:showWarning];

    navigationController.totalSteps = 4;
}



#pragma mark Sub Info Screens

- (void)infoMnemonicWarning: (InfoNavigationController*)navigationController
              setupCallback: (void (^)(InfoViewController*))setupCallback
                      title: (NSString*)title
                   messages: (NSArray<NSString*>*)messages
                       note: (NSString*)note {
    
    InfoViewController *info = [[InfoViewController alloc] init];
    info.setupView = ^(InfoViewController *info) {
        [info addGap:15.0f];
        
        [info addHeadingText:title];
        
        [info addGap:20.0f];
        
        for (NSString *message in messages) {
            [info addMarkdown:message fontSize:15.0f];
        }
        
        [info addFlexibleGap];
        
        [info addMarkdown:@"When viewing your //backup phrase//, **watch for**:" fontSize:15.0f];
        
        [info addGap:15.0f];
        
        [info addViews:@[
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_SECURITY_CAMERA topTitle:@"SECURITY" bottomTitle:@"CAMERAS"],
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_PRIVACY topTitle:@"NEARBY" bottomTitle:@"OBSERVERS"],
                         ]];
        
        [info addFlexibleGap];
        
        [info addMarkdown:note fontSize:15.0f];
        
        [info addGap:15.0f];
        
        [NSTimer scheduledTimerWithTimeInterval:2.0f repeats:NO block:^(NSTimer *timer) {
            info.nextEnabled = YES;
        }];
        
        setupCallback(info);
    };
    
    [navigationController pushViewController:info animated:YES];
}

- (void)infoShowMnemonic: (InfoNavigationController*)navigationController
           setupCallback: (void (^)(InfoViewController*))setupCallback
                 message: (NSString*)message
                    note: (NSString*)note
                mnemonic: (NSString*)mnemonicPhrase {
    
    InfoViewController *info = [[InfoViewController alloc] init];
    info.setupView = ^(InfoViewController *info) {
        [info addGap:44.0f];
        [info addHeadingText:@"Your Backup Phrase"];
        [info addGap:20.0f];
        [info addMarkdown:message fontSize:15.0f];
        
        [info addFlexibleGap];
        
        BlockMnemonicPhraseView *mnemonicPhraseView = [info addMnemonicPhraseView];
        mnemonicPhraseView.mnemonicPhrase = mnemonicPhrase;
        
        [info addFlexibleGap];
        
        [info addMarkdown:note fontSize:15.0f];
        [info addGap:15.0f];

        info.nextEnabled = YES;
        
        setupCallback(info);
//        [info setNextTitle:nextTitle action:callback];
//        if ([nextTitle isEqualToString:@"Done"]) {
//            info.navigationItem.hidesBackButton = YES;
//        }
    };
    
    [navigationController pushViewController:info animated:YES];
}


- (void)infoGetMnemonic: (InfoNavigationController*)navigationController
                  title: (NSString*)title
                message: (NSString*)message
    checkMnemonicPhrase: (BOOL (^)(NSString*))checkMnemonicPhrase
               callback: (void (^)())callback {
    
    InfoViewController *info = [[InfoViewController alloc] init];
    info.setupView = ^(InfoViewController *info) {
        [info addGap:44.0f];
        [info addHeadingText:title];
        [info addGap:20.0f];
        [info addMarkdown:message fontSize:15.0f];
        
        [info addFlexibleGap];
        
        [info addGap:15.0f];
        BlockMnemonicPhraseView *mnemonicPhraseView = [info addMnemonicPhraseView];
        [info addGap:15.0f];
        
        [info addFlexibleGap];
        
        mnemonicPhraseView.didChangeMnemonic = ^(BlockMnemonicPhraseView *mnemonicPhraseView) {
            info.nextEnabled = checkMnemonicPhrase(mnemonicPhraseView.mnemonicPhrase);
        };
        
        [info setNextTitle:@"Next" action:^() {
            [mnemonicPhraseView resignFirstResponder];
            callback(mnemonicPhraseView.mnemonicPhrase);
        }];
        
        [mnemonicPhraseView becomeFirstResponder];
    };
    
    [navigationController pushViewController:info animated:YES];
}


- (void)infoGetPassword: (InfoNavigationController*)navigationController
          setupCallback: (void (^)(BlockTextField*))setupCallback
                  title: (NSString*)title
                message: (NSString*)message
                   note: (NSString*)note
               callback: (void (^)(NSString*))callback {
    
    InfoViewController *info = [[InfoViewController alloc] init];
    
    void (^tapNext)(NSString*) = ^(NSString *password) {
        callback(password);
    };
    
    info.setupView = ^(InfoViewController *info) {
        [info addFlexibleGap];
        [info addHeadingText:title];
        [info addGap:20.0f];
        [info addMarkdown:message fontSize:15.0f];
        [info addFlexibleGap];
        [info addSeparator:0.5f];
        BlockTextField *textField = [info addPasswordEntryCallback:^(BlockTextField *textField) {
            tapNext(textField.text);
        }];
        [info addSeparator:0.5f];
        
        // optionally add a note
        if (note.length > 0) {
            [info addGap:7.0f];
            UITextView *noteTextView = [info addText:note fontSize:12.0f];
            noteTextView.alpha = 0.7f;
        }
        
        // @TODO: Add a flexible-like gap for keyboards
        [info addFlexibleGap];
        [info addFlexibleGap];
        [info addFlexibleGap];
        [info addFlexibleGap];
        
        // Tapping next should submit the password
        [info setNextTitle:@"Next" action:^() {
            tapNext(textField.text);
        }];
        
//        textField.shouldReturn = shouldReturn;
        
        // Typing the return key should submit (if allowed)
        textField.didChangeText = ^(BlockTextField *textField) {
            info.nextEnabled = textField.shouldReturn(textField);
        };
        
        setupCallback(textField);
        
        [textField becomeFirstResponder];
    };
    
    [navigationController pushViewController:info animated:YES];
}


- (void)infoGetAndConfirmPassword: (InfoNavigationController*)navigationController
                         callback: (void (^)(NSString*))callback {

    void (^confirmPassword)(NSString*) = ^(NSString *password) {
        void (^setup)(BlockTextField*) = ^(BlockTextField *textField) {
            textField.shouldReturn = ^BOOL(BlockTextField *textField) {
                return [textField.text isEqualToString:password];
            };
        };

        [self infoGetPassword:navigationController
                setupCallback:setup
                        title:@"Confirm Password"
                      message:@"Enter the same password again."
                         note:@""
                     callback:callback];
    };

    void (^setup)(BlockTextField*) = ^(BlockTextField *textField) {
        textField.shouldReturn = ^BOOL(BlockTextField *textField) {
            return (textField.text.length >= MIN_PASSWORD_LENGTH);
        };
    };
    
    [self infoGetPassword:navigationController
            setupCallback:setup
                    title:@"Choose a Password"
                  message:@">Enter a password to encrypt this account on this device."
                     note:[NSString stringWithFormat:@"Password must be %d characters or longer.", MIN_PASSWORD_LENGTH]
                 callback:confirmPassword];
}

- (Account*(^)(NSString*))setupCheckAddress: (Address*)address passwordTextField: (BlockTextField*)textField {
    
    NSString *json = [self getJSON:address];
    
    // Map address to @{@"account": accountOrNil, @"error": errorOrNil} for caching
    // scrypt kdf results
    NSMutableDictionary *passwordToAccount = [NSMutableDictionary dictionaryWithCapacity:16];
    
    __block Cancellable *cancellable = nil;
    
    BOOL (^shouldReturn)(BlockTextField*) = ^BOOL(BlockTextField *textField) {
        if (cancellable) {
            [cancellable cancel];
            cancellable = nil;
        }
        
        NSString *password = textField.text;
        
        NSString *cacheKey = [[[SecureData secureDataWithData:[password dataUsingEncoding:NSUTF8StringEncoding]] KECCAK256] hexString];
        
        // Check for a cached result
        NSDictionary *cacheHit = [passwordToAccount objectForKey:cacheKey];
        if (cacheHit) {
            Account *possibleAccount = [cacheHit objectForKey:@"account"];
            NSError *error = [cacheHit objectForKey:@"error"];
            BOOL valid = (possibleAccount && !error);
            [textField setStatus:(valid ? BlockTextFieldStatusGood: BlockTextFieldStatusBad) animated:YES];
            return valid;
        }
        
        if ([password isEqualToString:@""]) {
            textField.status = BlockTextFieldStatusNone;
        } else {
            [textField setStatus:BlockTextFieldStatusSpinning animated:YES];
        }
        
        // Start derivation...
        NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
        cancellable = [Account decryptSecretStorageJSON:json password:password callback:^(Account *account, NSError *error) {
            
            // We have an account, so the password was correct
            if (account) {
                NSLog(@"decrypted: %@ dt=%f", account.address, [NSDate timeIntervalSinceReferenceDate] - t0);
                [passwordToAccount setObject:@{@"account": account} forKey:cacheKey];
                
                // Trigger checking for return in the near future (which will enable the "next" button)
                dispatch_async(dispatch_get_main_queue(), ^() {
                    textField.didChangeText(textField);
                });
                
            } else if (error.code != kAccountErrorCancelled) {
                if (error.code != kAccountErrorWrongPassword) {
                    NSLog(@"Decryption error: %@", error);
                }
                
                // @TODO: What if the JSON is bad? We shouldn't have imported it in the irst palce...
                
                // @TODO: Really should evict entries from the cache... (any random() non-account valued key)
                
                // Cache the result (we do not cache cancelled reuests)
                [passwordToAccount setObject:@{@"error": error} forKey:cacheKey];
                
                // Trigger checking for return in the near future (which will cache hit an error and set the textfield status)
                dispatch_async(dispatch_get_main_queue(), ^() {
                    textField.didChangeText(textField);
                });
            }
        }];
        
        return NO;
    };

    textField.shouldReturn = shouldReturn;

    Account* (^sendAccount)(NSString*) = ^Account*(NSString *password) {
        NSString *cacheKey = [[[SecureData secureDataWithData:[password dataUsingEncoding:NSUTF8StringEncoding]] KECCAK256] hexString];
        return [[passwordToAccount objectForKey:cacheKey] objectForKey:@"account"];
    };
    
    return sendAccount;
}

- (void)infoCheckPassword: (InfoNavigationController*)navigationController
                  message: (NSString*)message
                  address: (Address*)address
                 callback: (void (^)(Account*))callback {
    
    __block Account* (^getAccount)(NSString*) = nil;
    void (^setup)(BlockTextField*) = ^(BlockTextField *textField) {
        getAccount = [self setupCheckAddress:address passwordTextField:textField];
    };
    
    void (^sendAccount)(NSString*) = ^(NSString *password) {
        Account *account = getAccount(password);
        callback(account);
    };
    
    [self infoGetPassword:navigationController
            setupCallback:setup
                    title:@"Enter Your Password"
                  message:message
                     note:@""
                 callback:sendAccount];
}


- (void)infoComplete: (InfoNavigationController*)navigationController
             account: (Account*)account
            password: (NSString*)password {
    NSLog(@"Complete: %@", account);
    
    InfoViewController *info = [[InfoViewController alloc] init];
    info.setupView = ^(InfoViewController *info) {
        [info addFlexibleGap];
        UITextView *headerEncrypting = [info addHeadingText:@"Encrypting..."];
        
        [info addGap:20.0f];
        
        UITextView *message = [info addMarkdown:@"One moment please." fontSize:15.0f];
        
        [info addFlexibleGap];
        
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        activityView.frame = CGRectMake(0.0f, 0.0f, info.view.frame.size.width, 44.0f);
        [activityView startAnimating];
        [info addView:activityView];
        
        [info addFlexibleGap];
        
        CGFloat top = [info addMarkdown:@"When protecting important data, such as your //backup phrase//, consider:" fontSize:15.0f].frame.origin.y;
        [info addGap:15.0f];
        [info addViews:@[
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_FIRES topTitle:@"" bottomTitle:@"FIRES"],
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_FLOODS topTitle:@"" bottomTitle:@"FLOODS"],
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_DAMAGE topTitle:@"" bottomTitle:@"DAMAGE"],
                         ]];
        [info addGap:15.0f];
        [info addViews:@[
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_LOSS topTitle:@"" bottomTitle:@"LOSS"],
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_THEFT topTitle:@"" bottomTitle:@"THEFT"],
                         [InfoIconView infoIconViewWithIcon:ICON_NAME_FAILURE topTitle:@"" bottomTitle:@"FAILURE"],
                         ]];
        
        [info addFlexibleGap];
        
        // HACK! This allows us to slide in a replacement header
        UILabel *headerDone = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 44.0f, info.view.frame.size.width, top - 44.0f)];
        headerDone.alpha = 0.0f;
        headerDone.backgroundColor = headerEncrypting.backgroundColor;
        headerDone.font = headerEncrypting.font;
        headerDone.tag = headerEncrypting.tag;
        headerDone.text = @"Account Ready!";
        headerDone.textAlignment = headerEncrypting.textAlignment;
        headerDone.textColor = headerEncrypting.textColor;
        headerDone.transform = CGAffineTransformMakeTranslation(200.0f, 0.0f);
        [headerEncrypting.superview addSubview:headerDone];
        
        
        [info setNextTitle:@"Done" action:^() {
            NSLog(@"Acc: %@", account);
            [navigationController dismissWithResult:account];
        }];
        
        [account encryptSecretStorageJSON:password callback:^(NSString *json) {
            [self addAccount:account json:json];
            
            void (^animate)() = ^ () {
                headerEncrypting.alpha = 0.0f;
                headerEncrypting.transform = CGAffineTransformMakeTranslation(-200.0f, 0.0f);
                
                headerDone.alpha = 1.0f;
                headerDone.transform = CGAffineTransformIdentity;
                
                message.alpha = 0.0f;
                message.transform = CGAffineTransformMakeTranslation(-200.0f, 0.0f);
                
                activityView.alpha = 0.0f;
                activityView.transform = CGAffineTransformMakeTranslation(-200.0f, 0.0f);
            };
            
            void (^complete)(BOOL) = ^(BOOL complete) {
                info.nextEnabled = YES;
            };
            
            [UIView animateWithDuration:0.5f
                                  delay:0.0f
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:animate
                             completion:complete];
            
        }];
    };
    info.navigationItem.hidesBackButton = YES;
    [navigationController pushViewController:info animated:YES];
}


#pragma mark - Address Operations

- (void)setActiveAccount:(Address *)address {
    if (_activeAccount == address || [address isEqualToAddress:_activeAccount]) {
        return;
    }
    
    _activeAccount = address;
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        NSDictionary *userInfo = ((_activeAccount) ? (@{ @"address": _activeAccount}): (@{}));
        [[NSNotificationCenter defaultCenter] postNotificationName:WalletChangedActiveAccountNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
    
    [_dataStore setObject:_activeAccount.checksumAddress forKey:DataStoreKeyUserActiveAccount];
}

- (BOOL)containsAddress: (Address*)address {
    if (!address) { return NO; }
    return [_orderedAddresses containsObject:address];
}

- (NSString*)nicknameForAccount: (Address*)address {
    NSString *nickname = [self _objectForKeyPrefix:DataStoreKeyAccountNicknamePrefix address:address];
    if (!nickname) { nickname = @"ethers.io"; }
    return nickname;
}

- (void)_setNickname: (NSString*)nickname address: (Address*)address {
    [self _setObject:nickname forKeyPrefix:DataStoreKeyAccountNicknamePrefix address:address];
    dispatch_async(dispatch_get_main_queue(), ^() {
        NSDictionary *userInfo = @{ @"address": address, @"nickname":nickname };
        [[NSNotificationCenter defaultCenter] postNotificationName:WalletChangedNicknameNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

- (void)setNickname:(NSString *)nickname address:(Address *)address {
    NSString *json = [self getJSON:address];
    if (!json) {
        NSLog(@"ERROR: Missing JSON Wallet (%@)", address);
        return;
    }
    
    addKeychainVaue(_keychainKey, address, nickname, json);
    [self _setNickname:nickname address:address];
}

- (BOOL)isAccountUnlocked: (Address*)address {
    if (!address) { return NO; }
    return [_accounts objectForKey:address] != nil;
}

- (BOOL)lockAccount: (Address*)address {
    if (!address) { return NO; }
    
    if ([_accounts objectForKey:address] != nil) {
        [_accounts removeObjectForKey:address];
        return YES;
    }
    
    return NO;
}


#pragma mark - Transactions

+ (void)sortTransactions: (NSMutableArray<TransactionInfo*>*)transactions {
    [transactions sortUsingComparator:^NSComparisonResult(TransactionInfo *a, TransactionInfo *b) {
        if (a.timestamp > b.timestamp) {
            return NSOrderedAscending;
        } if (a.timestamp < b.timestamp) {
            return NSOrderedDescending;
        } else if (a.timestamp == b.timestamp) {
            if (a.hash < b.hash) {
                return NSOrderedAscending;
            } if (a.hash > b.hash) {
                return NSOrderedDescending;
            }
        }
        return NSOrderedSame;
    }];
}

// @TODO: Use a database, or something more robust for larger sets
- (NSMutableArray<TransactionInfo*>*)transactionsForAddress: (Address*)address {
    NSDictionary<NSString*, NSDictionary*> *transactionsByHash = [self _objectForKeyPrefix:DataStoreKeyAccountTxsPrefix address:address];
    if (!transactionsByHash) { return [NSMutableArray arrayWithCapacity:4]; }
    
    NSMutableArray *transactions = [NSMutableArray arrayWithCapacity:[transactionsByHash count]];
    
    for (NSDictionary *info in [transactionsByHash allValues]) {
        TransactionInfo *transaction = [TransactionInfo transactionInfoFromDictionary:info];
        if (!transaction) {
            NSLog(@"Bad Transaction: %@", info);
            continue;
        }
        [transactions addObject:transaction];
    }
    
    [Wallet sortTransactions:transactions];
    
    return transactions;
}

- (NSInteger)addTransactionInfos: (NSArray<TransactionInfo*>*)transactionInfos address: (Address*)address {
    NSMutableDictionary *transactionsByHash = [[self _objectForKeyPrefix:DataStoreKeyAccountTxsPrefix address:address] mutableCopy];
    if (!transactionsByHash) { transactionsByHash = [NSMutableDictionary dictionaryWithCapacity:4]; }

    NSMutableArray<TransactionInfo*> *transactions = [_transactions objectForKey:address];
    NSMutableArray<TransactionInfo*> *changedTransactions = [NSMutableArray array];
    
    BOOL changed = [transactions isEqual:transactionInfos];
    for (TransactionInfo *transactionInfo in transactionInfos) {
        NSString *transactionHash = transactionInfo.transactionHash.hexString;
        
        NSDictionary *info = [transactionsByHash objectForKey:transactionHash];
        [transactionsByHash setObject:[transactionInfo dictionaryRepresentation] forKey:transactionHash];
        if (info && [info isEqual:[transactionInfo dictionaryRepresentation]]) {
            continue;
        }
        
        [changedTransactions addObject:transactionInfo];

        changed = YES;
    }

    // We may have updated something, so we save it
    [self _setObject:transactionsByHash forKeyPrefix:DataStoreKeyAccountTxsPrefix address:address];

    // Something important changed (transactionHash changed or new transaction)
    if (changed) {
        [_transactions setObject:[self transactionsForAddress:address] forKey:address];
    }

    NSInteger highestBlockNumber = -1;
    if ([transactions count]) {
        highestBlockNumber = [transactions lastObject].blockNumber;
    }
    
    if (changed) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            NSDictionary *userInfo = @{ @"address": address, @"highestBlockNumber": @(highestBlockNumber) };
            [[NSNotificationCenter defaultCenter] postNotificationName:WalletAccountTransactionsUpdatedNotification
                                                                object:self
                                                              userInfo:userInfo];
            
            for (TransactionInfo *transactionInfo in changedTransactions) {
                NSDictionary *userInfo = @{ @"transaction": transactionInfo };
                [[NSNotificationCenter defaultCenter] postNotificationName:WalletTransactionChangedNotification
                                                                    object:self
                                                                  userInfo:userInfo];
            }
        });
        
    }
    
    return highestBlockNumber;
}

- (NSUInteger)transactionCountForAddress:(Address*)address {
    return [[_transactions objectForKey:address] count];
}

- (TransactionInfo*)transactionForAddress:(Address*)address index:(NSUInteger)index {
    return [[_transactions objectForKey:address] objectAtIndex:index];
}


#pragma mark - Blockchain

- (BOOL)setBalanceForAddress: (Address*)address balance: (BigNumber*)balanceWei {
    if ([balanceWei isEqual:[self balanceForAddress:address]]) {
        return NO;
    }

    [self _setObject:[balanceWei hexString] forKeyPrefix:DataStoreKeyAccountBalancePrefix address:address];
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        NSDictionary *userInfo = @{ @"address": address, @"balance": balanceWei };
        [[NSNotificationCenter defaultCenter] postNotificationName:WalletBalanceChangedNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
    
    return YES;
}

- (BigNumber*)balanceForAddress: (Address*)address {
    NSString *balanceHex = [self _objectForKeyPrefix:DataStoreKeyAccountBalancePrefix address:address];
    if (!balanceHex) { return [BigNumber constantZero]; }
    return [BigNumber bigNumberWithHexString:balanceHex];
}

- (void)setNonce: (NSUInteger)nonce forAddress: (Address*)address {
    [self _setInteger:nonce forKeyPrefix:DataStoreKeyAccountNoncePrefix address:address];
}

- (NSUInteger)nonceForAddress: (Address*)address {
    return [self _integerForKeyPrefix:DataStoreKeyAccountNoncePrefix address:address];
}

- (void)setSyncDate: (NSTimeInterval)syncDate {
    BOOL changed = [_dataStore setTimeInterval:syncDate forKey:DataStoreKeyNetworkSyncDate];
    if (changed) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            NSDictionary *userInfo = @{@"syncDate": @(syncDate)};
            [[NSNotificationCenter defaultCenter] postNotificationName:WalletDidSyncNotification
                                                                object:self
                                                              userInfo:userInfo];
        });
    }
}

- (NSTimeInterval)syncDate {
    return [_dataStore timeIntervalForKey:DataStoreKeyNetworkSyncDate];
}

- (void)setGasPrice: (BigNumber*)gasPrice {
    [_dataStore setString:[gasPrice hexString] forKey:DataStoreKeyNetworkGasPrice];
}

- (BigNumber*)gasPrice {
    return [BigNumber bigNumberWithHexString:[_dataStore stringForKey:DataStoreKeyNetworkGasPrice]];
}

- (void)setBlockNumber: (NSInteger)blockNumber {
    [_dataStore setInteger:blockNumber forKey:DataStoreKeyNetworkBlockNumber];
    
    // All transactions' confirmations have increased
    if (_activeAccount && [_transactions objectForKey:_activeAccount].count) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            NSDictionary *userInfo = @{ @"address": _activeAccount, @"highestBlockNumber": @([self txBlockForAddress:_activeAccount]) };
            [[NSNotificationCenter defaultCenter] postNotificationName:WalletAccountTransactionsUpdatedNotification
                                                                object:self
                                                              userInfo:userInfo];
        });
    }
}

- (BlockTag)blockNumber {
    return [_dataStore integerForKey:DataStoreKeyNetworkBlockNumber];
}

- (BOOL)setEtherPrice: (float)etherPrice {
    BOOL changed = [_dataStore setFloat:etherPrice forKey:DataStoreKeyNetworkEtherPrice];
    [self updateEtherPriceLabel];
    return changed;
}

- (float)etherPrice {
    return [_dataStore floatForKey:DataStoreKeyNetworkEtherPrice];
}

- (void)setTxBlock: (NSUInteger)txBlock forAddress: (Address*)address {
    [self _setInteger:txBlock forKeyPrefix:DataStoreKeyAccountTxBlockNoncePrefix address:address];
}

- (NSUInteger)txBlockForAddress: (Address*)address {
    return [self _integerForKeyPrefix:DataStoreKeyAccountTxBlockNoncePrefix address:address];
}

- (void)refresh:(void (^)(BOOL))callback {
    @synchronized (self) {
        
        if (!_refreshPromise) {
            Provider *currentProvider = _provider;

            NSMutableArray *promises = [NSMutableArray array];
            
            for (Address *address in _orderedAddresses) {
                
                [promises addObject:[IntegerPromise promiseWithSetup:^(Promise *promise) {
                    [[currentProvider getBalance:address blockTag:BLOCK_TAG_PENDING] onCompletion:^(BigNumberPromise *balancePromise) {
                        BOOL changed = NO;
                        if (balancePromise.result && currentProvider == _provider) {
                            [self setSyncDate:[NSDate timeIntervalSinceReferenceDate]];
                            changed = [self setBalanceForAddress:address balance:balancePromise.value];
                        }
                        [promise resolve:@(changed)];
                    }];
                }]];

                [promises addObject:[IntegerPromise promiseWithSetup:^(Promise *promise) {
                    [[currentProvider getTransactionCount:address blockTag:BLOCK_TAG_PENDING] onCompletion:^(IntegerPromise *noncePromise) {
                        if (noncePromise.result && currentProvider == _provider) {
                            [self setSyncDate:[NSDate timeIntervalSinceReferenceDate]];
                            [self setNonce:noncePromise.value forAddress:address];
                        }
                        [promise resolve:@(NO)];
                    }];
                }]];
                
                [promises addObject:[IntegerPromise promiseWithSetup:^(Promise *promise) {
                    [[currentProvider getTransactions:address startBlockTag:0] onCompletion:^(ArrayPromise *transactionsPromise) {
                        if (transactionsPromise.result && currentProvider == _provider) {
                            NSInteger highestBlock = [self addTransactionInfos:transactionsPromise.value address:address];
                            // @TODO: if heighestBlock < blockNumber - 10, use blockNumber - 10?
                            [self setTxBlock:highestBlock forAddress:address];
                        }
                        [promise resolve:@(NO)];
                    }];
                }]];
            }
            
            [promises addObject:[IntegerPromise promiseWithSetup:^(Promise *promise) {
                [[currentProvider getGasPrice] onCompletion:^(BigNumberPromise *gasPricepromise) {
                    if (gasPricepromise.result && currentProvider == _provider) {
                        [self setGasPrice:gasPricepromise.value];
                    }
                    [promise resolve:@(NO)];
                }];
            }]];
            
            [promises addObject:[IntegerPromise promiseWithSetup:^(Promise *promise) {
                [[currentProvider getBlockNumber] onCompletion:^(IntegerPromise *blockNumberPromise) {
                    if (blockNumberPromise.result && currentProvider == _provider) {
                        [self setBlockNumber:blockNumberPromise.value];
                    }
                    [promise resolve:@(NO)];
                }];
            }]];
            
            [promises addObject:[IntegerPromise promiseWithSetup:^(Promise *promise) {
                [[currentProvider getEtherPrice] onCompletion:^(FloatPromise *etherPricePromise) {
                    BOOL changed = NO;
                    if (etherPricePromise.result && currentProvider == _provider) {
                        changed = [self setEtherPrice:etherPricePromise.value];
                    }
                    [promise resolve:@(changed)];
                }];
            }]];

            _refreshPromise = [IntegerPromise promiseWithSetup:^(Promise *promise) {
                [[Promise all:promises] onCompletion:^(ArrayPromise *allPromises) {
                    
                    if (allPromises.error) {
                        [promise reject:allPromises.error];
                        return;
                    }
                    
                    BOOL changed = NO;
                    for (NSNumber *updated in allPromises.value) {
                        if ([updated boolValue]) {
                            changed = YES;
                            break;
                        }
                    }
                    
                    [promise resolve:@(changed)];
                }];
            }];
            
            [_refreshPromise onCompletion:^(Promise *promise) {
                _refreshPromise = nil;
            }];
        }
        
        [_refreshPromise onCompletion:^(IntegerPromise *promise) {
            if (!callback) { return; }
            
            if (promise.result) {
                callback(promise.value);
            } else {
                callback(NO);
            }
        }];
    }
}

@end
