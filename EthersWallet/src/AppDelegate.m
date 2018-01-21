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

#import <ethers/SecureData.h>
#import <ethers/Transaction.h>

#import "AccountsViewController.h"
#import "ApplicationViewController.h"
#import "CloudView.h"
#import "ConfigNavigationController.h"
#import "GasPriceKeyboardView.h"
#import "ModalViewController.h"
#import "OptionsConfigController.h"
#import "PanelViewController.h"
#import "ScannerConfigController.h"
#import "SearchTitleView.h"
#import "SharedDefaults.h"
#import "SignedRemoteDictionary.h"
#import "UIColor+hex.h"
#import "Utilities.h"
#import "Wallet.h"
#import "WalletViewController.h"


// The Canary is a signed payload living on the ethers.io web server, which allows the
// authors to notify users of critical issues with either the app or the Ethereum network
// The scripts/tools directory contains the code that generates a signed payload.
static NSString *CanaryAddress              = @"0x70C14080922f091fD7d0E891eB483C9f8464a527";
static NSString *CanaryUrl                  = @"https://ethers.io/canary.raw";

// Test URL - This URL triggers the canaray for testing purposes
//static NSString *CanaryUrl                  = @"https://ethers.io/canary-test.raw";


// The list of current applications come from a signed dictionary on the ethers.io web
// server. This will change in the future, but is used currently incase a problem
// occurs with the burned-in apps
static NSString *ApplicationsDataAddress    = @"0xbe1bB78F53f4FD218fb46FA0a565A1eC6a65666e";
static NSString *ApplicationsDataUrl        = @"https://ethers.io/applications-v2.raw";


static NSString *CanaryVersion = nil;

static NSDictionary *DefaultApplications = nil;

@interface AppDelegate () <AccountsViewControllerDelegate, PanelViewControllerDataSource, SearchTitleViewDelegate> {
    NSMutableArray<NSString*> *_applicationTitles;
    NSMutableArray<NSString*> *_applicationUrls;
    
    NSMutableArray<NSString*> *_customApplicationsTitles;
    NSMutableArray<NSString*> *_customApplicationsUrls;
}

@property (nonatomic, readonly) PanelViewController *panelViewController;
@property (nonatomic, readonly) WalletViewController *walletViewController;

@property (nonatomic, readonly) Wallet *wallet;

@end


@implementation AppDelegate {
    UIBarButtonItem *_addAccountsBarButton, *_addApplicationBarButton;
    SearchTitleView *_searchTitleView;
}

#pragma mark - Life-Cycle

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        CanaryVersion = [NSString stringWithFormat:@"%@/%@", [info objectForKey:@"CFBundleIdentifier"],
                         [info objectForKey:@"CFBundleShortVersionString"]];
        
        NSLog(@"Canary Version: %@", CanaryVersion);
        
        DefaultApplications = @{
                                @"titles": @[
                                        @"Welcome", @"CryptoKitties", @"Block Explorer",
                                        ],
                                @"urls": @[
                                        @"https://0x017355b3c9ad3345fc64555676f6c538c0f0454d.ethers.space/",
                                        @"https://www.cryptokitties.co/",
                                        @"https://c3fbbba629d27a348a2f3ccd3e8bdcdca9b1019e.ethers.space/",
                                        ],
                                @"testnetTitles": @[
                                        @"Welcome", @"Testnet Faucet", @"Block Explorer", @"Test Token"
                                        ],
                                @"testnetUrls": @[
                                        @"https://0x017355b3c9ad3345fc64555676f6c538c0f0454d.ethers.space/",
                                        @"https://0xa5681b1fbda76e0d4ab646e13460a94fdcd3c1c1.ethers.space/",
                                        @"https://0xc3fbbba629d27a348a2f3ccd3e8bdcdca9b1019e.ethers.space/",
                                        @"https://0x84db171b84950185431e76d6cd2aa5ce1cf853cf.ethers.space"
                                        ],
                                };

    });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Schedule us for background fetching
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    _customApplicationsTitles = [NSMutableArray array];
    _customApplicationsUrls = [NSMutableArray array];

    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    _wallet = [Wallet walletWithKeychainKey:@"io.ethers.sharedWallet"];
    _walletViewController = [[WalletViewController alloc] initWithWallet:_wallet];
    
    _searchTitleView = [[SearchTitleView alloc] init];
    _searchTitleView.delegate = self;
    
    _panelViewController = [[PanelViewController alloc] initWithNibName:nil bundle:nil];
    _panelViewController.dataSource = self;
    _panelViewController.navigationItem.titleView = _searchTitleView;
    _panelViewController.titleColor = [UIColor colorWithWhite:1.0f alpha:1.0f];

    // The Accounts button on the top-right
    {
        UIButton *button = [Utilities ethersButton:ICON_NAME_ACCOUNTS fontSize:33.0f color:0xffffff];
        [button addTarget:self action:@selector(tapAccounts) forControlEvents:UIControlEventTouchUpInside];
        _addAccountsBarButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    }
    
    _panelViewController.navigationItem.leftBarButtonItem = _addAccountsBarButton;
    
    _addApplicationBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                             target:self
                                                                             action:@selector(tapAddApplication)];
    
    // @TODO: We aren't ready for any app yet
    //_panelViewController.navigationItem.rightBarButtonItem = _addApplicationBarButton;

    {
        CloudView *cloudView = [[CloudView alloc] initWithFrame:_panelViewController.view.bounds];
        cloudView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_panelViewController.backgroundView addSubview:cloudView];
    }
    
    UINavigationController *rootController = [[UINavigationController alloc] initWithRootViewController:_panelViewController];
    UIColor *navigationBarColor = [UIColor colorWithHex:ColorHexNavigationBar];
    [Utilities setupNavigationBar:rootController.navigationBar backgroundColor:navigationBarColor];

    [_panelViewController focusPanel:YES animated:NO];

    _window.rootViewController = rootController;
    
    [_window makeKeyAndVisible];
    
    // If the active account changed, we need to update the applications (e.g. testnet faucet for testnet accounts only)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyActiveAccountDidChange:)
                                                 name:WalletActiveAccountDidChangeNotification
                                               object:_wallet];
    
    // If an account was added, we may now have a different primary account
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletAccountAddedNotification
                                               object:_wallet];

    // If an account was removed, we may now have a different primary account
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletAccountRemovedNotification
                                               object:_wallet];

    // If an account was re-ordered, we may now have a different primary account
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletAccountsReorderedNotification
                                               object:_wallet];

    // If the balance of the primary account changed, we need to update the widet
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyExtensions)
                                                 name:WalletAccountBalanceDidChangeNotification
                                               object:_wallet];

    NSURL *url = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
    if (url) {
        [self application:application openURL:url options:@{}];
    }
    
    [self notifyExtensions];
    
    [self setupApplications];
    
    [self checkCanary];
    
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


// iban://0x05ABcF02682E2b3fB6e38840Cd57d2ea77edd41F
// https://ethers.io/app-link/#!debug



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
    [self checkCanary];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    [self notifyExtensions];

}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - SearchTitleViewDelegate

- (void)tapAddApplication {
    [_panelViewController.navigationItem setLeftBarButtonItem:nil animated:YES];
    [_panelViewController.navigationItem setRightBarButtonItem:nil animated:YES];
    [_searchTitleView setWidth:_panelViewController.view.frame.size.width animated:YES];
    [_searchTitleView becomeFirstResponder];
}

- (void)untapAddApplication {
    [_panelViewController.navigationItem setLeftBarButtonItem:_addAccountsBarButton animated:YES];
    [_panelViewController.navigationItem setRightBarButtonItem:_addApplicationBarButton animated:YES];
    [_searchTitleView setWidth:SEARCH_TITLE_HIDDEN_WIDTH animated:YES];
}

- (void)searchTitleViewDidCancel:(SearchTitleView *)searchTitleView {
    [self untapAddApplication];
}

- (BOOL)launchApplication: (NSString*)url {
    NSURL *check = [NSURL URLWithString:url];
    if (check && check.host.length > 0) {
        [_customApplicationsTitles addObject:check.host];
        [_customApplicationsUrls addObject:url];
        
        [self setupApplications];

        [_panelViewController reloadData];
        _panelViewController.viewControllerIndex = 1;
        
        return YES;
    }
    return NO;
}

- (void)searchTitleViewDidConfirm:(SearchTitleView *)searchTitleView {
    BOOL valid = [self launchApplication:searchTitleView.searchText];
    if (valid) {
        [self untapAddApplication];
    }
}

#pragma mark - AccountsViewControllerDelegate

- (void)tapAccounts {
    AccountsViewController *accountsViewController = [[AccountsViewController alloc] initWithWallet:_wallet];
    accountsViewController.delegate = self;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:accountsViewController];
    UIColor *navigationBarColor = [UIColor colorWithHex:ColorHexNavigationBar];
    [Utilities setupNavigationBar:navigationController.navigationBar backgroundColor:navigationBarColor];
    [ModalViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)accountsViewControllerDidCancel:(AccountsViewController *)accountsViewController {
    [accountsViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)accountsViewController:(AccountsViewController *)accountsViewController didSelectAccountIndex:(NSInteger)accountIndex {
    _wallet.activeAccountIndex = accountIndex;
}

#pragma mark - Applications

- (void)notifyActiveAccountDidChange: (NSNotification*)note {
    [self setupApplications];
}



+ (SignedRemoteDictionary*)signedApplicationsDictionary {
    
    return [SignedRemoteDictionary dictionaryWithUrl:ApplicationsDataUrl
                                             address:[Address addressWithString:ApplicationsDataAddress]
                                         defaultData:DefaultApplications];
}

+ (NSDictionary*)checkApplications {
    NSDictionary<NSString*, NSArray<NSString*>*> *data = [AppDelegate signedApplicationsDictionary].currentData;
    for (NSString *key in @[@"titles", @"urls", @"testnetTitles", @"testnetUrls"]) {
        if (![[data objectForKey:key] isKindOfClass:[NSArray class]]) {
            NSLog(@"AppDelegate - invalid application array: %@", key);
            return DefaultApplications;
        }
        
        if ([data objectForKey:key].count == 0) {
            NSLog(@"AppDelegate - zero items: %@", key);
            return DefaultApplications;
        }
        
        for (NSString *value in [data objectForKey:key]) {
            if (![value isKindOfClass:[NSString class]]) {
                NSLog(@"AppDelegate - invalid applcation value: %@", value);
                return DefaultApplications;
            }
        }
    }

    if ([data objectForKey:@"titles"].count != [data objectForKey:@"urls"].count) {
        NSLog(@"AppDelegate - titles/urls mismatch");
        return DefaultApplications;
    }
    
    if ([data objectForKey:@"testnetTitles"].count != [data objectForKey:@"testnetUrls"].count) {
        NSLog(@"AppDelegate - testnet titles/urls mismatch");
        return DefaultApplications;
    }

    return data;
}

- (void)setupApplications {
    NSDictionary *data = [AppDelegate checkApplications];
    if (_wallet.activeAccountProvider.chainId == ChainIdRopsten) {
        _applicationTitles = [[data objectForKey:@"testnetTitles"] mutableCopy];
        _applicationUrls = [[data objectForKey:@"testnetUrls"] mutableCopy];
    } else {
        _applicationTitles = [[data objectForKey:@"titles"] mutableCopy];
        _applicationUrls = [[data objectForKey:@"urls"] mutableCopy];
    }
    
    for (NSInteger i = _customApplicationsTitles.count - 1; i >= 0; i--) {
        [_applicationUrls insertObject:[_customApplicationsUrls objectAtIndex:i] atIndex:0];
        [_applicationTitles insertObject:[_customApplicationsTitles objectAtIndex:i] atIndex:0];
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TEMP_ALLOW_APPS"]) {
        _panelViewController.navigationItem.rightBarButtonItem = _addApplicationBarButton;
    } else {
        _panelViewController.navigationItem.rightBarButtonItem = nil;
    }

    [_panelViewController reloadData];
}


#pragma mark - Canary

- (BOOL)matchesCanaryVersion: (NSString*)version {
    return [CanaryVersion isEqual:version];
}

- (void)checkCanary {
    
    // Might as well check and possibly update the gas prices
    [GasPriceKeyboardView checkForUpdatedGasPrices];
    
    // Also lets check for updted Application list
    [[[AppDelegate signedApplicationsDictionary] data] onCompletion:^(DictionaryPromise *promise) {
        NSLog(@"Finished checking for applications: %@", promise.value);
    }];
    
    // Check for canary data. This is an emergency broadcast system, in case there is
    // either an Ethers Wallet or Ethereum-wide notification we need to send out
    SignedRemoteDictionary *canary = [SignedRemoteDictionary dictionaryWithUrl:CanaryUrl
                                                                       address:[Address addressWithString:CanaryAddress]
                                                                   defaultData:@{}];
    [canary.data onCompletion:^(DictionaryPromise *promise) {
        
        if (![[promise.value objectForKey:@"version"] isEqual:@"0.2"]) { return; }
        
        NSArray *alerts = [promise.value objectForKey:@"alerts"];
        if (![alerts isKindOfClass:[NSArray class]]) { return; }
        
        for (NSDictionary *alert in alerts) {
            if ([alerts isKindOfClass:[NSDictionary class]]) { continue; }
            
            NSArray *affectedVersions = [alert objectForKey:@"affectedVersions"];
            if (![affectedVersions isKindOfClass:[NSArray class]]) { continue; }
            
            BOOL affected = NO;
            for (NSString *affectedVersion in affectedVersions) {
                if ([self matchesCanaryVersion:affectedVersion]) {
                    affected = YES;
                    continue;
                }
            }
            
            // DEBUG!
            //affected = YES;
            
            if (!affected) { continue; }
            
            NSString *heading = [alert objectForKey:@"heading"];
            if (![heading isKindOfClass:[NSString class]]) { continue; }
            
            NSArray *messages = [alert objectForKey:@"text"];
            if (![messages isKindOfClass:[NSArray class]]) { continue; }
            BOOL validText = YES;
            for (NSString *text in messages) {
                if (![text isKindOfClass:[NSString class]]) {
                    validText = NO;
                    break;
                }
            }
            if (!validText) { continue; }
            
            NSString *button = [alert objectForKey:@"button"];
            if (![button isKindOfClass:[NSString class]]) { continue; }
            
            OptionsConfigController *config = [OptionsConfigController configWithHeading:heading
                                                                              subheading:@""
                                                                                messages:messages
                                                                                 options:@[button]];
            
            config.onLoad = ^(ConfigController *configController) {
                configController.navigationItem.leftBarButtonItem = nil;
            };
            
            config.onOption = ^(OptionsConfigController *configController, NSUInteger index) {
                [(ConfigNavigationController*)configController.navigationController dismissWithNil];
            };
            
            [ModalViewController presentViewController:[ConfigNavigationController configNavigationController:config]
                                              animated:YES
                                            completion:nil];
            break;
        }

    }];
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


#pragma mark - Scanner

- (void)showScanner {
    [ModalViewController dismissAllCompletionCallback:^() {
        if (_wallet.activeAccountAddress) {
            [_wallet scan:^(Transaction *transaction, NSError *error) {
                NSLog(@"Scan complete: %@ %@", transaction, error);
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


#pragma mark - External launching

typedef enum ExternalAction {
    ExternalActionNone = 0,
    ExternalActionScan,
    ExternalActionWallet,
    ExternalActionSend,
    ExternalActionConfig,
    ExternalActionFireflyConfig,
} ExternalAction;

- (BOOL)handleAction: (ExternalAction)action payment: (Payment*)payment {
    if (action == ExternalActionNone) { return NO; }
    
    [self.walletViewController scrollToTopAnimated:NO];
    
    if (action == ExternalActionWallet) {
        [self.panelViewController setViewControllerIndex:0 animated:NO];
        [self.panelViewController focusPanel:YES animated:NO];
    }
    
    __weak AppDelegate *weakSelf = self;
    [ModalViewController dismissAllCompletionCallback:^() {
        if (action == ExternalActionScan) {
            [weakSelf showScanner];
        
        } else if (action == ExternalActionSend) {
            [weakSelf.wallet sendPayment:payment callback:^(Transaction *transaction, NSError *error) {
                NSLog(@"AppDelegate: Sent transaction=%@ error=%@", transaction, error);
            }];
        
        } else if (action == ExternalActionConfig) {
            [weakSelf.wallet showDebuggingOptions:WalletOptionsTypeDebug callback:^() {
                NSLog(@"AppDelegate: Done config");
                [self setupApplications];
            }];
        
        } else if (action == ExternalActionFireflyConfig) {
            [weakSelf.wallet showDebuggingOptions:WalletOptionsTypeFirefly callback:^() {
                NSLog(@"AppDelegate: Done Firefly config");
                [self setupApplications];
            }];

        }
    }];
    
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {

    ExternalAction action = ExternalActionNone;
    Payment *payment = nil;
    
    if ([url.host isEqualToString:@"scan"]) {
        action = ExternalActionScan;

    } else if ([url.host isEqualToString:@"wallet"]) {
        action = ExternalActionWallet;

    } else if ([url.host isEqualToString:@"config"]) {
        action = ExternalActionConfig;

    } else if ([url.host isEqualToString:@"firefly"]) {
        action = ExternalActionFireflyConfig;

    } else {
        payment = [Payment paymentWithURI:[url absoluteString]];
        if (payment) {
            action = ExternalActionSend;
        }
    }
    
    return [self handleAction:action payment:payment];
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    
    BOOL handled = NO;
    
    if ([shortcutItem.type isEqualToString:@"io.ethers.scan"]) {
        handled = [self handleAction:ExternalActionScan payment:nil];
    } else if ([shortcutItem.type isEqualToString:@"io.ethers.wallet"]) {
        handled = [self handleAction:ExternalActionWallet payment:nil];
    }
    
    completionHandler(handled);
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    
    BOOL handled = NO;
    
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSLog(@"Handle: %@", userActivity.webpageURL);
        
        // Make sure we are at a URL we expect
        if (![userActivity.webpageURL.scheme isEqualToString:@"https"]) { return NO; }
        if (![userActivity.webpageURL.host isEqualToString:@"ethers.io"]) { return NO; }
        if ([userActivity.webpageURL.path hasPrefix:@"/app-link"]) {
            if ([userActivity.webpageURL.fragment hasPrefix:@"!debug"] || [userActivity.webpageURL.fragment hasPrefix:@"!config"]) {
                handled = [self handleAction:ExternalActionConfig payment:nil];

            } else if ([userActivity.webpageURL.fragment hasPrefix:@"!firefly"]) {
                handled = [self handleAction:ExternalActionFireflyConfig payment:nil];

            } else if ([userActivity.webpageURL.fragment hasPrefix:@"!scan"]) {
                handled = [self handleAction:ExternalActionScan payment:nil];

            } else if ([userActivity.webpageURL.fragment hasPrefix:@"!wallet"]) {
                handled = [self handleAction:ExternalActionWallet payment:nil];
            }
        
        } else if ([userActivity.webpageURL.fragment hasPrefix:@"!/app-link/"]) {
            NSString *url = [NSString stringWithFormat:@"https://%@", [userActivity.webpageURL.fragment substringFromIndex:11]];
            NSUInteger index = [_applicationUrls indexOfObject:url];
            if (index == NSNotFound) {
                [self launchApplication:url];
            } else {
                _panelViewController.viewControllerIndex = index + 1;
            }
        }
    }
    
    return handled;
}


#pragma mark - Background fetching

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


#pragma mark - Extensions

- (void)notifyExtensions {
    SharedDefaults *sharedDefaults = [SharedDefaults sharedDefaults];
    
    BigNumber *totalBalance = [BigNumber constantZero];
    
    BOOL hasContent = NO;
    if (_wallet.numberOfAccounts == 0) {
        hasContent = YES;

        if (sharedDefaults.address) {
            sharedDefaults.address = nil;
        }
    
        NSLog(@"AppDelegate: Disable extension");
              
    } else {
        hasContent = YES;
        
        // Address of first account
        Address *address = [_wallet addressForIndex:0];
        if (![sharedDefaults.address isEqualToAddress:address]) {
            sharedDefaults.address = address;
        }
        
        // Balance for first account
        BigNumber *balance = [_wallet balanceForIndex:0];
        if (![sharedDefaults.balance isEqual:balance]) {
            sharedDefaults.balance = balance;
        }
        
        // Sum total balance of all (mainnet) accounts
        for (NSUInteger i = 0; i < _wallet.numberOfAccounts; i++) {
            if ([_wallet chainIdForIndex:i] != ChainIdHomestead) { continue; }
            totalBalance = [totalBalance add:[_wallet balanceForIndex:i]];
        }
        
        NSLog(@"AppDelegate: Update extension - address=%@ totalBalance=%@ price=%.02f", address.checksumAddress, [Payment formatEther:totalBalance], _wallet.etherPrice);
    }
    
    // Total balance
    sharedDefaults.totalBalance = totalBalance;
    
    // Ether price
    sharedDefaults.etherPrice = _wallet.etherPrice;
    
    
    [[NCWidgetController widgetController] setHasContent:hasContent
                           forWidgetWithBundleIdentifier:@"io.ethers.app.TodayExtension"];
}


@end
