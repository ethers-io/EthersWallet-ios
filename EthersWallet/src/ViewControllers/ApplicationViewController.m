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

#import "EthersScriptHandler.h"
#import "ModalViewController.h"
#import "UIColor+hex.h"
#import "Utilities.h"
#import "Wallet.h"


@import WebKit;


@interface ApplicationViewController () <EthersScriptHandlerDelegate, WKNavigationDelegate, WKUIDelegate> {
    EthersScriptHandler *_etherScriptHandler, *_web3ScriptHandler;
    
    UIButton *_backButton, *_forwardButton;
    
    WKNavigation *_loading;
}

@property (nonatomic, readonly) UIView *toolbarContainer;
@property (nonatomic, readonly) WKWebView *webView;

@end


@implementation ApplicationViewController

- (instancetype)initWithApplicationTitle:(NSString *)applicationTitle url:(NSURL *)url wallet:(Wallet *)wallet {
    self = [super init];
    if (self) {
        _applicationTitle = applicationTitle;
        _url = url;
        
        _wallet = wallet;
        
        _etherScriptHandler = [[EthersScriptHandler alloc] initWithName:@"Ethers" wallet:wallet];
        _etherScriptHandler.delegate = self;

        _web3ScriptHandler = [[EthersScriptHandler alloc] initWithName:@"Web3" wallet:wallet];
        _web3ScriptHandler.delegate = self;

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
    
    CGSize size = self.view.frame.size;
    
    NSLog(@"Updating: %f %f", topMargin, bottomMargin);
    
//    CGFloat dTop = _webView.scrollView.contentInset.top - topMargin - 44.0f;
    //CGFloat dTop = -(topMargin + 44.0f);
    //_loadingContentOffset = CGPointMake(0.0f, -(topMargin + 44.0f));

    _webView.frame = CGRectMake(0.0f, topMargin + 44.0f, size.width, size.height - topMargin - 44.0f);
    _webView.scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0, bottomMargin + 44.0f, 0);
    _webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0f, 0.0f, bottomMargin + 44.0f, 0.0f);
    //_webView.scrollView.contentOffset = CGPointMake(0.0f, _webView.scrollView.contentOffset.y + dTop);
    
    _toolbarContainer.frame = CGRectMake(0.0f, size.height - 44.0f - bottomMargin, size.width, 44.0f + bottomMargin);
}

- (void)loadView {
    [super loadView];
    
    CGSize size =  self.view.frame.size;
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.applicationNameForUserAgent = [Utilities userAgent];
    config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    
    {
        NSError *error = nil;
        NSString *source = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ethers-web3" withExtension:@"js"]
                                                    encoding:NSUTF8StringEncoding
                                                       error:&error];
        
        if (error) {
            NSLog(@"Error Opening File: %@", error);
        }
        
        NSString *defaultAccount = @"";
        if (_wallet.activeAccountAddress) { defaultAccount = _wallet.activeAccountAddress.checksumAddress; }
        
        NSString *networkName = chainName(_wallet.activeAccountProvider.chainId);
        if (!networkName) { networkName = @"unknown"; }
        
        // Inject the account
        source = [source stringByReplacingOccurrencesOfString:@"__ETHERS_DEFAULT_ACCOUNT__" withString:defaultAccount];
        source = [source stringByReplacingOccurrencesOfString:@"__ETHERS_NETWORK__" withString:networkName];
        
        WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:YES];
        
        [config.userContentController addScriptMessageHandler:_etherScriptHandler name:_etherScriptHandler.name];
        [config.userContentController addScriptMessageHandler:_web3ScriptHandler name:_web3ScriptHandler.name];
        [config.userContentController addUserScript:script];
    }
    
    _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0.0f, 44.0f, size.width, size.height - 44.0f) configuration:config];
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webView.navigationDelegate = self;
    _webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _webView.UIDelegate = self;
    [self.view addSubview:_webView];
    _loading = [_webView loadRequest:[NSURLRequest requestWithURL:_url]];
    
    UIButton *backButton = [Utilities ethersButton:ICON_NAME_BACK fontSize:18.0f color:ColorHexToolbarIcon];
    [backButton addTarget:self action:@selector(buttonBack:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *forwardButton = [Utilities ethersButton:ICON_NAME_FORWARD fontSize:18.0f color:ColorHexToolbarIcon];
    [forwardButton addTarget:self action:@selector(buttonForward:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *refreshButton = [Utilities ethersButton:ICON_NAME_REFRESH fontSize:22.0f color:ColorHexToolbarIcon];
    [refreshButton addTarget:self action:@selector(buttonRefresh:) forControlEvents:UIControlEventTouchUpInside];

    _toolbarContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0f, size.height - 44.0f, size.width, 44.0f)];
    [self.view addSubview:_toolbarContainer];
    
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent]];
    visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    visualEffectView.frame = _toolbarContainer.bounds;
    [_toolbarContainer addSubview:visualEffectView];
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, 44.0f)];

    toolbar.items = @[
                      [[UIBarButtonItem alloc] initWithCustomView:backButton],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                      [[UIBarButtonItem alloc] initWithCustomView:forwardButton],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(buttonShare:)],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                      [[UIBarButtonItem alloc] initWithCustomView:refreshButton],
                      ];
    [toolbar setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];

    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [_toolbarContainer addSubview:toolbar];
    
    __weak ApplicationViewController *weakSelf = self;
    void (^checkButtons)(NSTimer*) = ^(NSTimer *timer) {
        if (!weakSelf) {
            NSLog(@"Killing refresh timer");
            [timer invalidate];
            return;
        }
        
        if (weakSelf.webView.canGoForward != forwardButton.enabled) {
            forwardButton.enabled = weakSelf.webView.canGoForward;
        }
        
        if (weakSelf.webView.canGoBack != backButton.enabled) {
            backButton.enabled = weakSelf.webView.canGoBack;
        }
        
    };
    
    [NSTimer scheduledTimerWithTimeInterval:0.5f repeats:YES block:checkButtons];
    checkButtons(nil);
}

- (void)buttonBack: (UIBarButtonItem*)sender {
    if ([_webView canGoBack]) {
        [_webView goBack];
    }
}

- (void)buttonForward: (UIBarButtonItem*)sender {
    if ([_webView canGoForward]) {
        [_webView goForward];
    }
}

- (void)buttonShare: (UIBarButtonItem*)sender {
    NSArray *shareItems = @[ _webView.URL ];
    
    UIActivityViewController *shareViewController = [[UIActivityViewController alloc] initWithActivityItems:shareItems
                                                                                      applicationActivities:nil];
    
    ModalViewController *modalViewController = [ModalViewController presentViewController:shareViewController animated:YES completion:nil];
    
    shareViewController.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        //NSLog(@"type=%@ compl=%d returned=%@ error=%@", type, completed, items, error);
        [modalViewController dismissViewControllerAnimated:YES completion:nil];
    };
}

- (void)buttonRefresh: (UIBarButtonItem*)sender {
    NSLog(@"BB: %@", NSStringFromCGPoint(_webView.scrollView.contentOffset));
    _loading = [_webView reloadFromOrigin];
    
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

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (navigation == _loading) {
        // Loaded content
    }
}

/*
- (void)webViewDidClose:(WKWebView *)webView {
    
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    //NSLog(@"Commit: %@", navigation);
}


- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    //NSLog(@"Fai: %@ %@", navigation, error);
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    //NSLog(@"Term: %@", webView);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    //NSLog(@"Provision: %@", navigation);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"Decide: %@", navigationAction);
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSLog(@"Decide2: %@", navigationResponse);
    decisionHandler(WKNavigationResponsePolicyAllow);
}
*/

#pragma mark - WKUIDelegte Protocol


@end
