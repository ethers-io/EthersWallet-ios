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

#import "AppDelegate.h"

@import NotificationCenter;

#import "ApplicationViewController.h"
#import "CloudView.h"
#import "ModalViewController.h"
#import "PanelViewController.h"
#import "ScannerViewController.h"
#import "SharedDefaults.h"
#import "UIColor+hex.h"
#import "Utilities.h"
#import "Wallet.h"
#import "WalletViewController.h"

//#import "LightClientProvider.h"

@interface AppDelegate () <PanelViewControllerDataSource, ScannerDelegate> {
    UIWindow *_window;
    Provider *_debugProvider;
    PanelViewController *_panelViewController;
    
//    LightClientProvider *_lightClient;
    
    Wallet *_wallet;
    
    WalletViewController *_walletViewController;
    
    NSArray<NSString*> *_applicationTitles;
    NSArray<NSString*> *_applicationUrls;
}

@end


@implementation AppDelegate

#pragma mark - Life-Cycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

//    _lightClient = [[LightClientProvider alloc] initWithTestnet:NO];
    
    // Userful for finding fonts..
    if ((NO)) {
        for (NSString* family in [UIFont familyNames]) {
            NSLog(@"%@", family);
            for (NSString* name in [UIFont fontNamesForFamilyName: family]) {
                NSLog(@"  %@", name);
            }
        }
    }
    
    // Schedule us for background fetching
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    _wallet = [Wallet walletWithKeychainKey:@"io.ethers.sharedWallet"];
    _walletViewController = [[WalletViewController alloc] initWithWallet:_wallet];
    
    _panelViewController = [[PanelViewController alloc] initWithNibName:nil bundle:nil];
    _panelViewController.dataSource = self;
    [_panelViewController focusPanel:YES animated:NO];
    _panelViewController.navigationItem.titleView = [Utilities navigationBarLogoTitle];
    _panelViewController.titleColor = [UIColor colorWithWhite:1.0f alpha:1.0f];

    {
        CloudView *cloudView = [[CloudView alloc] initWithFrame:_panelViewController.view.bounds];
        cloudView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_panelViewController.backgroundView addSubview:cloudView];
    }
    
    {
        UIColor *navigationBarColor = [UIColor colorWithHex:ColorHexNavigationBar overHex:0xb3cffe alpha:0.2];
        [Utilities setupNavigationBar:_panelViewController.navigationBar backgroundColor:navigationBarColor];
    }

    _window.rootViewController = _panelViewController;
    
    [_window makeKeyAndVisible];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyDidChangeNetwork:)
                                                 name:WalletDidChangeNetwork
                                               object:_wallet];
    
    // If an account was added, we may now have a different primary account
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletAddedAccountNotification
                                               object:_wallet];

    // If an account was removed, we may now have a different primary account
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletRemovedAccountNotification
                                               object:_wallet];

    // If an account was re-ordered, we may now have a different primary account
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletReorderedAccountsNotification
                                               object:_wallet];

    // If the balance of the primary account changed, we need to update the widet
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletBalanceChangedNotification
                                               object:_wallet];

    NSURL *url = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
    if (url) {
        [self application:application openURL:url options:@{}];
    }
    
    [self notifyExtensions];
    
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupApplications {
    if (_wallet.provider.testnet) {
        _applicationTitles = @[@"Welcome", @"Testnet Faucet"];
        _applicationUrls = @[
                             @"https://0x5543707cc4520f3984656e8edea6527ca474e77b.ethers.space/",
                             @"https://0xa5681b1fbda76e0d4ab646e13460a94fdcd3c1c1.ethers.space/"
                             ];
    } else {
        _applicationTitles = @[@"Welcome", @"DevCon2 PoA"];
        _applicationUrls = @[
                             @"https://0x5543707cc4520f3984656e8edea6527ca474e77b.ethers.space/",
                             @"https://0x2f2ab85f856ec137699cbe5d8038110dd7ce9cbe.ethers.space/"
                             ];
    }
    
    [_panelViewController reloadData];
}

- (void)notifyDidChangeNetwork: (NSNotification*)note {
    [self setupApplications];
}

// iban://0x05ABcF02682E2b3fB6e38840Cd57d2ea77edd41F
// https://ethers.io/app-link/#!debug

- (Payment*)checkPasteboard {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if ([pasteboard hasStrings]) {
        for (NSString *string in [pasteboard strings]) {
            NSLog(@"Pasteboard String: %@", string);
            Payment *payment = [Payment paymentWithURI:string];
            if (payment) {
                NSLog(@"Paymnet: %@", payment);
                return payment;
            }
        }
    }
    
    if ([pasteboard hasURLs]) {
        for (NSURL *url in [pasteboard URLs]) {
            NSLog(@"Pasteboard URL: %@", url);
            Payment *payment = [Payment paymentWithURI:[url absoluteString]];
            if (payment) {
                NSLog(@"Paymnet: %@", payment);
                return payment;
            }
        }
    }

    return nil;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    [self notifyExtensions];

    Payment *payment = [self checkPasteboard];
    if (!payment || [payment.address isEqualToAddress:_wallet.activeAccount] || !_wallet.activeAccount) {
        return;
    }

    NSLog(@"Found: %@", payment);

    [ModalViewController dismissAllCompletionCallback:^() {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Clipboard Payment"
                                                                                 message:@"An Ethereum address was found in the clipboard."
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        void (^preparePayment)(UIAlertAction*) = ^(UIAlertAction *action) {
            [_wallet sendPayment:payment callback:^(Hash *hash, NSError *error) {
                NSLog(@"Sent: %@ %@", hash, error);
            }];
        };
        [alertController addAction:[UIAlertAction actionWithTitle:@"Prepare Payment"
                                                            style:UIAlertActionStyleDefault
                                                          handler:preparePayment]];
        
        void (^clearClipboard)(UIAlertAction*) = ^(UIAlertAction *action) {
            [[UIPasteboard generalPasteboard] setString:@""];
        };
        [alertController addAction:[UIAlertAction actionWithTitle:@"Clear Clipboard"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:clearClipboard]];
        
        void (^cancel)(UIAlertAction*) = ^(UIAlertAction *action) {
            
        };
        [alertController addAction:[UIAlertAction actionWithTitle:@"Do Nothing"
                                                            style:UIAlertActionStyleCancel
                                                          handler:cancel]];
        
        alertController.preferredAction = [alertController.actions firstObject];
        
        [ModalViewController presentViewController:alertController animated:YES completion:nil];
    }];
    
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - PanelViewControllerDataSource

- (NSUInteger)panelViewControllerPinnedChildCound: (PanelViewController*)panelViewController {
    return 1;
}

- (NSUInteger)panelViewControllerChildCount: (PanelViewController*)panelViewController {
    return 1 + _applicationTitles.count;
}

- (NSString*)panelViewController: (PanelViewController*)panelViewController titleAtIndex: (NSUInteger)index {
    if (index == 0) {
        return @"Wallet";
    }
    
    return [_applicationTitles objectAtIndex:index - 1];
}

- (UIViewController*)panelViewController: (PanelViewController*)panelViewController viewControllerAtIndex: (NSUInteger)index {
    
    if (index == 0) {
        return _walletViewController;
    }
    
    return [[ApplicationViewController alloc] initWithApplicationTitle:[_applicationTitles objectAtIndex:index - 1]
                                                                   url:[NSURL URLWithString:[_applicationUrls objectAtIndex:index - 1]]
                                                                wallet:_wallet];
}


#pragma mark - ScannerViewController

- (void)showScanner {
    [ModalViewController dismissAllCompletionCallback:^() {
        if (_wallet.activeAccount) {
            ScannerViewController *scannerViewController = [[ScannerViewController alloc] init];
            scannerViewController.delegate = self;
            
            [ModalViewController presentViewController:scannerViewController animated:NO completion:^() {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [scannerViewController startScanningAnimated:YES];
                });
            }];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Accounts"
                                                                           message:@"You must create an account before scanner QR codes."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
            [ModalViewController presentViewController:alert animated:NO completion:nil];
        }
    }];
}

- (BOOL)scannerViewController:(ScannerViewController *)scannerViewController shouldFinishWithMessage:(NSString *)message {
    return (([Payment paymentWithURI:message]) != nil);
}

- (void)scannerViewController:(ScannerViewController *)scannerViewController didFinishWithMessage:(NSString *)message {
    [scannerViewController.presentingViewController dismissViewControllerAnimated:YES completion:^() {
        if (message) {
            Payment *payment = [Payment paymentWithURI:message];
            [_wallet sendPayment:payment callback:^(Hash *transactionHash, NSError *error) {
                NSLog(@"TXHASH: %@ %@", transactionHash, error);
            }];
        }
    }];
}


#pragma mark - External launching

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    BOOL handled = NO;
    
    if ([url.host isEqualToString:@"scan"]) {
        [self showScanner];
        handled = YES;

    } else if ([url.host isEqualToString:@"wallet"]) {
        [ModalViewController dismissAll];
        [_panelViewController setViewControllerIndex:0 animated:NO];
        [_panelViewController focusPanel:YES animated:NO];
        [_walletViewController scrollToTopAnimated:NO];
        handled = YES;
    }
    
    return handled;
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    
    BOOL handled = NO;
    
    if ([shortcutItem.type isEqualToString:@"io.ethers.scan"]) {
        [_walletViewController scrollToTopAnimated:NO];
        [self showScanner];
        handled = YES;
        
    } else if ([shortcutItem.type isEqualToString:@"io.ethers.wallet"]) {
        [ModalViewController dismissAll];
        [_panelViewController setViewControllerIndex:0 animated:NO];
        [_panelViewController focusPanel:YES animated:NO];
        [_walletViewController scrollToTopAnimated:NO];
        handled = YES;
    }
    
    completionHandler(handled);
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [_wallet refresh:^(BOOL updated) {
        if (updated) {
            [self notifyExtensions];
            completionHandler(UIBackgroundFetchResultNewData);
        } else {
            completionHandler(UIBackgroundFetchResultNoData);
        }
    }];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    
    NSLog(@"Continue: %@", userActivity.activityType);
    
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        if (![userActivity.webpageURL.scheme isEqualToString:@"https"]) { return NO; }
        if (![userActivity.webpageURL.host isEqualToString:@"ethers.io"]) { return NO; }
        if (![userActivity.webpageURL.path hasPrefix:@"/app-link"]) { return NO; }
        
        if ([userActivity.webpageURL.fragment hasPrefix:@"!debug"]) {
            [ModalViewController dismissAllCompletionCallback:^() {
                [_wallet showDebuggingOptionsCallback:nil];
            }];
            

        } else if ([userActivity.webpageURL.fragment hasPrefix:@"!scan"]) {
            [_walletViewController scrollToTopAnimated:NO];
            [self showScanner];

        } else if ([userActivity.webpageURL.fragment hasPrefix:@"!wallet"]) {
            [ModalViewController dismissAll];
            [_panelViewController setViewControllerIndex:0 animated:NO];
            [_panelViewController focusPanel:YES animated:NO];
            [_walletViewController scrollToTopAnimated:NO];

        } else {
            return NO;
        }
        
        return YES;
    }
    
    return YES;
}

#pragma mark - Extensions

- (void)notifyExtensions {
    SharedDefaults *sharedDefaults = [SharedDefaults sharedDefaults];
    
    BOOL changed = NO, hasContent = NO;
    if (_wallet.numberOfAccounts == 0) {
        hasContent = YES;

        if (sharedDefaults.address) {
            sharedDefaults.address = nil;
            changed = YES;
        }
    
    } else {
        hasContent = YES;
        
        Address *addres = [_wallet addressAtIndex:0];
        if (![sharedDefaults.address isEqualToAddress:addres]) {
            sharedDefaults.address = addres;
            changed = YES;
        }
        BigNumber *balance = [_wallet balanceForAddress:addres];
        if (![sharedDefaults.balance isEqual:balance]) {
            sharedDefaults.balance = balance;
            changed = YES;
        }
    }
    
//    if (changed) {
        [[NCWidgetController widgetController] setHasContent:hasContent
                               forWidgetWithBundleIdentifier:@"io.ethers.app.TodayExtension"];
//    }
}


@end
