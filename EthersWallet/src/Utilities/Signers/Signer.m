//
//  Signer.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-05-03.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "Signer.h"

#import <ethers/Payment.h>
#import "CachedDataStore.h"

#pragma mark - Notifications

const NSNotificationName SignerRemovedNotification                = @"SignerRemovedNotification";
const NSNotificationName SignerNicknameDidChangeNotification      = @"SignerNicknameDidChangeNotification";
const NSNotificationName SignerBalanceDidChangeNotification       = @"SignerBalanceDidChangeNotification";
const NSNotificationName SignerHistoryUpdatedNotification         = @"SignerHistoryUpdatedNotification";
const NSNotificationName SignerTransactionDidChangeNotification   = @"SignerTransactionDidChangeNotification";


#pragma mark - Notification Keys

const NSString* SignerNotificationSignerKey                       = @"SignerNotificationSignerKey";

const NSString* SignerNotificationNicknameKey                     = @"SignerNotificationNicknameKey";
const NSString* SignerNotificationFormerNicknameKey               = @"SignerNotificationFormerNicknameKey";

const NSString* SignerNotificationBalanceKey                      = @"SignerNotificationBalanceKey";
const NSString* SignerNotificationFormerBalanceKey                = @"SignerNotificationFormerBalanceKey";
const NSString* SignerNotificationTransactionKey                  = @"SignerNotificationTransactionKey";


#pragma mark - Data Store Keys

static NSString *DataStoreKeyAccountIndexPrefix                   = @"ACCOUNT_INDEX_";
static NSString *DataStoreKeyBalancePrefix                        = @"BALANCE_";
static NSString *DataStoreKeyBlockNumberPrefix                    = @"BLOCK_NUMBER_";
static NSString *DataStoreKeyNicknamePrefix                       = @"NICKNAME_";
static NSString *DataStoreKeyNoncePrefix                          = @"NONCE_";
static NSString *DataStoreKeyTransactionHistoryPrefix             = @"TRANSACTION_HISTORY_";
static NSString *DataStoreKeyTransactionHistoryTruncatedPrefix    = @"TRANSACTION_HISTORY_TRUNCATED_";


#pragma mark - Signer

@implementation Signer {
    CachedDataStore *_dataStore;
}


#pragma mark - Life-Cycle

- (instancetype)initWithCacheKey:(NSString *)cacheKey address:(Address *)address provider:(Provider *)provider {
    self = [super init];
    if (self) {
        _cacheKey = cacheKey;
        _address = address;
        _provider = provider;
                
        _dataStore = [CachedDataStore sharedCachedDataStoreWithKey:[@"signer-" stringByAppendingString:_cacheKey]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidReceiveNewBlock:)
                                                     name:ProviderDidReceiveNewBlockNotification
                                                   object:provider];
        [self notifyDidReceiveNewBlock:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UI State

- (void)setAccountIndex:(NSUInteger)accountIndex {
    NSString *key = [DataStoreKeyAccountIndexPrefix stringByAppendingString:self.address.checksumAddress];
    NSLog(@"SetAccountIndex: %@ %d", self.address, (int)accountIndex);
    [_dataStore setInteger:accountIndex forKey:key];
}

- (NSUInteger)accountIndex {
    NSString *key = [DataStoreKeyAccountIndexPrefix stringByAppendingString:self.address.checksumAddress];
    return [_dataStore integerForKey:key];
}

- (void)setNickname:(NSString *)nickname {
    __weak Signer *weakSelf = self;

    NSDictionary *userInfo = @{
                               SignerNotificationSignerKey: self,
                               SignerNotificationNicknameKey: nickname,
                               SignerNotificationFormerNicknameKey: self.nickname
                               };

    NSString *key = [DataStoreKeyNicknamePrefix stringByAppendingString:self.address.checksumAddress];
    if ([_dataStore setString:nickname forKey:key]) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[NSNotificationCenter defaultCenter] postNotificationName:SignerNicknameDidChangeNotification
                                                                object:weakSelf
                                                              userInfo:userInfo];
        });
    }
}

- (NSString*)nickname {
    NSString *key = [DataStoreKeyNicknamePrefix stringByAppendingString:self.address.checksumAddress];
    NSString *nickname = [_dataStore stringForKey:key];
    if (!nickname) { return @"ethers.io"; }
    return nickname;
}


#pragma mark - Blockchain Data

- (void)notifyDidReceiveNewBlock: (NSNotification*)note {
    
    __weak Signer *weakSelf = self;
    
    NSInteger blockNumber = [[note.userInfo objectForKey:@"blockNumber"] integerValue];
    [_dataStore setInteger:blockNumber forKey:[DataStoreKeyBlockNumberPrefix stringByAppendingString:_address.checksumAddress]];
    
    [[_provider getBalance:self.address] onCompletion:^(BigNumberPromise *promise) {
        if (!promise.result || promise.error) {
            //NSLog(@"Error: getBalance - %@", promise.error);
            return;
        }
        [weakSelf _setBalance:promise.value];
    }];

    [[_provider getTransactionCount:self.address] onCompletion:^(IntegerPromise *promise) {
        if (!promise.result || promise.error) {
            //NSLog(@"Error: getTransactionCount - %@", promise.error);
            return;
        }
        [weakSelf _setTransactionCount:promise.value];
    }];
    
    [[_provider getTransactions:self.address startBlockTag:0] onCompletion:^(ArrayPromise *promise) {
        if (!promise.result || promise.error) {
            //NSLog(@"Error: %@", promise.error);
            return;
        }
        
        [weakSelf _setTransactionHistory:promise.value];

        //NSInteger highestBlock = [self addTransactionInfos:transactionsPromise.value address:address];
        // @TODO: if heighestBlock < blockNumber - 10, use blockNumber - 10?
        //[self setTxBlock:highestBlock forAddress:address];
    }];

}

- (void)purgeCachedData {
    [self _setBalance:[BigNumber constantZero]];
    [self _setTransactionCount:0];
    [self _setTransactionHistory:@[]];
}

- (void)_setBalance: (BigNumber*)balance {
    BigNumber *oldBalance = self.balance;
    if ([oldBalance isEqual:balance]) { return; }
    
    NSString *key = [DataStoreKeyBalancePrefix stringByAppendingString:self.address.checksumAddress];
    [_dataStore setString:[balance hexString] forKey:key];
    
    __weak Signer *weakSelf = self;
    NSDictionary *info = @{
                           SignerNotificationSignerKey: self,
                           SignerNotificationBalanceKey: balance,
                           SignerNotificationFormerBalanceKey: oldBalance,
                           };
    dispatch_async(dispatch_get_main_queue(), ^() {
        [[NSNotificationCenter defaultCenter] postNotificationName:SignerBalanceDidChangeNotification
                                                            object:weakSelf
                                                          userInfo:info];
    });
}

- (BigNumber*)balance {
    NSString *key = [DataStoreKeyBalancePrefix stringByAppendingString:self.address.checksumAddress];
    NSString *valueHex = [_dataStore stringForKey:key];
    if (!valueHex) { return [BigNumber constantZero]; }
    BigNumber *value = [BigNumber bigNumberWithHexString:valueHex];
    if (!value) { return [BigNumber constantZero]; }
    return value;
}

- (NSUInteger)blockNumber {
    return [_dataStore integerForKey:[DataStoreKeyBlockNumberPrefix stringByAppendingString:_address.checksumAddress]];
}

- (void)_setTransactionCount: (NSUInteger)transactionCount {
    NSUInteger oldTransactionCount = self.transactionCount;
    if (oldTransactionCount == transactionCount) { return; }

    NSString *key = [DataStoreKeyNoncePrefix stringByAppendingString:self.address.checksumAddress];
    [_dataStore setInteger:transactionCount forKey:key];
}

- (NSUInteger)transactionCount {
    NSString *transactionCountKey = [DataStoreKeyNoncePrefix stringByAppendingString:self.address.checksumAddress];
    return [_dataStore integerForKey:transactionCountKey];
}


- (void)_setTransactionHistory: (NSArray<TransactionInfo*>*)transactionHistory {
    
    // Sort the transactions by blocktime and fallback onto hash (@TODO: Maybe from + nonce makes more sense?)
    NSMutableArray<TransactionInfo*> *transactions = [transactionHistory mutableCopy];
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
    
    BOOL truncatedTransactionHistory = NO;
    
    // Large historys get truncated
    if (transactions.count > 100) {
        truncatedTransactionHistory = YES;
        [transactions removeObjectsInRange:NSMakeRange(100, transactions.count - 100)];
    }
    
    NSArray *oldTransactionHistory = self.transactionHistory;
    
    NSMutableDictionary *oldTransactionsByHash = [NSMutableDictionary dictionaryWithCapacity:oldTransactionHistory.count];
    for (TransactionInfo *oldEntry in oldTransactionHistory) {
        [oldTransactionsByHash setObject:oldEntry forKey:oldEntry.transactionHash];
    }
    
    NSMutableArray *changedTransactions = [NSMutableArray array];
    NSMutableArray *serialized = [NSMutableArray arrayWithCapacity:transactions.count];
    for (TransactionInfo *entry in transactions) {
        
        [serialized addObject:[entry dictionaryRepresentation]];
        
        // Does this entry match any old entry?
        TransactionInfo *oldEntry = [oldTransactionsByHash objectForKey:entry.transactionHash];
        if (oldEntry && [[oldEntry dictionaryRepresentation] isEqual:[entry dictionaryRepresentation]]) {
            continue;
        }

        [changedTransactions addObject:entry];
    }
    
    NSString *key = [DataStoreKeyTransactionHistoryPrefix stringByAppendingString:self.address.checksumAddress];
    [_dataStore setObject:serialized forKey:key];
    
    if (changedTransactions.count) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            NSDictionary *userInfo = @{
                                       SignerNotificationSignerKey: self,
                                       };
            [[NSNotificationCenter defaultCenter] postNotificationName:SignerHistoryUpdatedNotification
                                                                object:self
                                                              userInfo:userInfo];
            
            for (TransactionInfo *entry in changedTransactions) {
                NSDictionary *userInfo = @{
                                           SignerNotificationSignerKey: self,
                                           SignerNotificationTransactionKey: entry
                                           };
                [[NSNotificationCenter defaultCenter] postNotificationName:SignerTransactionDidChangeNotification
                                                                    object:self
                                                                  userInfo:userInfo];
            }
        });
    }
}

- (NSArray<TransactionInfo*>*)transactionHistory {
    NSString *key = [DataStoreKeyTransactionHistoryPrefix stringByAppendingString:self.address.checksumAddress];
    NSArray<NSDictionary*> *serialized = (NSArray*)[_dataStore objectForKey:key];

    if (!serialized || ![serialized isKindOfClass:[NSArray class]]) {
        return @[];
    }
    
    NSMutableArray *transactionHistory = [NSMutableArray arrayWithCapacity:serialized.count];
    
    for (NSDictionary *info in serialized) {
        TransactionInfo *transaction = [TransactionInfo transactionInfoFromDictionary:info];
        if (!transaction) {
            NSLog(@"Bad Transaction: %@", info);
            continue;
        }
        [transactionHistory addObject:transaction];
    }

    return transactionHistory;
}


#pragma mark - Signing

- (BOOL)supportsFingerprintUnlock {
    return NO;
}

- (void)fingerprintUnlockCallback: (void (^)(Signer*, NSError*))callback {
    __weak Signer *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^() {
        callback(weakSelf, [NSError errorWithDomain:@"foo" code:234 userInfo:@{}]);
    });
}

- (BOOL)supportsSign {
    return NO;
}

//- (void)sign: (Transaction*)transaction callback: (void (^)(Transaction*, NSError*))callback {
//    dispatch_async(dispatch_get_main_queue(), ^() {
//        callback(transaction, [NSError errorWithDomain:@"foo" code:234 userInfo:@{}]);
//    });
//}

- (void)send:(Transaction *)transaction callback:(void (^)(Transaction *, NSError *))callback {
    dispatch_async(dispatch_get_main_queue(), ^() {
        callback(nil, [NSError errorWithDomain:PromiseErrorDomain code:1 userInfo:@{@"a": @"B"}]);
    });
}

- (BOOL)hasPassword {
    return NO;
}

- (BOOL)isUnlocked {
    return NO;
}

- (void)lock {
}

- (void)cancelUnlock {
}

- (void)unlock: (NSString*)password callback: (void (^)(Signer*, NSError*))callback {
    __weak Signer *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^() {
        callback(weakSelf, [NSError errorWithDomain:@"foo" code:234 userInfo:@{}]);
    });
}


#pragma mark - NSObject

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@ index=%d address=%@ nickname='%@' balance=%@ nonce=%d chainId=%d>",
            NSStringFromClass([self class]), (int)self.accountIndex, self.address, self.nickname,
            [Payment formatEther:self.balance], (int)self.transactionCount, (self.provider.testnet ? ChainIdRopsten: ChainIdHomestead)];
}

@end
