//
//  SignedRemoteDictionary.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-08-23.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ethers/Address.h>
#import <ethers/Promise.h>

extern const NSErrorDomain SignedRemoteDictionaryErrorDomain;

typedef enum SignedRemoteDictionaryError {
    SignedRemoteDictionaryErrorNetwork            =  -1,
    SignedRemoteDictionaryErrorBadSignature       =  -10,
} SignedRemoteDictionaryError;


@interface SignedRemoteDictionary : NSObject

+ (instancetype)dictionaryWithUrl: (NSString*)url address: (Address*)address defaultData: (NSDictionary*)defaultData;

@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) Address *address;

@property (nonatomic, readonly) NSTimeInterval updatedDate;

// The maximum age preferred to allow stale data to be used
@property (nonatomic, readonly) NSTimeInterval preferredMaximumStaleAge;

// The maximum amount of time to wait for a response (default 3.0s)
@property (nonatomic, readonly) NSTimeInterval maximumTimeout;


// The current data
@property (nonatomic, readonly) NSDictionary *currentData;


- (DictionaryPromise*)data;

@end
