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
    
    //NSArray<NSArray*> *_sections;
    
    // The history items; IndexPath => TransactionInfo
    NSDictionary <NSIndexPath*, TransactionInfo*> *_history;
    NSArray<NSNumber*> *_historyCounts;
    NSUInteger _historyBlockNumber;
    
    // The transactions used to compute the current history list
//    NSArray<TransactionInfo*> *_historyTransactions;
    
    // The block number for which the *position* is correct
//    NSMutableDictionary<Hash*, NSNumber*> *_historyBlockNumbers;
    
    UIView *_toolbarBackground;
    
    CrossfadeLabel *_networkLabel;
    
    BOOL _needsUpdateHeaders;
}

//@property (nonatomic, assign) NSUInteger updateNonce;
//@property (nonatomic, assign) BOOL updating;

//@property (nonatomic, strong)

@property (nonatomic, strong) SectionHeaderView *headerConfirmed;
@property (nonatomic, strong) SectionHeaderView *headerInProgress;
@property (nonatomic, strong) SectionHeaderView *headerPending;

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
        
        //_historyBlockNumbers = [NSMutableDictionary dictionaryWithCapacity:32];
        
        self.navigationItem.titleView = _balanceLabel;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateBalance)
                                                     name:WalletAccountBalanceDidChangeNotification
                                                   object:_wallet];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeUpdateTransactions:)
                                                     name:WalletAccountHistoryUpdatedNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeUpdateTransactions:)
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

- (void)noticeUpdateTransactions: (NSNotification*)note {
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

- (void)updateTopMargin:(CGFloat)topMargin bottomMargin:(CGFloat)bottomMargin {
    [super updateTopMargin:topMargin bottomMargin:bottomMargin];
    
    CGFloat dTop = _tableView.contentInset.top - topMargin - 44.0f;
    _tableView.contentInset = UIEdgeInsetsMake(topMargin + 44.0f, 0.0f, 44.0f + bottomMargin, 0.0f);
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(topMargin + 44.0f, 0.0f, 44.0f + bottomMargin, 0.0f);
    _tableView.contentOffset = CGPointMake(0.0f, _tableView.contentOffset.y + dTop);
    
    _toolbarBackground.frame = CGRectMake(0.0f, self.view.frame.size.height - bottomMargin - 44.0f, self.view.frame.size.width, 44.0f + bottomMargin);
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
    _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _tableView.dataSource = self;
    _tableView.delegate = self;
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
    
    _toolbarBackground = [[UIView alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 44.0f, frame.size.width, 44.0f)];
    _toolbarBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _toolbarBackground.backgroundColor = [UIColor colorWithHex:0xf8f8f8];
    [self.view addSubview:_toolbarBackground];

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, 44.0f)];
    [_toolbarBackground addSubview:toolbar];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [toolbar setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];

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

    _sendButton = [Utilities ethersButton:ICON_NAME_AIRPLANE fontSize:36.0f color:ColorHexToolbarIcon];
    [_sendButton addTarget:self action:@selector(tapCamera) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *send = [[UIBarButtonItem alloc] initWithCustomView:_sendButton];
    
    [toolbar setItems:@[
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

/**
 *   Idea
 *    - check for additions; if any, insert all of them at the begginning of their section, defer another animation for 1s from now
 *    - check for deletions; if any, remove all of them and defer another animation for 1s from now
 *    - if no additions, check expected order vs actual order, re-arrange one at a tiem and defer for 1s
 */

+ (NSMutableDictionary<Hash*, NSIndexPath*>*)computeHistory: (NSArray<TransactionInfo*>*)transactions
                                                blockNumber: (NSUInteger)blockNumber {
    NSMutableArray<TransactionInfo*> *pending = [NSMutableArray array];
    NSMutableArray<TransactionInfo*> *inProgress = [NSMutableArray array];
    NSMutableArray<TransactionInfo*> *confirmed = [NSMutableArray array];

    for (TransactionInfo *transaction in transactions) {
        if (transaction.blockNumber < 0) {
            [pending addObject:transaction];
        } else {
            int confirmations = (int)(blockNumber - transaction.blockNumber + 1);
            if (confirmations < CONFIRMED_COUNT) {
                [inProgress addObject:transaction];
            } else {
                [confirmed addObject:transaction];
            }
        }
    }
    
    NSMutableDictionary<Hash*, NSIndexPath*> *history = [NSMutableDictionary dictionaryWithCapacity:transactions.count];

    NSComparisonResult (^sorter)(TransactionInfo*, TransactionInfo*) = ^NSComparisonResult(TransactionInfo *a, TransactionInfo *b) {
        NSInteger delta = b.blockNumber - a.blockNumber;
        if (delta > 0) {
            return NSOrderedDescending;
        } else if (delta < 0) {
            return NSOrderedAscending;
        }
        
        return [[a.transactionHash hexString] compare:[b.transactionHash hexString]];
    };
    
    void (^insert)(NSUInteger, NSMutableArray*) = ^(NSUInteger section, NSMutableArray *transactions) {
        [transactions sortUsingComparator:sorter];
        for (NSUInteger row = 0; row < transactions.count; row++) {
            TransactionInfo *transaction = [transactions objectAtIndex:row];
            [history setObject:[NSIndexPath indexPathForRow:row inSection:section] forKey:transaction.transactionHash];
        }
    };
    
    insert(1, pending);
    insert(2, inProgress);
    insert(3, confirmed);

    return history;
}

- (void)fixHistoryCountsAnimated: (BOOL)animated {
    NSUInteger counts[] = { 0, 0, 0 };
    for (NSIndexPath *indexPath in _history) {
        counts[indexPath.section - 1]++;
    }
    
    _historyCounts = @[ @(counts[0]), @(counts[1]), @(counts[2]) ];
    
    if (counts[1] > 0 && _wallet.activeAccountAddress) {
        
        // Iterate over all pending transactions
        NSUInteger row = 0;
        NSInteger minInProgressConfirmations = 42, maxInProgressConfirmations = -1;
        while (true) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row++ inSection:2];
            TransactionInfo *transaction = [_history objectForKey:indexPath];
            if (!transaction) { break; }
            
            NSInteger confirmations = _wallet.activeAccountBlockNumber - transaction.blockNumber + 1;

            // Find the lowest and highest number of confirmations
            if (confirmations < minInProgressConfirmations) {
                minInProgressConfirmations = confirmations;
            }
            if (confirmations > maxInProgressConfirmations) {
                maxInProgressConfirmations = confirmations;
            }
        }
        
        if (minInProgressConfirmations == maxInProgressConfirmations) {
            [_headerInProgress setDetails:[NSString stringWithFormat:@"%d confirmations", (int)minInProgressConfirmations]
                                 animated:animated];
        } else {
            [_headerInProgress setDetails:[NSString stringWithFormat:@"%d \u2013 %d confirmations",
                                           (int)minInProgressConfirmations, (int)maxInProgressConfirmations]
                                 animated:animated];
        }
    }
}


- (void)updateHeadersAnimated: (BOOL)animated {
    if (animated) {
        [_tableView beginUpdates];
    }

    [_headerPending setShowing:([[_historyCounts objectAtIndex:0] integerValue] > 0) animated:animated];
    [_headerInProgress setShowing:([[_historyCounts objectAtIndex:1] integerValue] > 0) animated:animated];
    [_headerConfirmed setShowing:([[_historyCounts objectAtIndex:2] integerValue] > 0) animated:animated];

    if (animated) {
        [_tableView endUpdates];
    }
    
    _needsUpdateHeaders = NO;
}

+ (Hash*)findFirstDifference: (NSDictionary<Hash*,NSIndexPath*>*)historyFrom
              againstHistory: (NSDictionary<Hash*,NSIndexPath*>*)historyTo {
    
    NSIndexPath *lowestPath = nil;
    Hash *lowestHash = nil;
    
    for (Hash *hash in historyFrom) {
        NSIndexPath *fromIndexPath = [historyFrom objectForKey:hash];
        NSIndexPath *toIndexPath = [historyTo objectForKey:hash];
        if ([fromIndexPath isEqual:toIndexPath]) { continue; }
        if (lowestPath == nil || toIndexPath.section < lowestPath.section || (toIndexPath.section == lowestPath.section && toIndexPath.row < lowestPath.row)) {
            lowestPath = toIndexPath;
            lowestHash = hash;
        }
    }
    
    return lowestHash;
    
}

+ (void)moveHistory: (NSMutableDictionary*)history hash: (Hash*)hash toIndexPath: (NSIndexPath*)toIndexPath {
    NSIndexPath *fromIndexPath = [history objectForKey:hash];
    [history removeObjectForKey:hash];
    
    NSArray *keys = [history allKeys];
    
    // Bump all elements in the same source section above this item down by one
    for (Hash *hash in keys) {
        NSIndexPath *indexPath = [history objectForKey:hash];
        if (indexPath.section != fromIndexPath.section) { continue; }
        if (indexPath.row < fromIndexPath.row) { continue; }
        [history setObject:[NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section] forKey:hash];
    }

    // Bump all elements in the same target section above this item up one
    for (Hash *hash in keys) {
        NSIndexPath *indexPath = [history objectForKey:hash];
        if (indexPath.section != toIndexPath.section) { continue; }
        if (indexPath.row < toIndexPath.row) { continue; }
        [history setObject:[NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section] forKey:hash];
    }

    [history setObject:toIndexPath forKey:hash];
}

+ (void)removeHistory: (NSMutableDictionary*)history hash: (Hash*)hash {
    NSIndexPath *fromIndexPath = [history objectForKey:hash];
    [history removeObjectForKey:hash];

    for (Hash *hash in [history allKeys]) {
        NSIndexPath *indexPath = [history objectForKey:hash];
        if (indexPath.section != fromIndexPath.section) { continue; }
        if (indexPath.row < fromIndexPath.row) { continue; }
        [history setObject:[NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section] forKey:hash];
    }
}

+ (void)insertHistory: (NSMutableDictionary*)history hash: (Hash*)hash atIndexPath: (NSIndexPath*)toIndexPath {
    // Bump all elements in the same target section above this item up one
    for (Hash *hash in [history allKeys]) {
        NSIndexPath *indexPath = [history objectForKey:hash];
        if (indexPath.section != toIndexPath.section) { continue; }
        if (indexPath.row < toIndexPath.row) { continue; }
        [history setObject:[NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section] forKey:hash];
    }
    
    [history setObject:toIndexPath forKey:hash];
}

- (void)dumpHistory: (NSDictionary<Hash*,NSIndexPath*>*)history title: (NSString*)title {
    NSMutableArray *list = [[history allKeys] mutableCopy];
    [list sortUsingComparator:^NSComparisonResult(Hash *a, Hash *b) {
        NSIndexPath *ai = [history objectForKey:a];
        NSIndexPath *bi = [history objectForKey:b];
        if (ai.section < bi.section) { return NSOrderedAscending; }
        if (ai.section > bi.section) { return NSOrderedDescending; }
        if (ai.row < bi.row) { return NSOrderedAscending; }
        if (ai.row > bi.row) { return NSOrderedDescending; }
        return NSOrderedSame;
    }];
    
    NSLog(@"History - %@", title);
    for (Hash *hash in list) {
        NSIndexPath *indexPath = [history objectForKey:hash];
        NSLog(@"  %d - %d : %@", (int)indexPath.section, (int)indexPath.row, hash);
    }
}

// After hours of messing around with this, finally found a great article that explains everything:
// https://stackoverflow.com/questions/28724500/uitableview-delete-insert-move-ordering-in-batch-updates#42316297

- (void)reloadTableAnimated: (BOOL)animated {
    
    // Map Hash => NewTransactionInfo
    NSMutableDictionary<Hash*, TransactionInfo*> *hashToNewTransactions = [NSMutableDictionary dictionary];
    {
        // Get the current transaction history (if any)
        if (_wallet.activeAccountIndex != AccountNotFound) {
            for (TransactionInfo *transaction in [_wallet transactionHistoryForIndex:_wallet.activeAccountIndex]) {
                [hashToNewTransactions setObject:transaction forKey:transaction.transactionHash];
            }
            
            // @TODO: Animate by fading
            _noTransactionsView.hidden = (hashToNewTransactions.count > 0);
        } else {
            // @TODO: Animate by fading
            _noTransactionsView.hidden = NO;
        }
    }

    NSUInteger blockNumber = _wallet.activeAccountBlockNumber;
    
    // Compute the new desired history assuming latest block number
    NSDictionary<Hash*, NSIndexPath*> *newHistory = [WalletViewController computeHistory:[hashToNewTransactions allValues]
                                                                             blockNumber:blockNumber];

    //[self dumpHistory:newHistory title:@"NEW"];
    
    // Not animated, so just update the table
    if (!animated) {
        
        NSMutableDictionary<NSIndexPath*, TransactionInfo*> *history = [NSMutableDictionary dictionaryWithCapacity:newHistory.count];
        for (Hash *hash in newHistory) {
            [history setObject:[hashToNewTransactions objectForKey:hash] forKey:[newHistory objectForKey:hash]];
        }
        
        _history = history;
        _historyBlockNumber = blockNumber;
        [self fixHistoryCountsAnimated:animated];
        
        [self updateHeadersAnimated:animated];
        
        [_tableView reloadData];
        
        return;
    }
    
    // Map Hash => OldIndexPath
    NSMutableDictionary<Hash*, NSIndexPath*> *oldHistory = [NSMutableDictionary dictionaryWithCapacity:_history.count];
    
    // Map Hash => OldTransactionInfo
    NSMutableDictionary<Hash*, TransactionInfo*> *hashToOldTransaction = [NSMutableDictionary dictionaryWithCapacity:_history.count];
    
    for (NSIndexPath *path in _history) {
        TransactionInfo *transaction = [_history objectForKey:path];
        [oldHistory setObject:path forKey:transaction.transactionHash];
        [hashToOldTransaction setObject:transaction forKey:transaction.transactionHash];
    }
    
    //[self dumpHistory:oldHistory title:@"Old"];

    NSMutableArray<NSIndexPath*> *rowsDeleted = [NSMutableArray array];
    NSMutableArray<NSIndexPath*> *rowsInserted = [NSMutableArray array];
    NSMutableArray<NSIndexPath*> *rowsMovedFrom = [NSMutableArray array];
    NSMutableArray<NSIndexPath*> *rowsMovedTo = [NSMutableArray array];
    
    NSDictionary<Hash*, NSIndexPath*> *oldHistoryOriginal = [oldHistory copy];

    // Highest source removals will trigger no change
    NSMutableArray<Hash*> *sortedOldHashes = [[hashToOldTransaction allKeys] mutableCopy];
    [sortedOldHashes sortUsingComparator:^NSComparisonResult(Hash *a, Hash *b) {
        NSIndexPath *ai = [oldHistory objectForKey:a];
        NSIndexPath *bi = [oldHistory objectForKey:b];
        if (ai.section > bi.section) { return NSOrderedAscending; }
        if (ai.section < bi.section) { return NSOrderedDescending; }
        if (ai.row > bi.row) { return NSOrderedAscending; }
        if (ai.row < bi.row) { return NSOrderedDescending; }
        return NSOrderedSame;
    }];
    
    // Delete records that no longer exist
    for (Hash *hash in sortedOldHashes) {
        NSIndexPath *newIndexPath = [newHistory objectForKey:hash];
        if (!newIndexPath) {
            [rowsDeleted addObject:[oldHistory objectForKey:hash]];
            [hashToOldTransaction removeObjectForKey:hash];
            [WalletViewController removeHistory:oldHistory hash:hash];
        }
    }
    
    // Lowest target movements will trigger teh most change
    NSMutableArray<Hash*> *sortedNewHashes = [[hashToNewTransactions allKeys] mutableCopy];
    [sortedNewHashes sortUsingComparator:^NSComparisonResult(Hash *a, Hash *b) {
        NSIndexPath *ai = [newHistory objectForKey:a];
        NSIndexPath *bi = [newHistory objectForKey:b];
        if (ai.section < bi.section) { return NSOrderedAscending; }
        if (ai.section > bi.section) { return NSOrderedDescending; }
        if (ai.row < bi.row) { return NSOrderedAscending; }
        if (ai.row > bi.row) { return NSOrderedDescending; }
        return NSOrderedSame;
    }];
    
    for (Hash *hash in sortedNewHashes) {
        NSIndexPath *oldIndexPath = [oldHistory objectForKey:hash];
        NSIndexPath *newIndexPath = [newHistory objectForKey:hash];
        
        if (!oldIndexPath) {
            [rowsInserted addObject:newIndexPath];
        } else if (![oldIndexPath isEqual:newIndexPath]) {
            [WalletViewController moveHistory:oldHistory hash:hash toIndexPath:newIndexPath];
            [rowsMovedFrom addObject:[oldHistoryOriginal objectForKey:hash]];
            [rowsMovedTo addObject:newIndexPath];
        }
    }
    
    //[self dumpHistory:oldHistory title:@"Updated old"];

    if (rowsInserted.count == 0 && rowsDeleted.count == 0 && rowsMovedFrom.count == 0) {
        [self fixHistoryCountsAnimated:animated];
        return;
    }
    
    NSMutableDictionary<NSIndexPath*,TransactionInfo*> *history = [NSMutableDictionary dictionaryWithCapacity:newHistory.count];
    for (Hash *hash in newHistory) {
        [history setObject:[hashToNewTransactions objectForKey:hash] forKey:[newHistory objectForKey:hash]];
    }
    
    _history = history;
    _historyBlockNumber = blockNumber;
    [self fixHistoryCountsAnimated:animated];

    /*
    NSLog(@"Counts: %@", _historyCounts);
    NSLog(@"Deleted: %@", rowsDeleted);
    NSLog(@"Inserted: %@", rowsInserted);
    NSLog(@"Moved: %@ => %@", rowsMovedFrom, rowsMovedTo);
     */
    
    
    [_tableView performBatchUpdates:^() {
        [self updateHeadersAnimated:NO];
        if (rowsDeleted.count) {
            [_tableView deleteRowsAtIndexPaths:rowsDeleted withRowAnimation:UITableViewRowAnimationFade];
        }
        if (rowsInserted.count) {
            [_tableView insertRowsAtIndexPaths:rowsInserted withRowAnimation:UITableViewRowAnimationRight];
        }
        for (NSUInteger i = 0; i < rowsMovedFrom.count; i++) {
            [_tableView moveRowAtIndexPath:[rowsMovedFrom objectAtIndex:i] toIndexPath:[rowsMovedTo objectAtIndex:i]];
        }
    } completion:^(BOOL finished) {
        NSLog(@"Complete");
    }];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) { return _headerView.frame.size.height; }
    //if (indexPath.row == _selectedRow) { return TransactionTableViewCellHeightSelected; }
    return TransactionTableViewCellHeightNormal;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
    //return _sections.count + 1;
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

- (UISwipeActionsConfiguration*)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section != 1) { return [UISwipeActionsConfiguration configurationWithActions:@[]]; }
    
    void (^handler)(UIContextualAction*, UIView*, void(^)(BOOL)) = ^(UIContextualAction *action, UIView *source, void(^handler)(BOOL)) {
        TransactionInfo *transactionInfo = [_history objectForKey:indexPath];
        void (^sent)(Transaction*, NSError*) = ^(Transaction *transation, NSError *error) {
            NSLog(@"Cancelled: %@ %@ %@", transactionInfo, transation, error);
        };
        [_wallet overrideTransaction:transactionInfo action:WalletTransactionActionCancel callback:sent];
        handler(NO);
    };
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                         title:@"Cancel"
                                                                       handler:handler];
    
    UISwipeActionsConfiguration *swipeConfig = [UISwipeActionsConfiguration configurationWithActions:@[action]];
    swipeConfig.performsFirstActionWithFullSwipe = NO;
    return swipeConfig;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return 0.0;
        case 1: return (_headerPending.showing ? 30.0f: FLT_EPSILON);
        case 2: return (_headerInProgress.showing ? 30.0f: FLT_EPSILON);
        case 3: return (_headerConfirmed.showing ? 30.0f: FLT_EPSILON);
    }
    return 30.0f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { return 1; }
    return [[_historyCounts objectAtIndex:section - 1] integerValue];
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

        TransactionInfo *transactionInfo = [_history objectForKey:indexPath];
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
