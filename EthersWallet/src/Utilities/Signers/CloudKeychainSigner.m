//
//  SecretStorageSigner.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-08-12.
//  Copyright © 2017 ethers.io. All rights reserved.
//



#import "CloudKeychainSigner.h"

#import <ethers/account.h>

#import "CachedDataStore.h"

static Address *checkJson(NSString *json) {
    NSError *error = nil;
    NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:0
                                                               error:&error];
    if (error) {
        NSLog(@"ERROR: Invalid JSON Wallet - %@", error);
        return nil;
    }
    
    if (![jsonData isKindOfClass:[NSDictionary class]]) { return nil; }
    
    // @TODO: Add more checks in here?
    
    return [Address addressWithString:[jsonData objectForKey:@"address"]];
}


static NSString *getNickname(NSString *label) {
    
    static NSRegularExpression *regexLabel = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        regexLabel = [NSRegularExpression regularExpressionWithPattern:@"[^(]*\\((.*)\\)" options:0 error:&error];
        if (error) {
            NSLog(@"CloudKeychainSigner: Error creating regular expression - %@", error);
        }
    });
    
    NSTextCheckingResult *result = [regexLabel firstMatchInString:label options:0 range:NSMakeRange(0, label.length)];
    
    if ([result numberOfRanges] && [result rangeAtIndex:1].location != NSNotFound) {
        return [label substringWithRange:[result rangeAtIndex:1]];
    }
    
    return @"ethers.io";
}


#pragma mark - Keychain helpers

/**
 *  kSecAttrGeenric is not part of teh key (as the documentation and example code allude to).
 *  As a result, to support the same address with multiple providers, we now use the service
 *  to specify the per-account provider.
 *
 *  In the future, we will allow any string, so this class is flexible and can be used
 *  by anyone. The caller will have to have the sharedWallet keys updated.
 */
static NSString *getServiceName(NSString *keychainKey) {
    if ([keychainKey isEqualToString:@"io.ethers.sharedWallet"]) {
        return @"ethers.io";
    } else if ([keychainKey isEqualToString:@"io.ethers.sharedWallet-testnet"]) {
        return @"ethers.io/ropsten";
    }
    
    // @TODO: return keychainKey
    return nil;
}

static NSString* getKeychainValue(NSString *keychainKey, Address *address) {
    NSString *serviceName = getServiceName(keychainKey);
    if (!serviceName) { return nil; }
    
    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnData: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: address.checksumAddress,
                            (id)kSecAttrService: serviceName,
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

static BOOL addKeychainVaue(NSString *keychainKey, Address *address, NSString *nickname, NSString *value) {
    NSString *serviceName = getServiceName(keychainKey);
    if (!serviceName) { return NO; }

    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: address.checksumAddress,
                            (id)kSecAttrService: serviceName,
                            };
    
    CFDictionaryRef existingEntry = nil;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&existingEntry);
    if (status == noErr) {
        NSLog(@"Update");
        NSMutableDictionary *updateQuery = [(__bridge NSDictionary *)existingEntry mutableCopy];
        [updateQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
        
        NSDictionary *updateEntry = @{
                                      (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                                      
                                      (id)kSecAttrAccount: address.checksumAddress,
                                      (id)kSecAttrService: serviceName,
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
        NSLog(@"Add");
        NSDictionary *addEntry = @{
                                   (id)kSecClass: (id)kSecClassGenericPassword,
                                   (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                                   (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                                   
                                   (id)kSecAttrAccount: address.checksumAddress,
                                   (id)kSecAttrService: serviceName,
                                   (id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding],
                                   (id)kSecAttrLabel: [NSString stringWithFormat:@"Ethers Account (%@)", nickname],
                                   (id)kSecAttrDescription: @"Encrypted JSON Wallet",
                                   (id)kSecAttrComment: @"This is managed by Ethers and contains an encrypted copy of your JSON wallet.",
                                   };
        
        status = SecItemAdd((__bridge CFDictionaryRef)addEntry, NULL);
        if (status != noErr) {
            NSLog(@"Keychain: Error adding %@ - %d", address, (int)status);
        }
        
    }
    
    if (existingEntry) { CFRelease(existingEntry); }
    
    return (status == noErr);
}

BOOL removeKeychainValue(NSString *keychainKey, Address *address) {
    NSString *serviceName = getServiceName(keychainKey);
    if (!serviceName) { return NO; }

    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: address.checksumAddress,
                            (id)kSecAttrService: serviceName,
                            };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status != noErr) {
        NSLog(@"Error deleting");
    }
    
    return (status == noErr);
}


#pragma mark - CloudKeychainSigner

static NSString *DataStoreKeyAccounts                 = @"ACCOUNTS";

@implementation CloudKeychainSigner {
    Account *_account;
    Cancellable *_unlocking;
    NSString *_serviceName;
}

+ (NSArray<Address*>*)addressesForKeychainKey: (NSString*)keychainKey {
    NSString *serviceName = getServiceName(keychainKey);
    if (!serviceName) { return @[]; }

    NSString *cacheKey = [@"cloudkeychainsigner-" stringByAppendingString:keychainKey];
    CachedDataStore *dataStore = [CachedDataStore sharedCachedDataStoreWithKey:cacheKey];;
    
    NSMutableArray<Address*> *addresses = [NSMutableArray array];
    
    // If the devices is unlocked, we can load all the JSON wallets
    NSDictionary *query = @{
                            (id)kSecMatchLimit: (id)kSecMatchLimitAll,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecAttrService: serviceName,
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue
                            };
    
    CFMutableArrayRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&result);
    
    if (status == noErr) {
        NSMutableArray *addressStrings = [NSMutableArray array];
        
        for (NSDictionary *entry in ((__bridge NSArray*)result)) {
            NSString *addressString = [entry objectForKey:(id)kSecAttrAccount];
            [addressStrings addObject:addressString];
            [addresses addObject:[Address addressWithString:addressString]];
        }

        NSLog(@"Keychain: Found %d accounts for %@", (int)(addresses.count), keychainKey);

        // Save the list of addresses to the data store (so we can load it without keychain access if needed)
        [dataStore setArray:addressStrings forKey:DataStoreKeyAccounts];
        
    } else if (status == errSecItemNotFound) {
        // No problem... No exisitng entries
        NSLog(@"Keychain: No accounts for %@", keychainKey);

        [dataStore setArray:nil forKey:DataStoreKeyAccounts];
        
    } else {
        // Error... Possibly the device is locked?
        NSLog(@"Keychain: Error - status=%d (maybe the device is locked?)", (int)status);

        // Device locked; load the addresses from the data store
        for (NSString *addressString in [dataStore arrayForKey:DataStoreKeyAccounts]) {
            [addresses addObject:[Address addressWithString:addressString]];
        }
    }
    
    if (result) { CFRelease(result); }
    
    return addresses;
}



+ (instancetype)writeToKeychain:(NSString *)keychainKey
                       nickname:(NSString *)nickname
                           json:(NSString *)json
                       provider:(Provider *)provider {
    
    
    Address *address = checkJson(json);
    if (!address) { return nil; }
    
    addKeychainVaue(keychainKey, address, nickname, json);
    
    return [CloudKeychainSigner signerWithKeychainKey:keychainKey address:address provider:provider];
}

+ (instancetype)signerWithKeychainKey: (NSString*)keychainKey address: (Address*)address provider: (Provider*)provider {
    return [[self alloc] initWithKeychainKey:keychainKey address:address provider:provider];
}

- (instancetype)initWithKeychainKey: (NSString*)keychainKey address: (Address*)address provider: (Provider*)provider {
    self = [super initWithCacheKey:keychainKey address:address provider:provider];
    if (self) {
        _keychainKey = keychainKey;
        
        _serviceName = getServiceName(_keychainKey);
        if (!_serviceName) { return nil; }
        
        __weak CloudKeychainSigner *weakSelf = self;
        [NSTimer scheduledTimerWithTimeInterval:4.0f repeats:YES block:^(NSTimer *timer) {
            if (!weakSelf) {
                [timer invalidate];
                return;
            }
            
            // No longer alive, stop polling
            BOOL maybeAlive = [weakSelf checkNickname];
            if (!maybeAlive) { [timer invalidate]; }
        }];
    }
    return self;
}

- (BOOL)checkNickname {
    BOOL maybeAlive = YES;
    
    NSDictionary *query = @{
                            //(id)kSecMatchLimit: (id)kSecMatchLimitAll,
                            
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [self.keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: self.address.checksumAddress,
                            (id)kSecAttrService: _serviceName,
                            };
    
    NSString *label = nil;
    
    CFDictionaryRef entry = nil;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&entry);
    if (status == noErr) {
        label = [(__bridge NSDictionary*)entry objectForKey:(id)kSecAttrLabel];
        
    } else if (status == errSecItemNotFound) {
        maybeAlive = NO;
        
        __weak CloudKeychainSigner *weakSelf = self;
        //NSDictionary *userInfo = @{ SignerNotificationSignerKey: self };
        NSDictionary *userInfo = @{};
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[NSNotificationCenter defaultCenter] postNotificationName:SignerRemovedNotification
                                                                object:weakSelf
                                                              userInfo:userInfo];
        });
    }
    
    if (entry) { CFRelease(entry); }
    
    // We found a label, set our nickname (super handles changed notifications)
    if (label) {
        NSString *nickname = getNickname(label);
        if (nickname) { [super setNickname:nickname]; }
    }
    
    return maybeAlive;
}

- (void)setNickname:(NSString *)nickname {
    NSString *json = [self _json];

    Address *address = checkJson(json);
    if (address) {
        if ([address isEqualToAddress:self.address]) {
            addKeychainVaue(self.keychainKey, address, nickname, json);
            [super setNickname:nickname];
        } else {
            NSLog(@"ERROR: setNickname - address does not match JSON");
        }
    }
}

- (BOOL)remove {
    if (!_account) { return NO; }
    
    BOOL success = removeKeychainValue(_keychainKey, self.address);
    if (success) {
        __weak CloudKeychainSigner *weakSelf = self;
        
        //NSDictionary *userInfo = @{ SignerNotificationSignerKey: self };
        NSDictionary *userInfo = @{};
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[NSNotificationCenter defaultCenter] postNotificationName:SignerRemovedNotification
                                                                object:weakSelf
                                                              userInfo:userInfo];
        });
    }
    
    return success;
}

- (BOOL)supportsFingerprintUnlock {
    // @todo: Check if there is an entry in the local keychain
    return NO;
}

- (void)fingerprintUnlockCallback: (void (^)(Signer*, NSError*))callback {
    
}

- (BOOL)supportsSign {
    return YES;
}

- (void)send:(Transaction *)transaction callback:(void (^)(Transaction *, NSError *))callback {
    transaction = [transaction copy];
    NSLog(@"CloudKeychainSigner: Sending - address=%@ transaction=%@", _account.address, transaction);

    if (!_account) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:@"FOO" code:1 userInfo:@{}]);
        });
        return;
    }
    
    [_account sign:transaction];
    
    __weak CloudKeychainSigner *weakSelf = self;
    
    NSData *signedTransaction = [transaction serialize];
    [[self.provider sendTransaction:signedTransaction] onCompletion:^(HashPromise *promise) {
        NSLog(@"CloudKeychainSigner: Sent - signed=%@ hash=%@ error=%@", signedTransaction, promise.value, promise.error);
        
        if (promise.error) {
            callback(nil, promise.error);
        } else {
            [weakSelf addTransaction:transaction];
            callback(transaction, nil);
        }
    }];
}


- (BOOL)hasPassword {
    return YES;
}

- (BOOL)unlocked {
    return (_account != nil);
}

- (void)lock {
    _account = nil;
}

- (void)cancelUnlock {
    if (_unlocking) { [_unlocking cancel]; }
}

- (BOOL)_setAccount: (Account*)account {
    if (![account.address isEqualToAddress:self.address]) { return NO; }
    _account = account;
    return YES;
}

- (BOOL)supportsMnemonicPhrase {
    return YES;
}

- (NSString*)mnemonicPhrase {
    return _account.mnemonicPhrase;
}

- (NSString*)_json {
    return getKeychainValue(self.keychainKey, self.address);
}

- (void)unlock: (NSString*)password callback: (void (^)(Signer*, NSError*))callback {
    [self cancelUnlock];

    __weak CloudKeychainSigner *weakSelf = self;

    if (_account) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(weakSelf, nil);
        });
        return;
    }
    
    _unlocking = [Account decryptSecretStorageJSON:[self _json] password:password callback:^(Account *account, NSError *error) {
        if (error) {
            callback(weakSelf, error);
        } else {
            [weakSelf _setAccount:account];
            callback(weakSelf, nil);
        }
    }];
}

@end
