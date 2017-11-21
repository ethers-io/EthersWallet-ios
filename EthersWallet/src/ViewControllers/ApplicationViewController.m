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

#import "ApplicationViewController.h"

#import <ethers/ApiProvider.h>
#import <ethers/SecureData.h>

#import "UIColor+hex.h"
#import "Utilities.h"
#import "Wallet.h"


static const NSString* const EthersVersion = @"v\x01\n";


@import WebKit;

Transaction *getTransaction(NSDictionary *info) {
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


#pragma mark -
#pragma mark - EtherScriptHandler

@class EthersScriptHandler;

@protocol EthersScriptHandlerDelegate <NSObject>

- (void)ethersScriptHandler: (EthersScriptHandler*)ethersScriptHandler evaluateJavaScript: (NSString*)script;

@end


@interface EthersScriptHandler : NSObject <WKScriptMessageHandler> {
    NSInteger _lastBlockNumber;
    BOOL _ready;
}

- (instancetype)initWithWallet: (Wallet*)wallet;

@property (nonatomic, readonly) Wallet *wallet;

@property (nonatomic, weak) NSObject<EthersScriptHandlerDelegate> *delegate;

@end


@implementation EthersScriptHandler

- (instancetype)initWithWallet:(Wallet *)wallet {
    self = [super init];
    if (self) {
        _wallet = wallet;
        

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
    NSLog(@"ScriptHandler Dealloc: %@", self);
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
        NSLog(@">>> %@", response);
    //}

    NSError *error = nil;
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
    
    if (error) {
        NSLog(@"Response Error: %@", error);
        return;
        
    }
    
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSString *script = [NSString stringWithFormat:@"parent._ethersRespond(%@)", responseString];
    
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
    
    if (![message.name isEqualToString:@"ethers"]) {
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

    NSLog(@"<<< %@", data);
    
    
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


@interface ApplicationViewController () <EthersScriptHandlerDelegate, WKNavigationDelegate, WKUIDelegate> {
    WKWebView *_webView;
    EthersScriptHandler *_etherScriptHandler;
}

@end


@implementation ApplicationViewController

- (instancetype)initWithApplicationTitle:(NSString *)applicationTitle url:(NSURL *)url wallet:(Wallet *)wallet {
    self = [super init];
    if (self) {
        _applicationTitle = applicationTitle;
        _url = url;
        
        _wallet = wallet;
        _etherScriptHandler = [[EthersScriptHandler alloc] initWithWallet:wallet];
        _etherScriptHandler.delegate = self;
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 40.0f)];
        titleLabel.font = [UIFont fontWithName:FONT_MEDIUM size:20.0f];
        titleLabel.text = applicationTitle;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = [UIColor colorWithHex:ColorHexNavigationBarTitle];
        
        self.navigationItem.titleView = titleLabel;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notifyActiveAccountDidChange:)
                                                     name:WalletActiveAccountDidChangeNotification
                                                   object:_wallet];
    }
    return self;
}

- (void)notifyActiveAccountDidChange: (NSNotification*)note {
    NSLog(@"Warning: Active user changed during application; shutting down app (state may not be consistent)");
    
    _webView.userInteractionEnabled = NO;
    _webView.alpha = 0.5f;
    
    // @TODO: Put up a message explaining this
}

- (void)dealloc {
    // Make sure we allow the webview, et al to be cleaned up
    [_webView.configuration.userContentController removeAllUserScripts];
    [_webView.configuration.userContentController removeScriptMessageHandlerForName:@"ethers"];
    
    // Stop listening for events
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateTopMargin:(CGFloat)topMargin bottomMargin:(CGFloat)bottomMargin {
    [super updateTopMargin:topMargin bottomMargin:bottomMargin];
    
    CGFloat dTop = _webView.scrollView.contentInset.top - topMargin - 44.0f;
    _webView.scrollView.contentInset = UIEdgeInsetsMake(topMargin + 44.0f, 0, bottomMargin, 0);
    _webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(topMargin + 44.0f, 0.0f, bottomMargin, 0.0f);
    _webView.scrollView.contentOffset = CGPointMake(0.0f, _webView.scrollView.contentOffset.y + dTop);
}

- (void)loadView {
    [super loadView];
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.applicationNameForUserAgent = [Utilities userAgent];
    config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    
    {
        NSError *error = nil;
        NSString *source = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ethers" withExtension:@"js"]
                                                    encoding:NSUTF8StringEncoding
                                                       error:&error];
        
        if (error) {
            NSLog(@"Error Opening File: %@", error);
        }
        
        WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:YES];
        
        [config.userContentController addScriptMessageHandler:_etherScriptHandler name:@"ethers"];
        [config.userContentController addUserScript:script];
    }
    
    _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webView.navigationDelegate = self;
    _webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _webView.UIDelegate = self;
    [self.view addSubview:_webView];
    [_webView loadRequest:[NSURLRequest requestWithURL:_url]];
}

#pragma mark - EthersScriptHandler

- (void)ethersScriptHandler:(EthersScriptHandler *)ethersScriptHandler evaluateJavaScript:(NSString *)script {
    [_webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"JavaScript Error: %@ (%@)", error, script);
        }
    }];
}

#pragma mark - WKUIDelegate

- (WKWebView*)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {

    NSURL *url = navigationAction.request.URL;
    if (![url.scheme isEqualToString:@"https"] && ![url.scheme isEqualToString:@"http"]) {
        url = nil;
    }
    
    if (url) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[UIApplication sharedApplication] openURL:navigationAction.request.URL
                                               options:@{}
                                     completionHandler:nil];
        });
    }
    
    return nil;
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    
    if (![webView.URL.host isEqualToString:frame.request.URL.host]) {
        NSLog(@"ApplicationViewController: Security Warning webviewHost=%@ frameHost=%@", webView.URL.host, frame.request.URL.host);
        completionHandler();
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:_applicationTitle
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    {
        void (^action)(UIAlertAction*) = ^(UIAlertAction *action) {
            completionHandler();
        };
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:action]];
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    NSLog(@"Confirm: %@ %@", message, frame);
    
    if (![webView.URL.host isEqualToString:frame.request.URL.host]) {
        NSLog(@"ApplicationViewController: Security Warning webviewHost=%@ frameHost=%@", webView.URL.host, frame.request.URL.host);
        completionHandler(NO);
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:_applicationTitle
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    {
        void (^action)(UIAlertAction*) = ^(UIAlertAction *action) {
            completionHandler(NO);
        };
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:action]];
    }

    {
        void (^action)(UIAlertAction*) = ^(UIAlertAction *action) {
            completionHandler(YES);
        };
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:action]];
    }

    [self presentViewController:alert animated:YES completion:nil];

}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler {

    if (![webView.URL.host isEqualToString:frame.request.URL.host]) {
        NSLog(@"ApplicationViewController: Security Warning webviewHost=%@ frameHost=%@", webView.URL.host, frame.request.URL.host);
        completionHandler(nil);
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:_applicationTitle
                                                                   message:prompt
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
    }];
    
    {
        void (^action)(UIAlertAction*) = ^(UIAlertAction *action) {
            completionHandler([alert.textFields firstObject].text);
        };
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:action]];
    }

    {
        void (^action)(UIAlertAction*) = ^(UIAlertAction *action) {
            completionHandler(nil);
        };
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:action]];
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webViewDidClose:(WKWebView *)webView {
    
}


#pragma mark - WKUIDelegte Protocol


@end
