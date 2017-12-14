//
//  EthersScriptHandler.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-12-11.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "EthersScriptHandler.h"

#import <ethers/ApiProvider.h>
#import <ethers/SecureData.h>

#import "Utilities.h"


static Transaction *getTransaction(NSDictionary *info) {
    if (!info) { return nil; }
    
    Transaction *transaction = nil;
    
    {
        Address *fromAddress = queryPath(info, @"dictionary:from/address");
        if (fromAddress) {
            transaction = [Transaction transactionWithFromAddress:fromAddress];
        } else {
            transaction = [Transaction transaction];
        }
    }
    
    {
        Address *toAddress = queryPath(info, @"dictionary:to/address");
        if (toAddress) { transaction.toAddress = toAddress; }
    }
    
    {
        BigNumber *gasLimit = queryPath(info, @"dictionary:gasLimit/bigNumber");
        if (gasLimit) { transaction.gasLimit = gasLimit; }
    }
    
    {
        BigNumber *gasPrice = queryPath(info, @"dictionary:gasPrice/bigNumber");
        if (gasPrice) { transaction.gasPrice = gasPrice; }
    }
    
    {
        BigNumber *value = queryPath(info, @"dictionary:value/bigNumber");
        if (value) { transaction.value = value; }
    }
    
    {
        NSData *data = queryPath(info, @"dictionary:data/data");
        if (data) { transaction.data = data; }
    }
    
    return transaction;
}


@import WebKit;

static const NSString* const EthersVersion = @"v\x01\n";


@implementation EthersScriptHandler {
    NSInteger _lastBlockNumber;
    BOOL _ready;
}

- (instancetype)initWithName:(NSString *)name wallet:(Wallet *)wallet {
    self = [super init];
    if (self) {
        _wallet = wallet;
        _name = name;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notifyActiveAccountDidChange:)
                                                     name:WalletActiveAccountDidChangeNotification
                                                   object:_wallet];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notifyDidReceiveNewBlock:)
                                                     name:ProviderDidReceiveNewBlockNotification
                                                   object:_wallet.activeAccountProvider];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)notifyActiveAccountDidChange: (NSNotification*)note {
    if (!_ready) { return; }
    
    NSObject *account = _wallet.activeAccountAddress.checksumAddress;
    if (!account) { account = [NSNull null]; }
    
    [self send:@{ @"action": @"accountChanged", @"account": account }];
}

- (void)notifyDidReceiveNewBlock: (NSNotification*)note {
    NSUInteger blockNumber = [[note.userInfo objectForKey:@"blockNumber"] integerValue];
    if (!_ready || _lastBlockNumber == blockNumber) { return; }
    
    _lastBlockNumber = blockNumber;
    
    //[self send:@{ @"action": @"block", @"blockNumber": @(blockNumber), @"ethers": EthersVersion }];
}

- (void)send: (NSDictionary*)response {
    //if ([response objectForKey:@"id"]) {
    //NSLog(@">>> %@", response);
    //}
    
    NSError *error = nil;
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
    
    if (error) {
        NSLog(@"Response Error: %@", error);
        return;
        
    }
    
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSString *script = [NSString stringWithFormat:@"parent._respond%@(%@)", _name, responseString];
    
    [_delegate ethersScriptHandler:self evaluateJavaScript:script];
}

- (void)sendResult: (NSObject*)result messageId: (NSInteger)messageId {
    NSDictionary *response = @{ @"id": @(messageId), @"ethers": EthersVersion, @"result": result };
    [self send:response];
}

- (void)sendError: (NSString*)error messageId: (NSInteger)messageId {
    NSDictionary *response = @{ @"id": @(messageId), @"ethers": EthersVersion, @"error": error };
    [self send:response];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message  {
    //NSLog(@"<<<M %@", message);
    
    if (![message.name isEqualToString:_name]) {
        NSLog(@"WARNING! Unknown messge handler: %@", message.name);
        return;
    }
    
    if (!message.frameInfo.mainFrame) {
        NSLog(@"WARNING! Wrong frame: %@", message.frameInfo);
        return;
    }
    
    NSDictionary *data = coerceValue(message.body, ApiProviderFetchTypeDictionary);
    if (!data) {
        NSLog(@"WARNING! Invalid message body: %@", message.body);
        return;
    }
    
    
    NSString *action = queryPath(data, @"dictionary:action/string");
    if (!action) {
        NSLog(@"Application: Unknown action %@", data);
        return;
    }
    
    NSDictionary *params = queryPath(data, @"dictionary:params/dictionary");
    if (!params) {
        params = @{};
    }
    
    NSInteger messageId = 0;
    {
        NSNumber *messageIdObject = queryPath(data, @"dictionary:id/integer");
        if (messageIdObject) { messageId = [messageIdObject integerValue]; }
    }
    
    //NSLog(@"<<< %@", data);
    
    
    /**
     *  Debug console
     */
    if ([action isEqualToString:@"console.log"]) {
        NSLog(@"console.log(%@)", [data objectForKey:@"message"]);
        
        
        /**
         *  Accounts and Network
         */
        
    } else if ([action isEqualToString:@"getAccount"]) {
        if (_wallet.activeAccountAddress) {
            [self sendResult:_wallet.activeAccountAddress.checksumAddress messageId:messageId];
        } else {
            [self sendResult:[NSNull null] messageId:messageId];
        }
        
    } else if ([action isEqualToString:@"getNetwork"]) {
        NSString *networkName = nil;
        switch (_wallet.activeAccountProvider.chainId) {
            case ChainIdHomestead:
                networkName = @"mainnet";
                break;
            case ChainIdRopsten:
                networkName = @"testnet";
                break;
            default:
                networkName = chainName(_wallet.activeAccountProvider.chainId);
                break;
        }
        [self sendResult:networkName messageId:messageId];
        
    } else if ([action isEqualToString:@"fundAccount"]) {
        
        if (_wallet.activeAccountProvider.chainId == ChainIdRopsten) {
            
            Address *address = queryPath(params, @"dictionary:address/address");
            if (!address) {
                [self sendError:@"invalid address" messageId:messageId];
                
            } else {
                
                void (^handleResponse)(NSData*, NSURLResponse*, NSError*) = ^(NSData *data, NSURLResponse *response, NSError *error) {
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                    
                    if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]] || httpResponse.statusCode != 200) {
                        [self sendError:@"Server Error" messageId:messageId];
                        return;
                    }
                    
                    Hash *hash = queryPath(data, @"json:hash/hash");
                    if (!hash) {
                        [self sendError:@"Server Error" messageId:messageId];
                        return;
                    }
                    
                    [self sendResult:hash.hexString messageId:messageId];
                };
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
                    NSString *urlFormat = @"https://api.ethers.io/api/v1/?action=fundAccount&address=%@";
                    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:urlFormat, address]];
                    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
                    [request setValue:[Utilities userAgent] forHTTPHeaderField:@"User-Agent"];
                    
                    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
                    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:handleResponse];
                    [task resume];
                });
            }
            
        } else {
            [self sendError:@"invalid network" messageId:messageId];
        }
        
        
        /**
         *  Blockchain (permissioned calls)
         */
        
    } else if ([action isEqualToString:@"signMessage"]) {

        if (!_wallet.activeAccountAddress) {
            [self sendError:@"cancelled" messageId:messageId];
            
        } else {
            NSData *message = [SecureData hexStringToData:queryPath(params, @"dictionary:message/string")];
            if (!message) {
                [self sendError:@"invalid message" messageId:messageId];
            
            } else {
                [_wallet signMessage:message callback:^(Signature *signature, NSError *error) {
                    if (error) {
                        [self sendError:@"cancelled" messageId:messageId];
                        return;
                    }
                    
                    SecureData *signatureData = [SecureData secureDataWithCapacity:65];
                    [signatureData appendData:signature.r];
                    [signatureData appendData:signature.s];
                    [signatureData appendByte:signature.v + 27];
                    [self sendResult:[SecureData dataToHexString:signatureData.data] messageId:messageId];
                }];
            }
        }
        

    } else if ([action isEqualToString:@"sendTransaction"]) {

        if (!_wallet.activeAccountAddress) {
            [self sendError:@"cancelled" messageId:messageId];
            
        } else {
            
            Transaction *transaction = getTransaction([params objectForKey:@"transaction"]);
            
            if (!transaction) {
                [self sendError:@"invalid parameter" messageId:messageId];
                
            } else {
                [_wallet sendTransaction:transaction callback:^(Transaction *transaction, NSError *error) {
                    if (transaction) {
                        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:8];
                        
                        if (transaction.toAddress) {
                            [result setObject:transaction.toAddress.checksumAddress forKey:@"to"];
                        }
                        
                        [result setObject:transaction.fromAddress.checksumAddress forKey:@"from"];
                        [result setObject:@(transaction.nonce) forKey:@"nonce"];
                        [result setObject:[transaction.gasLimit hexString] forKey:@"gasLimit"];
                        [result setObject:[transaction.gasPrice hexString] forKey:@"gasPrice"];
                        [result setObject:[transaction.value hexString] forKey:@"value"];
                        [result setObject:[SecureData dataToHexString:transaction.data] forKey:@"data"];
                        
                        [result setObject:[transaction.transactionHash hexString] forKey:@"hash"];
                        
                        [self sendResult:result messageId:messageId];
                        
                    } else if ([error.domain isEqualToString:WalletErrorDomain] && error.code == WalletErrorSendCancelled) {
                        [self sendError:@"cancelled" messageId:messageId];
                        
                    } else {
                        [self sendError:@"unknown error" messageId:messageId];
                    }
                }];
                
            }
        }
        
        /**
         *  Ready
         */
        
    } else if ([action isEqualToString:@"notify"]) {
        NSLog(@"Not Implemented: notify");
        
    } else if ([action isEqualToString:@"ready"]) {
        _ready = YES;
        
        // @TODO: Remove loading animation
        
        _lastBlockNumber = _wallet.activeAccountBlockNumber;
        
        [self send:@{@"action": @"ready"}];
        //[self send:@{@"action": @"block", @"blockNumber": @(_lastBlockNumber)}];
        
    } else {
        NSLog(@"Unknown action: %@ (data: %@)", action, data);
    }
    
}

@end

