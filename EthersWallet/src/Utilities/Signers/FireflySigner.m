/**
 *  MIT License
 *
 *  Copyright (c) 2018 Richard Moore <me@ricmoo.com>
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

#import <ethers/SecureData.h>

#import "FireflySigner.h"

#import "BLECast.h"
#import "FireflyScannerConfigController.h"

@interface CloudKeychainSigner (private)

- (NSString*)_json;
- (BOOL)_remove;
- (void)_send:(Transaction *)transaction callback:(void (^)(Transaction *, NSError *))callback;

@end


@interface FireflySigner () <BLECastDelegate>
@end


@implementation FireflySigner {
    BLECast *_currentBroadcast;
}

+ (instancetype)writeToKeychain:(NSString *)keychainKey
                       nickname:(NSString *)nickname
                           json:(NSString *)json
                       provider:(Provider *)provider {
    
    // Do not allow this class to write standard JSON wallets
    return nil;
}

+ (instancetype)writeToKeychain:(NSString *)keychainKey
                       nickname:(NSString *)nickname
                        address:(Address *)address
                      secretKey:(NSData *)secretKey
                       provider:(Provider *)provider {
    
    NSString *json = [NSString stringWithFormat:@"{\"address\": \"%@\", \"secretKey\":\"%@\", \"version\": \"firefly/v0\"}",
                      [address checksumAddress], [SecureData dataToHexString:secretKey]];

    FireflySigner *signer = [super writeToKeychain:keychainKey nickname:nickname json:json provider:provider];
    [signer _setVersion:0];
    return signer;
}

+ (instancetype)signerWithKeychainKey:(NSString *)keychainKey address:(Address *)address provider:(Provider *)provider {
    FireflySigner *signer = [super signerWithKeychainKey:keychainKey address:address provider:provider];
    [signer _setVersion:0];
    return signer;
}

- (void)_setVersion:(uint8_t)version {
    _version = 0;
}

- (bool)remove {
    return [super _remove];
}

- (BOOL)supportsBiometricUnlock {
    return NO;
}

- (void)unlockBiometricCallback:(void (^)(Signer *, NSError *))callback {
    [self cancelUnlock];
    
    __weak CloudKeychainSigner *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^() {
        callback(weakSelf, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorUnsupported userInfo:@{}]);
    });
}

#pragma mark - Broadcasting

- (BOOL)broadcast: (NSData*)data {
    if (_currentBroadcast) {
        NSLog(@"Stopping broadcast");
        [_currentBroadcast stop];
        _currentBroadcast = nil;
    }
    
    // Nil data means stop
    if (!data) { return NO; }
    
    NSLog(@"Starting Broadcast");

    // Get the Firefly JSON description
    NSString *json = [self _json];
    if (!json) { return NO; }
    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                         options:0
                                                           error:&error];
    
    if (!info || error) {
        NSLog(@"FireflySigner - Error decoding JSON: %@", error);
        return NO;
    }

    // Get the secret key we use for broadcasting
    NSData *secretKey = [SecureData hexStringToData:[info objectForKey:@"secretKey"]];
    if (!secretKey) { return NO; }

    // Start broadcasting
    _currentBroadcast = [BLECast bleCastWithKey:secretKey data:data];
    _currentBroadcast.delegate = self;
    [_currentBroadcast start];
    
    return (_currentBroadcast != nil);
}

- (void)cancel {
    [self broadcast:nil];
}

- (void)bleCastDidBegin:(BLECast *)bleCast {
    //NSLog(@"Did begin broadcasting");
}

- (void)bleCast:(BLECast *)bleCast didHopPayload:(NSData *)payload index:(uint8_t)index {
    //NSLog(@"Did Hop Payload: %d: %@", index, payload);
}

#pragma mark - Sending

- (ConfigController*)send:(Transaction *)transaction callback:(void (^)(Transaction *, NSError *))callback {
    transaction = [transaction copy];
    
    NSLog(@"FireflySigner: Sending - address=%@ transaction=%@", self.address.checksumAddress, transaction);
    
    __weak FireflySigner *weakSelf = self;
    
    NSData *unsignedTransaction = [transaction unsignedSerialize];
    SecureData *data = [SecureData secureDataWithCapacity:unsignedTransaction.length + 1];
    [data appendByte:0x00];
    [data appendData:unsignedTransaction];
    
    BOOL broadcasting = [self broadcast:data.data];
    
    if (!broadcasting) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorTransactionTooBig userInfo:@{}]);
        });
        return nil;
    }
    
    FireflyScannerConfigController *scanner = [FireflyScannerConfigController configWithSigner:self transaction:transaction];
    
    scanner.didSignTransaction = ^(FireflyScannerConfigController *config, Transaction *transaction) {
        NSLog(@"FireflySigner - Signed: %@", [transaction serialize]);
        [weakSelf cancel];
        config.navigationItem.rightBarButtonItem.enabled = NO;
        if (!callback) { return; }
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        [weakSelf _send:transaction callback:^(Transaction *transaction, NSError *error) {
            if (error) {
                config.navigationItem.rightBarButtonItem.enabled = YES;
                callback(transaction, error);
                return;
            }

            // Wait at least 2 seconds after scanning
            const NSTimeInterval minimumWaitTime = 2.0f;
            NSTimeInterval delta = [NSDate timeIntervalSinceReferenceDate] - now;
            if (delta > minimumWaitTime) {
                callback(transaction, error);
            } else {
                [NSTimer scheduledTimerWithTimeInterval:minimumWaitTime - delta repeats:NO block:^(NSTimer *timer) {
                    callback(transaction, error);
                }];
            }
        }];
    };
    
    scanner.didCancel = ^(FireflyScannerConfigController *config) {
        [weakSelf cancel];
        if (!callback) { return; }
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorCancelled userInfo:@{}]);
        });
    };
    
    __weak FireflyScannerConfigController *weakScanner = scanner;
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer *timer) {
        if (!weakScanner) {
            NSLog(@"Dangling Scanner without a viewcontroller; stop broadcasting");
            [weakSelf cancel];
            [timer invalidate];
        }
    }];
    
    return scanner;
}

- (ConfigController*)signMessage: (NSData*)message callback: (void (^)(Signature*, NSError*))callback {
    // @TODO: Add support
    dispatch_async(dispatch_get_main_queue(), ^() {
        callback(nil, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorUnsupported userInfo:@{}]);
    });
    __weak FireflySigner *weakSelf = self;
    
    BOOL ascii = YES;
    const uint8_t *bytes = message.bytes;
    for (NSInteger i = 0; i < message.length; i++) {
        uint8_t c = bytes[i];
        if (c >= 32 && c < 127) { continue; }
        if (c == 10) { continue; }
        ascii = NO;
        break;
    }

    if ((ascii && message.length > 128) || (!ascii && message.length > 48)) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorTransactionTooBig userInfo:@{}]);
        });
        return nil;
    }

    SecureData *data = [SecureData secureDataWithCapacity:message.length + 1];
    [data appendByte:(ascii ? 0x01: 0x02)];
    [data appendData:message];
    
    BOOL broadcasting = [self broadcast:data.data];
    
    if (!broadcasting) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorTransactionTooBig userInfo:@{}]);
        });
        return nil;
    }
    
    FireflyScannerConfigController *scanner = [FireflyScannerConfigController configWithSigner:self message:message];
    
    scanner.didSignMessage = ^(FireflyScannerConfigController *config, Signature *signature) {
        [weakSelf cancel];
        if (!callback) { return; }
        
        // Wait at least 2 seconds after scanning
        const NSTimeInterval minimumWaitTime = 2.0f;
        [NSTimer scheduledTimerWithTimeInterval:minimumWaitTime repeats:NO block:^(NSTimer *timer) {
            callback(signature, nil);
        }];
    };
    
    scanner.didCancel = ^(FireflyScannerConfigController *config) {
        [weakSelf cancel];
        if (!callback) { return; }
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(nil, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorCancelled userInfo:@{}]);
        });
    };
    
    __weak FireflyScannerConfigController *weakScanner = scanner;
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer *timer) {
        if (!weakScanner) {
            NSLog(@"Dangling Scanner without a viewcontroller; stop broadcasting");
            [weakSelf cancel];
            [timer invalidate];
        }
    }];
    
    return scanner;
}

- (NSString*)textMessageFor: (SignerTextMessage)textMessageType {
    switch (textMessageType) {
        case SignerTextMessageSendButton:
            return @"Authorize with Firefly Wallet";
        case SignerTextMessageCancelButton:
            return @"Attempt Cancel";
        case SignerTextMessageSignButton:
            return @"Sign with Firefly Wallet";
    }
    return @"OK";
}

- (BOOL)supportsPasswordUnlock {
    return NO;
}

- (void)unlockPassword:(NSString *)password callback:(void (^)(Signer *, NSError *))callback {
    [self cancelUnlock];
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        callback(nil, [NSError errorWithDomain:SignerErrorDomain code:SignerErrorAccountLocked userInfo:@{}]);
    });
}

- (BOOL)unlocked {
    return YES;
}

- (BOOL)supportsMnemonicPhrase {
    return NO;
}

@end
