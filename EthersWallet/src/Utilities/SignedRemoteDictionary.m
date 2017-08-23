//
//  SignedRemoteDictionary.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-08-23.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "SignedRemoteDictionary.h"

#import <ethers/SecureData.h>
#import <ethers/Transaction.h>

#import "CachedDataStore.h"
#import "Utilities.h"


#define STALE_AGE       (60.0f * 60.0f)
#define TIMEOUT         3.0f


const NSErrorDomain SignedRemoteDictionaryErrorDomain = @"SignedRemoteDictionaryErrorDomain";


const NSString *DataStoreKeyUpdateDatePrefix = @"UPDATED_";
const NSString *DataStoreKeyHexPrefix = @"HEX_";


@implementation SignedRemoteDictionary


+ (instancetype)dictionaryWithUrl: (NSString*)url address: (Address*)address defaultData: (NSDictionary*)defaultData {

    static NSMutableDictionary *signedRemoteDictionaries = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        signedRemoteDictionaries = [NSMutableDictionary dictionary];
    });
    
    SignedRemoteDictionary *dictionary = [signedRemoteDictionaries objectForKey:url];
    if (!dictionary) {
        dictionary = [[SignedRemoteDictionary alloc] initWithUrl:url address:address defaultData:defaultData];
        [signedRemoteDictionaries setObject:dictionary forKey:url];
    }

    return dictionary;
}

- (instancetype)initWithUrl: (NSString*)url address: (Address*)address defaultData: (NSDictionary*)defaultData {
    self = [super init];
    if (self) {
        _url = url;
        _address = address;
        
        _currentData = defaultData;
        _updatedDate = 0;
    
        _preferredMaximumStaleAge = STALE_AGE;
        _maximumTimeout = TIMEOUT;
        
        [self loadData];
    }
    return self;
}

- (NSDictionary*)checkSignature: (NSString*)hexString {
    NSData *data = [SecureData hexStringToData:hexString];
    if (!data) { return nil; }
    
    Transaction *transaction = [Transaction transactionWithData:data];
    if (!transaction || !transaction.data || ![transaction.fromAddress isEqualToAddress:_address]) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:transaction.data options:0 error:&error];
    if (![payload isKindOfClass:[NSDictionary class]]) { return nil; }
    
    return payload;
}

- (void)loadData {
    CachedDataStore *dataStore = [CachedDataStore sharedCachedDataStoreWithKey:@"signed-remote-data"];

    NSString *hexString = [dataStore stringForKey:[DataStoreKeyHexPrefix stringByAppendingString:_url]];
    if (!hexString) { return; }

    NSDictionary *data = [self checkSignature:hexString];
    if (!data) { return; }
    
    _currentData = data;
    _updatedDate = [dataStore timeIntervalForKey:[DataStoreKeyUpdateDatePrefix stringByAppendingString:_url]];
    
    NSLog(@"Loaded: %@ %@", _url, data);
}

- (BOOL)saveData: (NSString*)hexString {
    NSDictionary *currentData = [self checkSignature:hexString];
    if (currentData) {
        _currentData = currentData;
        _updatedDate = [NSDate timeIntervalSinceReferenceDate];
        
        CachedDataStore *dataStore = [CachedDataStore sharedCachedDataStoreWithKey:@"signed-remote-data"];
        [dataStore setObject:hexString forKey:[DataStoreKeyHexPrefix stringByAppendingString:_url]];
        [dataStore setTimeInterval:_updatedDate forKey:[DataStoreKeyUpdateDatePrefix stringByAppendingString:_url]];
        return YES;
    }
    return NO;
}

- (Promise*)fetchData {
    __weak SignedRemoteDictionary *weakSelf = self;
    return [Promise promiseWithSetup:^(Promise *promise) {
        [[Utilities fetchUrl:_url body:nil dedupToken:@""] onCompletion:^(DataPromise *dataPromise) {
            if (dataPromise.error) {
                [promise reject:[NSError errorWithDomain:SignedRemoteDictionaryErrorDomain
                                                    code:SignedRemoteDictionaryErrorNetwork
                                                userInfo:@{}]];
            } else {
                NSString *hexString = [[NSString alloc] initWithData:dataPromise.value encoding:NSUTF8StringEncoding];
                hexString = [hexString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([weakSelf saveData:hexString]) {
                    [promise resolve:weakSelf.currentData];
                    
                } else {
                    [promise reject:[NSError errorWithDomain:SignedRemoteDictionaryErrorDomain
                                                        code:SignedRemoteDictionaryErrorBadSignature
                                                    userInfo:@{}]];
                }
            }
        }];
    }];
}

- (DictionaryPromise*)data {
    __weak SignedRemoteDictionary *weakSelf = self;
    return [DictionaryPromise promiseWithSetup:^(Promise *promise) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        
        // Stale data is allowed
        if (now - weakSelf.updatedDate <= weakSelf.preferredMaximumStaleAge) {
            [promise resolve:weakSelf.currentData];
        } else {
            
            // Set a timer
            __block BOOL promiseDone = NO;
            [[Promise timer:weakSelf.maximumTimeout] onCompletion:^(Promise *timerPromise) {
                if (promiseDone) { return; }
                promiseDone = YES;
                [promise resolve:weakSelf.currentData];
            }];
            
            [[weakSelf fetchData] onCompletion:^(Promise *fetchPromise) {
                if (promiseDone) { return; }
                promiseDone = YES;
                if (fetchPromise.error) {
                    [promise reject:fetchPromise.error];
                } else {
                    [promise resolve:fetchPromise.result];
                }
            }];
        }
        
    }];
}

@end
