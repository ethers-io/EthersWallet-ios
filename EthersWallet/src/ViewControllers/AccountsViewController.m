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

#import "AccountsViewController.h"

#import "AccountTableViewCell.h"
#import "UIColor+hex.h"
#import "Utilities.h"


@interface AccountsViewController () <AccountTableViewCellDelegate, UITableViewDataSource, UITableViewDelegate> {
    UITableView *_tableView;
    UIBarButtonItem *_addButton, *_doneButton, *_doneReorderButton, *_doneRenameButton, *_reorderButton;
}

@end

@implementation AccountsViewController

- (instancetype)initWithWallet:(Wallet *)wallet {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _wallet = wallet;
        
        _addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(tapAdd)];
        

        _doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                    target:self
                                                                    action:@selector(tapDone)];

        _doneReorderButton = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                    style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(tapDoneReorder)];
        
        _doneRenameButton = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(tapDoneRename)];
        
        _reorderButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                            target:self
                                                                            action:@selector(tapReorder)];
        
        self.navigationItem.hidesBackButton = YES;
        self.navigationItem.leftBarButtonItem = _reorderButton;
        
        self.navigationItem.rightBarButtonItem = _doneButton;
        
        self.navigationItem.titleView = [Utilities navigationBarTitleWithString:@"Accounts"];
        

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notificationAdded:)
                                                     name:WalletAddedAccountNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notificationRemoved:)
                                                     name:WalletRemovedAccountNotification
                                                   object:_wallet];

    }
    return self;
}


// @TODO: Figure out why animating these buttons causes them not to show up.

- (void)tapReorder {
    [self resignNicknameTextFields];
    
    [self.navigationItem setLeftBarButtonItem:_doneReorderButton animated:NO];
    [self.navigationItem setRightBarButtonItem:_addButton animated:NO];
    
    // If the "Manage" tab is visible, hide it
    if (_tableView.editing) {
        [_tableView setEditing:NO animated:NO];
    }
    
    [_tableView setEditing:YES animated:YES];
}

- (void)tapDoneReorder {
    [self.navigationItem setLeftBarButtonItem:_reorderButton animated:NO];
    [self.navigationItem setRightBarButtonItem:_doneButton animated:NO];
    [_tableView setEditing:NO animated:YES];
}

- (void)tapDone {
    [self resignNicknameTextFields];
    
    if ([_delegate respondsToSelector:@selector(accountsViewControllerDidCancel:)]) {
        [_delegate accountsViewControllerDidCancel:self];
    }
}

- (void)tapRename {
    [self.navigationItem setLeftBarButtonItem:_doneRenameButton animated:NO];
    [self.navigationItem setRightBarButtonItem:nil animated:NO];
}

- (void)tapDoneRename {
    [self.navigationItem setLeftBarButtonItem:_reorderButton animated:NO];
    [self.navigationItem setRightBarButtonItem:_doneButton animated:NO];
    [self resignNicknameTextFields];
}

- (void)tapAdd {
    [self.navigationItem setLeftBarButtonItem:_reorderButton animated:NO];
    [self.navigationItem setRightBarButtonItem:_doneButton animated:NO];
    [_tableView setEditing:NO animated:YES];

    [_wallet addAccountCallback:^(Address *address) {
        NSLog(@"Created: %@", address);
    }];
}

- (void)notificationAdded: (NSNotification*)note {
    NSLog(@"Added: %@", note);
    [_tableView reloadData];
}

- (void)notificationRemoved: (NSNotification*)note {
    [_tableView reloadData];
    
    // No accounts left, we no longer have any purpose
    if (!_wallet.activeAccount) { [self tapDone]; }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - View Life-Cycle

- (void)loadView {
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.contentInset = UIEdgeInsetsMake(64.0f, 0.0f, 0.0f, 0.0f);
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = AccountTableViewCellHeight;
    _tableView.scrollIndicatorInsets = _tableView.contentInset;
    [self.view addSubview:_tableView];
   
    // @TODO: Check this... Should it return a uint? If not found, does it return -1 or NSNOTFOUND?
    NSInteger selectedIndex = [_wallet indexForAddress:_wallet.activeAccount];
    NSLog(@"Wallet: %@ %d %@ ", _wallet, (int)_wallet.numberOfAccounts, [_wallet addressAtIndex:selectedIndex]);
    /*
    if (selectedIndex >= 0) {
        
        // Scroll the current account on the screen
        [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:selectedIndex inSection:0]
                                animated:NO
                          scrollPosition:UITableViewScrollPositionTop];
    }
     */

    UINavigationBar *navigationBar = [Utilities addNavigationBarToView:self.view];
    navigationBar.items = @[self.navigationItem];
}


#pragma mark - AccountTableViewCellDelegate

- (void)accountTableViewCell:(AccountTableViewCell *)accountTableViewCell changedNickname:(NSString *)nickname {
    [_wallet setNickname:nickname address:accountTableViewCell.address];
}

- (void)accountTableViewCell:(AccountTableViewCell *)accountTableViewCell changedEditingNickname:(BOOL)isEditing {
    if (isEditing) {
        [self tapRename];
    } else {
        [self tapDoneRename];
    }
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _wallet.numberOfAccounts;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AccountTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AccountTableViewCellResuseIdentifier];
    if (!cell) {
        cell = [AccountTableViewCell accountTableCellWithWallet:_wallet];
        cell.delegate = self;
    }
    
    cell.address = [_wallet addressAtIndex:indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self resignNicknameTextFields];
    if ([_delegate respondsToSelector:@selector(accountsViewController:didSelectAccount:)]) {
        [_delegate accountsViewController:self didSelectAccount:[_wallet addressAtIndex:indexPath.row]];
    }
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    return proposedDestinationIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    [_wallet moveAccountAtIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    // If editing, don't show the little red delete circle
    if (tableView.editing) {
        return UITableViewCellEditingStyleNone;
    }
    
    // Not really delete, but we need to pass this so our "Manage" tab shows up
    return UITableViewCellEditingStyleDelete;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}


- (NSArray<UITableViewRowAction*>*)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    void (^handleAction)(UITableViewRowAction*, NSIndexPath*) = ^(UITableViewRowAction *rowAction, NSIndexPath *indexPath) {
        NSLog(@"Action: %@ %@", rowAction, indexPath);
        [_wallet manageAccount:((AccountTableViewCell*)[tableView cellForRowAtIndexPath:indexPath]).address
                      callback:nil];
        
        [tableView setEditing:NO animated:YES];
    };
    
    UITableViewRowAction *rowAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
                                                                         title:@"Manage"
                                                                       handler:handleAction];
    rowAction.backgroundColor = [UIColor colorWithHex:ColorHexToolbarIcon];
    return @[rowAction];
}


#pragma mark - UIScrollViewDelegate

- (void)resignNicknameTextFields {
    [[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
    for (AccountTableViewCell *cell in _tableView.visibleCells) {
        [cell setEditingNickname:NO];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self resignNicknameTextFields];
}


@end
