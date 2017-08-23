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

#import "WalletViewController.h"

//#import <ethers/NSString+Secure.h>
#import <ethers/Payment.h>
#import <ethers/Transaction.h>

#import "AccountsViewController.h"
#import "BalanceLabel.h"
#import "IndexPathArray.h"
//#import "NSArray+LongestCommonSubsequences.h"
#import "ScannerViewController.h"
#import "SectionHeaderView.h"
#import "TransactionTableViewCell.h"
#import "UIColor+hex.h"
#import "Utilities.h"
#import "Wallet.h"
#import "WalletView.h"

#define CONFIRMED_COUNT        12

@interface WalletViewController () <AccountsViewControllerDelegate, ScannerDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
    BigNumber *_amount;
    
    WalletView *_walletView;
    
    UIView *_noAccountView;
    UIButton *_accountsButton, *_cameraButton;
    
    UITableView *_tableView;

    UIView *_noTransactionsView;
    
    BalanceLabel *_balanceLabel;
    UIView *_headerView;
    
    NSInteger _selectedRow;
    
    UILabel *_nicknameLabel, *_updatedLabel;
    
    NSArray<NSArray*> *_sections;
//    NSArray *_sectionTitles;
    SectionHeaderView *_headerConfirmed, *_headerInProgress, *_headerPending;
}

@end


@implementation WalletViewController

static NSRegularExpression *RegExOnlyNumbers = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        RegExOnlyNumbers = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]*$" options:0 error:&error];
        if (error) {
            NSLog(@"ERROR: %@", error);
        }
    });
}

- (instancetype)initWithWallet: (Wallet*)wallet {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _wallet = wallet;

        _selectedRow = -1;
        
        _headerPending = [SectionHeaderView sectionHeaderViewWithTitle:@"PENDING" details:@"0 confirmations"];
        _headerInProgress = [SectionHeaderView sectionHeaderViewWithTitle:@"IN PROGRESS" details:@"1+ confirmations"];
        _headerConfirmed = [SectionHeaderView sectionHeaderViewWithTitle:@"COMPLETE"
                                                                 details:[NSString stringWithFormat:@"%d+ confirmations", CONFIRMED_COUNT]];

        _balanceLabel = [BalanceLabel balanceLabelWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 44.0f)
                                                   fontSize:20.0f
                                                      color:BalanceLabelColorLight
                                                  alignment:BalanceLabelAlignmentCenter];
        
        self.navigationItem.titleView = _balanceLabel;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateBalance)
                                                     name:WalletAccountBalanceDidChangeNotification
                                                   object:_wallet];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeUpdateTransactions)
                                                     name:WalletAccountHistoryUpdatedNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeUpdateActiveAccount)
                                                     name:WalletActiveAccountDidChangeNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeUpdateActiveAccount)
                                                     name:WalletAccountNicknameDidChangeNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateSyncDate)
                                                     name:WalletDidSyncNotification
                                                   object:_wallet];
//
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(notifyUpdateNetwork:)
//                                                     name:WalletDidChangeNetwork
//                                                   object:_wallet];

    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//- (void)notifyUpdateNetwork: (NSNotification*)note {
//    [self reloadTableAnimated:NO];
//}

- (void)noticeUpdateActiveAccount {
    [self updatedActiveAccountAnimated:YES];
}


#pragma mark - State Updating

- (void)updatedActiveAccountAnimated: (BOOL)animated {
    _walletView.address = _wallet.activeAccountAddress;

    float targetNoAccountAlpha = 0.0f;
    
    if (_wallet.activeAccountIndex != AccountNotFound) {
        _nicknameLabel.text = [_wallet nicknameForIndex:_wallet.activeAccountIndex];

        _accountsButton.enabled = YES;
        _cameraButton.enabled = YES;
        
        _updatedLabel.hidden = NO;
        _nicknameLabel.hidden = NO;
    
    } else {
        targetNoAccountAlpha = 1.0f;

        _accountsButton.enabled = NO;
        _cameraButton.enabled = NO;

        _updatedLabel.hidden = YES;
        _nicknameLabel.hidden = YES;
    }
    
    {
        void (^animate)() = ^() {
            _noAccountView.alpha = targetNoAccountAlpha;
        };
        
        if (animated) {
            [UIView animateWithDuration:0.5f animations:animate];
        } else {
            animate();
        }
    }
    
    [self updateBalance];
    [self reloadTableAnimated:NO];
}

- (void)updateBalance {
    if (_wallet.activeAccountIndex != AccountNotFound) {
        _balanceLabel.balance = [_wallet balanceForIndex:_wallet.activeAccountIndex];
        _balanceLabel.hidden = NO;
    } else {
        _balanceLabel.hidden = YES;
    }
}

- (void)noticeUpdateTransactions {
    [self reloadTableAnimated:YES];
}

- (void)updateSyncDate {
    _updatedLabel.text = [@"Updated " stringByAppendingString:[Utilities timeAgo:_wallet.syncDate]];
}


#pragma mark - View Life-Cycle

- (void)scrollToTopAnimated:(BOOL)animated {
    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                      atScrollPosition:UITableViewScrollPositionTop
                              animated:animated];
}

- (void)loadView {
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];

    CGRect frame = self.view.frame;
    float top = 64.0f;
    
    _headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, 0.0f)];

    _walletView = [[WalletView alloc] initWithAddress:_wallet.activeAccountAddress width:frame.size.width];
    {
        CGRect frame = _walletView.frame;
        frame.origin.y = top;
        _walletView.frame = frame;
    }
    [_headerView addSubview:_walletView];

    top += _walletView.frame.size.height + 64.0f;

    UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, top, frame.size.width, 1.0f)];
    topSeparator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topSeparator.backgroundColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
    [_headerView addSubview:topSeparator];
    
    top += 1.0f;
    
    UILabel *transactionTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, top, frame.size.width, 44.0f)];
    transactionTitleLabel.font = [UIFont fontWithName:FONT_BOLD size:12.0f];
    transactionTitleLabel.text = @"TRANSACTIONS";
    transactionTitleLabel.textColor = [UIColor colorWithWhite:0.3f alpha:1.0f];
    transactionTitleLabel.textAlignment = NSTextAlignmentCenter;
    [_headerView addSubview:transactionTitleLabel];
    
    top += 44.0f;
    
    UIView *bottomSeparator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, top, frame.size.width, 0.5f)];
    bottomSeparator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    bottomSeparator.backgroundColor = [UIColor colorWithWhite:0.6f alpha:1.0f];
    [_headerView addSubview:bottomSeparator];

    top += 1.0f;
    
    _headerView.frame = CGRectMake(0.0f, 0.0f, frame.size.width, top);
    
    {
        CGFloat remainingHeight = frame.size.height - 64.0f - top - 44.0f;
        UILabel *noTransactionsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, top, frame.size.width, remainingHeight)];
        noTransactionsLabel.backgroundColor = [UIColor clearColor];
        noTransactionsLabel.font = [UIFont fontWithName:FONT_ITALIC size:16.0f];
        noTransactionsLabel.text = @"No transactions found";
        noTransactionsLabel.textAlignment = NSTextAlignmentCenter;
        noTransactionsLabel.textColor = [UIColor lightGrayColor];
        _noTransactionsView = noTransactionsLabel;
        [_headerView addSubview:_noTransactionsView];
    }
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.contentInset = UIEdgeInsetsMake(64.0f, 0.0f, 44.0f, 0.0f);
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(64.0f, 0.0f, 44.0f, 0.0f);
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];

    _noAccountView = [[UIView alloc] initWithFrame:self.view.bounds];
    _noAccountView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _noAccountView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_noAccountView];

    {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 300.0f, 25.0f)];
        label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
        label.center = CGPointMake(frame.size.width / 2.0f, frame.size.height / 3.0f);
        label.font = [UIFont fontWithName:FONT_ITALIC size:17.0f];
        label.text = @"You do not have any accounts.";
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor colorWithHex:ColorHexLight];
        label.userInteractionEnabled = YES;
        [_noAccountView addSubview:label];
        
        UIButton *button = [Utilities ethersButton:ICON_NAME_CIRCLE_PLUS fontSize:40.0f color:ColorHexToolbarIcon];
        button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
        button.bounds = CGRectMake(0.0f, 0.0f, 60.0f, 60.0f);
        button.center = CGPointMake(frame.size.width / 2.0f, 7.0f * frame.size.height / 10.0f);
        [_noAccountView addSubview:button];
        
        [button addTarget:self action:@selector(tapAddAccount) forControlEvents:UIControlEventTouchUpInside];

        label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 300.0f, 25.0f)];
        label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
        label.center = CGPointMake(frame.size.width / 2.0f, button.center.y + 40.0f);
        label.font = [UIFont fontWithName:FONT_NORMAL size:15.0f];
        label.text = @"Add Account";
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor colorWithHex:ColorHexNormal];
        [_noAccountView addSubview:label];
    }
    
    UINavigationBar *navigationBar = [Utilities addNavigationBarToView:self.view];
    [navigationBar setItems:@[self.navigationItem]];
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 44.0f, frame.size.width, 44.0f)];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    toolbar.translucent = YES;
    [self.view addSubview:toolbar];
    
    UIView *status = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 44.0f)];
    
    _updatedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 4.0f, 200.0f, 18.0f)];
    _updatedLabel.font = [UIFont fontWithName:FONT_NORMAL size:12.0f];
    _updatedLabel.text = @"Syncing...";
    _updatedLabel.textAlignment = NSTextAlignmentCenter;
    [status addSubview:_updatedLabel];

    _nicknameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 22.0f, 200.0f, 18.0f)];
    _nicknameLabel.font = [UIFont fontWithName:FONT_NORMAL size:12.0f];
    _nicknameLabel.text = @"ethers.io";
    _nicknameLabel.textAlignment = NSTextAlignmentCenter;
    _nicknameLabel.textColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
    [status addSubview:_nicknameLabel];

    _accountsButton = [Utilities ethersButton:ICON_NAME_ACCOUNTS fontSize:36.0f color:ColorHexToolbarIcon];
    [_accountsButton addTarget:self action:@selector(tapAccounts) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *accounts = [[UIBarButtonItem alloc] initWithCustomView:_accountsButton];

    _cameraButton = [Utilities ethersButton:ICON_NAME_AIRPLANE fontSize:36.0f color:ColorHexToolbarIcon];
    [_cameraButton addTarget:self action:@selector(tapCamera) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *camera = [[UIBarButtonItem alloc] initWithCustomView:_cameraButton];
    
    [toolbar setItems:@[
                        accounts,
                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                      target:nil
                                                                      action:nil],
                        [[UIBarButtonItem alloc] initWithCustomView:status],
                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                      target:nil
                                                                      action:nil],
                        camera,
                        ]];
    
    [self updatedActiveAccountAnimated:NO];
    [self updateSyncDate];
}


#pragma mark - UITableViewDataSoruce and UITableViewDelegate

- (void)reloadTableAnimated: (BOOL)animated {
    
    NSArray <TransactionInfo*> *transactions = nil;
    
    // @TODO: Animate by fading
    if (_wallet.activeAccountIndex != AccountNotFound) {
        transactions = [_wallet transactionHistoryForIndex:_wallet.activeAccountIndex];
        _noTransactionsView.hidden = (transactions.count > 0);
    } else {
        _noTransactionsView.hidden = NO;
    }
    
    NSMutableArray *pending = [NSMutableArray array];
    NSMutableArray *inProgress = [NSMutableArray array];
    NSMutableArray *confirmed = [NSMutableArray array];
    
    int minInProgressConfirmations = CONFIRMED_COUNT;
    int maxInProgressConfirmations = 0;
    
    //NSUInteger transactionCount = [transactions];
    for (TransactionInfo *transaction in transactions) {
    //for (NSUInteger i = 0; i < transactions.count; i++) {
        //TransactionInfo *transactionInfo = [_wallet transactionForAddress:activeAccount index:i];

        if (transaction.blockNumber == -1) {
            [pending addObject:transaction];
            
        } else {
            int confirmations = (int)(_wallet.activeAccountBlockNumber - transaction.blockNumber + 1);
            if (confirmations < CONFIRMED_COUNT) {
                [inProgress addObject:transaction];
                if (confirmations < minInProgressConfirmations) {
                    minInProgressConfirmations = confirmations;
                }
                if (confirmations > maxInProgressConfirmations) {
                    maxInProgressConfirmations = confirmations;
                }
            } else {
                [confirmed addObject:transaction];
            }
        }
    }
    
    // Stop-gap; We dont' currently support animating the deletion of transactions
    // from the list, and after changing networks (i.e. from mainnet to testnet or
    //  vice versa) transactions may have been deleted
    // @TODO: Support animated deletion of transactions
    if (transactions.count == 0) { animated = NO; }
    
    NSArray<NSArray*> *oldSections = _sections;
    _sections = @[ pending, inProgress, confirmed ];

    void (^animate)() = ^() {
        _headerPending.alpha = ([_sections objectAtIndex:0].count ? 1.0: 0.0f);
        _headerInProgress.alpha = ([_sections objectAtIndex:1].count ? 1.0: 0.0f);
        _headerConfirmed.alpha = ([_sections objectAtIndex:2].count ? 1.0: 0.0f);
    };
    
    if (minInProgressConfirmations == maxInProgressConfirmations) {
        _headerInProgress.details = [NSString stringWithFormat:@"%d confirmation%@",
                                     minInProgressConfirmations, (minInProgressConfirmations == 1) ? @"": @"s"];
    } else {
        _headerInProgress.details = [NSString stringWithFormat:@"%d \u2013 %d confirmations",
                                     minInProgressConfirmations, maxInProgressConfirmations];
    }
    
    if (animated) {

        [_tableView beginUpdates];

        IndexPathArray *oldTransactions = [[IndexPathArray alloc] init];
        [oldTransactions insert:[NSNull null] atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        
        // Old transactions
        for (NSInteger section = 0; section < oldSections.count; section++) {
            NSArray<TransactionInfo*> *rows = [oldSections objectAtIndex:section];
            for (NSInteger row = 0; row < rows.count; row++) {
                TransactionInfo *transactionInfo = [rows objectAtIndex:row];
                [oldTransactions insert:transactionInfo atIndexPath:[NSIndexPath indexPathForRow:row inSection:section + 1]];
            }
        }

        NSMutableArray<NSIndexPath*> *insertIndices = [NSMutableArray array];

        // New transactions
        for (NSInteger section = 0; section < _sections.count; section++) {
            NSArray<TransactionInfo*> *rows = [_sections objectAtIndex:section];
            for (NSInteger row = 0; row < rows.count; row++) {
                TransactionInfo *transactionInfo = [rows objectAtIndex:row];
                
                NSIndexPath *oldIndexPath = [oldTransactions indexPathOfObject:transactionInfo];
                NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:row inSection:section + 1];
                if (oldIndexPath) {
//                    if (!newIndexPath) {
//                        [_tableView deleteRowsAtIndexPaths:@[oldIndexPath] withRowAnimation:UITableViewRowAnimationFade];
//                    } else
                    if (![oldIndexPath isEqual:newIndexPath]) {
                        [_tableView moveRowAtIndexPath:oldIndexPath toIndexPath:newIndexPath];
                    }
                } else {
                    [insertIndices addObject:newIndexPath];
                }
            }
        }
        
        if (insertIndices.count > 0) {
            [_tableView insertRowsAtIndexPaths:insertIndices withRowAnimation:UITableViewRowAnimationRight];
        }
        
        [_tableView endUpdates];
        
        [UIView animateWithDuration:0.5f animations:animate];
        
    } else {
        [_tableView reloadData];
        animate();
    }

}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) { return _headerView.frame.size.height; }
    //if (indexPath.row == _selectedRow) { return TransactionTableViewCellHeightSelected; }
    return TransactionTableViewCellHeightNormal;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count + 1;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 1:
            return _headerPending;
        case 2:
            return _headerInProgress;
        case 3:
            return _headerConfirmed;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) { return 0.0f; }
    if ([_sections objectAtIndex:section - 1].count == 0) { return FLT_EPSILON; }
    return 30.0f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { return 1; }
    if (section > _sections.count) { return 0; }
    return [_sections objectAtIndex:section - 1].count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
        NSString *reuseIdentifier = @"wallet";
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell.contentView addSubview:_headerView];
        }
        
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:TransactionTableViewCellResuseIdentifier];
        if (!cell) {
            cell = [[TransactionTableViewCell alloc] init];
        }

        
        TransactionInfo *transactionInfo = [[_sections objectAtIndex:indexPath.section - 1] objectAtIndex:indexPath.row];
        
        [((TransactionTableViewCell*)cell) setAddress:_wallet.activeAccountAddress transactionInfo:transactionInfo];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //if (indexPath.row == 0) { return; }
    
    return;
    /*
     @TODO: When enhanced version of the cells is ready
     
    if (_selectedRow == indexPath.row) {
        _selectedRow = -1;
    } else {
        _selectedRow = indexPath.row;
    }
    
    [tableView beginUpdates];
    [tableView endUpdates];
     */
}

#pragma mark - AccountsViewControllerDelegate

- (void)accountsViewControllerDidCancel:(AccountsViewController *)accountsViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)accountsViewController:(AccountsViewController *)accountsViewController didSelectAccountIndex:(NSInteger)accountIndex {
    _wallet.activeAccountIndex = accountIndex;
}

#pragma mark - WalletViewControllerDelegate

- (void)tapAccounts {
    AccountsViewController *accountsViewController = [[AccountsViewController alloc] initWithWallet:_wallet];
    accountsViewController.delegate = self;
    [self presentViewController:accountsViewController animated:YES completion:nil];
}

- (void)tapCamera {
    ScannerViewController *scannerViewController = [[ScannerViewController alloc] init];
    scannerViewController.delegate = self;
    [self presentViewController:scannerViewController animated:YES completion:nil];
    dispatch_async(dispatch_get_main_queue(), ^() {
        [scannerViewController startScanningAnimated:YES];
    });
}

- (void)tapAddAccount {
    [_wallet addAccountCallback:^(Address *address) {
        NSLog(@"Created Address: %@", address);
    }];
}

#pragma mark - Long Press Address Copy

// http://stackoverflow.com/questions/1146587/how-to-get-uimenucontroller-work-for-a-custom-view
/*
- (void)animateAddressLabel {
    __weak UILabel *addressLabel = _addressLabel;
    UIViewAnimationOptions options = UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionCurveEaseOut;
    [UIView transitionWithView:addressLabel duration:0.9f options:options animations:^() {
        addressLabel.textColor = [UIColor colorWithHex:0x5f95be];
    } completion:nil];
}
*/
- (void)share: (id)sender {
    
}

#pragma mark - UITextFieldDelegate

- (void)configureTextField: (UITextField*)textField {
    textField.delegate = self;
    textField.keyboardType = UIKeyboardTypeDecimalPad;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return NO;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    NSArray *components = [newString componentsSeparatedByString:@"."];
    if ([components count] > 2) { return NO; }
    
    NSString *whole = [components objectAtIndex:0];
//    whole = [whole stringByReplacingOccurrencesOfString:@"," withString:@""];
    
    NSString *decimal = (([components count] == 2) ? [components objectAtIndex:1]: @"0");
    
    // Make sure everything is a number
    if (![RegExOnlyNumbers numberOfMatchesInString:whole options:0 range:NSMakeRange(0, whole.length)]) {
        return NO;
    }
    if (![RegExOnlyNumbers numberOfMatchesInString:decimal options:0 range:NSMakeRange(0, decimal.length)]) {
        return NO;
    }
    
    /*
    NSMutableString *commifyWhole = [NSMutableString stringWithString:whole];
    for (NSInteger i = whole.length - 3; i > 0; i -= 3) {
        [commifyWhole insertString:@"," atIndex:i];
    }
    
    textField.text = [NSString stringWithFormat:@"%@.%@", ];
    
    NSLog(@"FOO: %@ %@", string, newString);
    return NO;
     */
    return YES;
}

#pragma mark - Scanner Delegate
/*
- (void)showScannerAnimated:(BOOL)animated {
    NSLog(@"Show: %@ %d", self.presentedViewController, animated);
    
    void (^presentScannerViewController)() = ^() {
        ScannerViewController *scannerViewController = [[ScannerViewController alloc] init];
        scannerViewController.delegate = self;
        [self presentViewController:scannerViewController animated:animated completion:^() {
            dispatch_async(dispatch_get_main_queue(), ^() {
//                scannerViewController.scanning = YES;
                [scannerViewController setScanning:YES animated:YES];
            });
        }];
    };
    
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:NO completion:presentScannerViewController];
    } else {
        presentScannerViewController();
    }
}
*/

- (void)scannerViewController:(ScannerViewController *)scannerViewController didFinishWithMessages:(NSArray<NSString *> *)messages {
    [self dismissViewControllerAnimated:YES completion:^() {
        if (messages.count > 0) {
            Payment *payment = [Payment paymentWithURI:[messages firstObject]];
            [_wallet sendPayment:payment callback:^(Hash *transactionHash, NSError *error) {
                NSLog(@"TXHASH: %@ %@", transactionHash, error);
            }];
        }
    }];
}

- (BOOL)scannerViewController: (ScannerViewController*)scannerViewController shouldFinishWithMessages: (NSArray<NSString*>*)messages {
    return (messages.count > 0 && ([Payment paymentWithURI:[messages firstObject]]) != nil);
}

- (void)getSendAmount: (void (^)(BigNumber *wei))callback {

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Transaction Amount" message:@"How much ether do you wish to send?" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* actionSend = [UIAlertAction actionWithTitle:@"Continue..." style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           callback([Payment parseEther:[alert.textFields objectAtIndex:0].text]);
                                                       }];
    [alert addAction:actionSend];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        [self configureTextField:textField];
    }];

    UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             callback(nil);
                                                         }];
    [alert addAction:actionCancel];

    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)send: (NSString*)address amount: (BigNumber*)amount firm: (BOOL)firm callback: (void (^)(NSData *hash, NSError *error)) callback {
    
    if (!amount) {
        __weak WalletViewController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^() {
            [weakSelf getSendAmount:^(BigNumber *amount) {
                if (!amount) {
                    callback(nil, [NSError errorWithDomain:@"cancelled" code:0 userInfo:nil]);
                    return;
                }
                [weakSelf send:address amount:amount firm:NO callback:callback];
            }];
        });
        return YES;
    }
    
    NSString *shortAddress = [NSString stringWithFormat:@"%@...%@",
                              [address substringToIndex:9],
                              [address substringFromIndex:address.length - 7]];
    NSString *etherAmount = [Payment formatEther:amount options:EtherFormatOptionCommify];
    
    NSString *messageFormat = @"To: %@\nAmount: \u039E\u2009%@\nFee: %@\n\nTransactions on the Ethereum network cannot be reversed.";
    NSString *messageFeeEstimatedFormat = @"Ξ\u2009%@ (estimated)";
    NSString *message = [NSString stringWithFormat:messageFormat, shortAddress, etherAmount, @"(estimating...)"];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Confirm Transaction"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSString *textSend = [NSString stringWithFormat:@"Send \u039E\u2009%@", etherAmount];
    UIAlertAction* actionSend = [UIAlertAction actionWithTitle:textSend
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                       }];
    actionSend.enabled = NO;
    [alert addAction:actionSend];

    NSTimer *populateFee = [NSTimer scheduledTimerWithTimeInterval:4.0f repeats:NO block:^(NSTimer *timer) {
        NSString *etherFeeAmount = [Payment formatEther:[BigNumber bigNumberWithDecimalString:@"10500000000000000"]
                                               options:(EtherFormatOptionCommify | EtherFormatOptionApproximate)];
        NSString *feeMessage = [NSString stringWithFormat:messageFeeEstimatedFormat, etherFeeAmount];
        NSString *message = [NSString stringWithFormat:messageFormat, shortAddress, etherAmount, feeMessage];
        alert.message = message;
        actionSend.enabled = YES;
    }];

    if (!firm) {
        __weak WalletViewController *weakSelf = self;
        void (^changeAmountFunc)(UIAlertAction*) = ^(UIAlertAction *action) {
            [populateFee invalidate];
            
            dispatch_async(dispatch_get_main_queue(), ^() {
                [weakSelf getSendAmount:^(BigNumber *amount) {
                    [weakSelf send:address amount:amount firm:NO callback:callback];
                }];
            });
            
        };
        UIAlertAction* actionChange = [UIAlertAction actionWithTitle:@"Change Amount" style:UIAlertActionStyleDefault
                                                             handler:changeAmountFunc];
        [alert addAction:actionChange];
    }
    
    
    {
        void (^cancelFunc)(UIAlertAction*) = ^(UIAlertAction *action) {
            callback(nil, [NSError errorWithDomain:@"cancelled" code:0 userInfo:nil]);
        };

        UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                             handler:cancelFunc];
        [alert addAction:actionCancel];
    }
    
    [self presentViewController:alert animated:YES completion:nil];
    
    return YES;
}

- (void)sendTransaction: (Transaction*)transaction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Send ether to 0x0b7FC9...99528?" message:@"Are you sure you want to send XXX? Transactions on Ethereum cannot be reversed." preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* actionSend = [UIAlertAction actionWithTitle:@"Send Ξ 1.34563" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                          }];

    UIAlertAction* actionChange = [UIAlertAction actionWithTitle:@"Change Amount" style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                       }];

    UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {
                                                          }];

    [alert addAction:actionSend];
    [alert addAction:actionChange];
    [alert addAction:actionCancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
