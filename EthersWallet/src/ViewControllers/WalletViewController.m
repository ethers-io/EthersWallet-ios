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

#import <ethers/Transaction.h>

#import "AccountsViewController.h"
#import "BalanceLabel.h"
#import "CrossfadeLabel.h"
#import "IndexPathArray.h"
#import "SectionHeaderView.h"
#import "TransactionTableViewCell.h"
#import "UIColor+hex.h"
#import "Utilities.h"
#import "Wallet.h"
#import "WalletView.h"

#define CONFIRMED_COUNT        12

@interface WalletViewController () <UITableViewDataSource, UITableViewDelegate> {
    BigNumber *_amount;
    
    WalletView *_walletView;
    
    UIView *_noAccountView;
    
    UIButton *_shareButton, *_sendButton;
    
    UITableView *_tableView;

    UIView *_noTransactionsView;
    
    BalanceLabel *_balanceLabel;
    UIView *_headerView;
    
    NSInteger _selectedRow;
    
    CrossfadeLabel *_nicknameLabel, *_updatedLabel;
    
    NSArray<NSArray*> *_sections;

    SectionHeaderView *_headerConfirmed, *_headerInProgress, *_headerPending;
    
    CrossfadeLabel *_networkLabel;
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
    self = [super init];
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
        
//        {
//            UIButton *sendButton = [Utilities ethersButton:ICON_NAME_AIRPLANE fontSize:30.0f color:0xffffff];
//            [sendButton addTarget:sendButton action:@selector(tapCamera) forControlEvents:UIControlEventTouchUpInside];
//            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:sendButton];
//        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateBalance)
                                                     name:WalletAccountBalanceDidChangeNotification
                                                   object:_wallet];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeUpdateTransactions)
                                                     name:WalletAccountHistoryUpdatedNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeUpdateTransactions)
                                                     name:WalletTransactionDidChangeNotification
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
                                                 selector:@selector(notifyWalletDidSync:)
                                                     name:WalletDidSyncNotification
                                                   object:_wallet];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)noticeUpdateActiveAccount {
    [self updatedActiveAccountAnimated:YES];
}


#pragma mark - State Updating

- (void)updatedActiveAccountAnimated: (BOOL)animated {
    _walletView.address = _wallet.activeAccountAddress;

    float targetNoAccountAlpha = 0.0f;
    
    if (_wallet.activeAccountIndex != AccountNotFound) {
        _nicknameLabel.text = [_wallet nicknameForIndex:_wallet.activeAccountIndex];

        _shareButton.enabled = YES;
        
        _sendButton.enabled = YES;
        
        _updatedLabel.hidden = NO;
        _nicknameLabel.hidden = NO;
        
        NSString *networkName = @"";
        if (_wallet.activeAccountProvider.chainId != ChainIdHomestead) {
            networkName = [chainName(_wallet.activeAccountProvider.chainId) uppercaseString];
        }
        [_networkLabel setText:networkName animated:animated];
    
    } else {
        targetNoAccountAlpha = 1.0f;

        _shareButton.enabled = NO;
        _sendButton.enabled = NO;

        _updatedLabel.hidden = YES;
        _nicknameLabel.hidden = YES;
        
        [_networkLabel setText:@"" animated:animated];
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
    [NSTimer scheduledTimerWithTimeInterval:0.5f repeats:NO block:^(NSTimer *timer) {
        [self reloadTableAnimated:YES];
    }];
}

- (void)updateSyncDateAniamted: (BOOL)animated {
    [_updatedLabel setText:[@"Updated " stringByAppendingString:[Utilities timeAgo:_wallet.syncDate]] animated:animated];
}

- (void)notifyWalletDidSync: (NSNotification*)note {
    [self updateSyncDateAniamted:YES];
}


#pragma mark - View Life-Cycle

- (void)scrollToTopAnimated:(BOOL)animated {
    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                      atScrollPosition:UITableViewScrollPositionTop
                              animated:animated];
}

- (void)didUpdateNavigationBar:(CGFloat)marginTop {
    [super didUpdateNavigationBar:marginTop];
    CGPoint contentOffset = _tableView.contentOffset;
    _tableView.contentInset = UIEdgeInsetsMake(marginTop, 0.0f, 44.0f, 0.0f);
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(marginTop, 0.0f, 44.0f, 0.0f);
    _tableView.contentOffset = contentOffset;
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
    
    _networkLabel = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 85.0f, 7.0f, 70.0f, 30.0f)];
    _networkLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _networkLabel.font = [UIFont fontWithName:FONT_BOLD size:12];
    _networkLabel.text = @"ROPSTEN";
    _networkLabel.textAlignment = NSTextAlignmentRight;
    _networkLabel.textColor = [UIColor colorWithHex:ColorHexRed];
    [_headerView addSubview:_networkLabel];

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
    
    // This is kinda hacky, but the way the automatic scroll insets is computed is not
    // currently compatible with our PanelViewController
    //CGFloat navHeight = self.navigationController.navigationBar.bounds.size.height + [[UIApplication sharedApplication] statusBarFrame].size.height;

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    //_tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
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
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 44.0f, frame.size.width, 44.0f)];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    toolbar.translucent = YES;
    [self.view addSubview:toolbar];
    
    UIView *status = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 44.0f)];
    
    _updatedLabel = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(0.0f, 4.0f, 200.0f, 18.0f)];
    _updatedLabel.font = [UIFont fontWithName:FONT_NORMAL size:12.0f];
    _updatedLabel.text = @"Syncing...";
    _updatedLabel.textAlignment = NSTextAlignmentCenter;
    [status addSubview:_updatedLabel];

    _nicknameLabel = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(0.0f, 22.0f, 200.0f, 18.0f)];
    _nicknameLabel.font = [UIFont fontWithName:FONT_NORMAL size:12.0f];
    _nicknameLabel.textAlignment = NSTextAlignmentCenter;
    _nicknameLabel.textColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
    [status addSubview:_nicknameLabel];

//    _shareButton = [Utilities ethersButton:ICON_NAME_ fontSize:27.0f color:ColorHexToolbarIcon];
//    [_shareButton addTarget:self action:@selector(tapManage) forControlEvents:UIControlEventTouchUpInside];
//    UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
//                                                                           target:nil
//                                                                           action:nil];
    
    _sendButton = [Utilities ethersButton:ICON_NAME_AIRPLANE fontSize:36.0f color:ColorHexToolbarIcon];
    [_sendButton addTarget:self action:@selector(tapCamera) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *send = [[UIBarButtonItem alloc] initWithCustomView:_sendButton];
    
    [toolbar setItems:@[
//                        share,
                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                      target:nil
                                                                      action:nil],
                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                      target:nil
                                                                      action:nil],
                        [[UIBarButtonItem alloc] initWithCustomView:status],
                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                      target:nil
                                                                      action:nil],
                        send,
//                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
//                                                                      target:nil
//                                                                      action:nil],
                        ]];
    
    [self updatedActiveAccountAnimated:NO];
    [self updateSyncDateAniamted:NO];
    
    // Updte the sync date label every 10 seconds
    __weak WalletViewController *weakSelf = self;
    [NSTimer scheduledTimerWithTimeInterval:10.0f repeats:YES block:^(NSTimer *timer) {
        if (!weakSelf) {
            [timer invalidate];
            return;
        }
        [weakSelf updateSyncDateAniamted:YES];
    }];
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
    
    NSString *details = nil;
    if (minInProgressConfirmations == maxInProgressConfirmations) {
        NSString *plural = (minInProgressConfirmations == 1) ? @"": @"s";
        details = [NSString stringWithFormat:@"%d confirmation%@", minInProgressConfirmations, plural];
    } else {
        details = [NSString stringWithFormat:@"%d \u2013 %d confirmations", minInProgressConfirmations, maxInProgressConfirmations];
    }
    [_headerInProgress setDetails:details animated:animated];
    
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
    
    return;
}

#pragma mark - WalletViewControllerDelegate

- (void)tapManage {
    [_wallet manageAccountAtIndex:_wallet.activeAccountIndex callback:^() {
        NSLog(@"FOO");
    }];
}

- (void)tapCamera {
    [_wallet scan:^(Transaction *transaction, NSError *error) {
        NSLog(@"WalletViewController: Scanned Transaction - transaction=%@ error=%@", transaction, error);
    }];
}

- (void)tapAddAccount {
    [_wallet addAccountCallback:^(Address *address) {
        NSLog(@"Created Address: %@", address);
    }];
}

@end
