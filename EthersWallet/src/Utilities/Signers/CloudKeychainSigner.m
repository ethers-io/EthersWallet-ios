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

static NSString* getKeychainValue(NSString *keychainKey, Address *address) {
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

static BOOL addKeychainVaue(NSString *keychainKey, Address *address, NSString *nickname, NSString *value) {
    
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


#pragma mark - CloudKeychainSigner

static NSString *DataStoreKeyAccounts                 = @"ACCOUNTS";

@implementation CloudKeychainSigner {
    Account *_account;
    Cancellable *_unlocking;
}

+ (NSArray<Address*>*)addressesForKeychainKey: (NSString*)keychainKey {

    NSString *cacheKey = [@"cloudkeychainsigner-" stringByAppendingString:keychainKey];
    CachedDataStore *dataStore = [CachedDataStore sharedCachedDataStoreWithKey:cacheKey];;
    
    NSMutableArray *addresses = [NSMutableArray array];
    
    // If the devices is unlocked, we can load all the JSON wallets
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
        NSLog(@"Keychain: Found accounts");
        
        for (NSDictionary *entry in ((__bridge NSArray*)result)) {
            [addresses addObject:[Address addressWithString:[entry objectForKey:(id)kSecAttrAccount]]];
        }
        
        // Save the list of addresses to the data store (so we can load it without keychain access if needed)
        [dataStore setArray:addresses forKey:DataStoreKeyAccounts];
        
    } else if (status == errSecItemNotFound) {
        // No problem... No exisitng entries
        NSLog(@"Keychain: No accounts");

        [dataStore setArray:nil forKey:DataStoreKeyAccounts];
        
    } else {
        // Error... Possibly the device is locked?
        NSLog(@"Keychain: Error - status=%d", (int)status);

        // Device locked; load the addresses from the data store
        for (NSString *addressString in [dataStore arrayForKey:DataStoreKeyAccounts]) {
            [addresses addObject:[Address addressWithString:addressString]];
        }
    }
    
    if (result) { CFRelease(result); }

    NSLog(@"Keychain: Found - %@", addresses);
    
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
        
        __weak CloudKeychainSigner *weakSelf = self;
        [NSTimer scheduledTimerWithTimeInterval:4.0f repeats:YES block:^(NSTimer *timer) {
            if (!weakSelf) {
                NSLog(@"Keychain thing dead; killing timer");
                [timer invalidate];
                return;
            }
            
            [weakSelf checkNickname];
        }];
    }
    return self;
}

- (BOOL)checkNickname {
    BOOL alive = YES;
    
    NSDictionary *query = @{
                            //(id)kSecMatchLimit: (id)kSecMatchLimitAll,
                            
                            (id)kSecClass: (id)kSecClassGenericPassword,
                            (id)kSecAttrGeneric: [self.keychainKey dataUsingEncoding:NSUTF8StringEncoding],
                            (id)kSecReturnAttributes: (id)kCFBooleanTrue,
                            (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
                            
                            (id)kSecAttrAccount: self.address.checksumAddress,
                            (id)kSecAttrService: @"ethers.io",
                            };
    
    NSString *label = nil;
    
    CFDictionaryRef entry = nil;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&entry);
    if (status == noErr) {
        label = [(__bridge NSDictionary*)entry objectForKey:(id)kSecAttrLabel];
        
    } else if (status == errSecItemNotFound) {
        NSLog(@"Not found! Removed Event");
        alive = NO;
        __weak CloudKeychainSigner *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[NSNotificationCenter defaultCenter] postNotificationName:SignerRemovedNotification
                                                                object:weakSelf
                                                              userInfo:@{ @"signer": weakSelf }];
        });
    }
    
    if (entry) { CFRelease(entry); }
    
    // We found a label, set our nickname (super handles changed notifications)
    if (label) {
        NSString *nickname = getNickname(label);
        if (nickname) { [super setNickname:nickname]; }
    }
    
    return alive;
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
    return removeKeychainValue(_keychainKey, self.address);
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
    NSLog(@"Sending: %@ %@", _account, transaction);
    if (!_account) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:@"FOO" code:1 userInfo:@{}]);
        });
        return;
    }
    
    [_account sign:transaction];
    
    [[self.provider sendTransaction:[transaction serialize]] onCompletion:^(HashPromise *promise) {
        NSLog(@"Signed: %@ %@", transaction, promise);
        if (promise.error) {
            callback(nil, promise.error);
        } else {
            callback(transaction, nil);
        }
    }];
}

//- (void)sign: (Transaction*)transaction callback: (void (^)(Transaction*, NSError*))callback {
//    if (!_account) {
//        callback(nil, [NSError errorWithDomain:@"foo" code:123 userInfo:@{}]);
//        return;
//    }
//    
//    transaction = [transaction copy];
//    [_account sign:transaction];
//    dispatch_async(dispatch_get_main_queue(), ^() {
//        callback(transaction, nil);
//    });
//}


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
