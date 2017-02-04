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

#import "AccountTableViewCell.h"

#import "BalanceLabel.h"
#import "UIColor+hex.h"
#import "Utilities.h"

NSString *const AccountTableViewCellResuseIdentifier = @"TransactionTableViewCellResuseIdentifier";
const CGFloat AccountTableViewCellHeight = 80.0f;


#pragma mark - ClearProofLabel

// UITableViewCell will automatically crawl the view hierarchy and
// set the backgroud color of UILabels to clear... We don't want this

@interface ClearProofLabel : UILabel
@property (nonatomic, strong) UIColor *safeBackgroundColor;
@end


@implementation ClearProofLabel

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    return;
}

- (void)setSafeBackgroundColor: (UIColor*)backgroundColor {
    [super setBackgroundColor:backgroundColor];
}

@end


#pragma mark - AccountTableViewCell

@interface AccountTableViewCell () <UITextFieldDelegate> {
    BalanceLabel *_balanceLabel;
    UILabel *_addressLabel;

    UIView *_isSelectedView;
    ClearProofLabel *_selectedLabel;
    
    UITextField *_nicknameTextField;
    
    BOOL _accountSelected;
}

@end


@implementation AccountTableViewCell

+ (instancetype)accountTableCellWithWallet: (Wallet*)wallet {
    return [[AccountTableViewCell alloc] initWithWallet:wallet];
}

- (instancetype)initWithWallet: (Wallet*)wallet {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AccountTableViewCellResuseIdentifier];
    if (self) {
        _wallet = wallet;
        
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.shouldIndentWhileEditing = NO;
        
        CGRect frame = self.frame;
        
        _isSelectedView = [[UIView alloc] initWithFrame:CGRectMake(15.0f, (frame.size.height - 28.0f) / 2.0f, 28.0f, 28.0f)];
        _isSelectedView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.contentView addSubview:_isSelectedView];
        
        // The round empty circle to fill with the selected checkmark
        UIView *unselectedView = [[UIView alloc] initWithFrame:_isSelectedView.bounds];
        unselectedView.backgroundColor = [UIColor whiteColor];
        unselectedView.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:1.0f].CGColor;
        unselectedView.layer.borderWidth = 3.0f;
        unselectedView.layer.cornerRadius = _isSelectedView.frame.size.width / 2.0f;
        unselectedView.layer.masksToBounds = YES;
        [_isSelectedView addSubview:unselectedView];
        
        // The checkmark (for indicating this account is selected)
        _selectedLabel = [[ClearProofLabel alloc] initWithFrame:_isSelectedView.bounds];
        _selectedLabel.alpha = 0.0f;
        _selectedLabel.safeBackgroundColor = [UIColor colorWithHex:ColorHexLightGreen];
        _selectedLabel.font = [UIFont fontWithName:FONT_ETHERS size:20.0f];
        _selectedLabel.textAlignment = NSTextAlignmentCenter;
        _selectedLabel.layer.cornerRadius = _selectedLabel.frame.size.width / 2.0f;
        _selectedLabel.layer.masksToBounds = YES;
        _selectedLabel.text = ICON_NAME_SELECTED;
        _selectedLabel.textColor = [UIColor whiteColor];
        [_isSelectedView addSubview:_selectedLabel];
        
        // The balance
        _balanceLabel = [BalanceLabel balanceLabelWithFrame:CGRectMake(frame.size.width - 115.0f, 0.0f, 100.0f, frame.size.height)
                                                   fontSize:15.0f
                                                      color:BalanceLabelColorStatus
                                                  alignment:BalanceLabelAlignmentAlignDecimal];
        _balanceLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
        [self.contentView addSubview:_balanceLabel];
        
        // The nickname
        _nicknameTextField = [[UITextField alloc] initWithFrame:CGRectMake(62.0f, 10.0f, 200.0f, 30.0f)];
        _nicknameTextField.autocapitalizationType = UITextAutocapitalizationTypeWords;
        _nicknameTextField.delegate = self;
        _nicknameTextField.font = [UIFont fontWithName:FONT_BOLD size:24.0f];
        _nicknameTextField.textColor = [UIColor colorWithHex:ColorHexDark];
        _nicknameTextField.userInteractionEnabled = NO;
        [self.contentView addSubview:_nicknameTextField];
        
        [self.contentView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(showNicknameMenu:)]];
        
        _addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(62.0f, 40.0f, 200.0f, 30.0f)];
        _addressLabel.font = [UIFont fontWithName:FONT_MONOSPACE_SMALL size:15.0f];
        _addressLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _addressLabel.textColor = [UIColor colorWithHex:ColorHexNormal];
        [self.contentView addSubview:_addressLabel];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateAddressNotification:)
                                                     name:WalletBalanceChangedNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateAddressNotification:)
                                                     name:WalletChangedNicknameNotification
                                                   object:_wallet];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateActiveAccountNotification:)
                                                     name:WalletChangedActiveAccountNotification
                                                   object:_wallet];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)copyAddress: (id)sender {
    [[UIPasteboard generalPasteboard] setString:_address.checksumAddress];
}

- (void)changeNickname: (id)sender {
    [self setEditingNickname:YES];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)selector withSender:(id) sender {
    if (self.isEditing) { return NO; }
    if (selector == @selector(copyAddress:) || selector == @selector(changeNickname:)) {
        return YES;
    }
    return NO;
}

- (void)showNicknameMenu: (UILongPressGestureRecognizer*)longPressGestureRecognizer {
    if ([longPressGestureRecognizer state] == UIGestureRecognizerStateBegan) {
        UIMenuItem *changeNicknameMenuItem = [[UIMenuItem alloc] initWithTitle:@"Edit Name" action:@selector(changeNickname:)];
        UIMenuItem *copyAddressMenuItem = [[UIMenuItem alloc] initWithTitle:@"Copy Address" action:@selector(copyAddress:)];
        
        CGRect frame = self.contentView.frame;
        frame.origin.y += 20.0f;
        frame.size.height -= 20.0f;
        
        UIMenuController *menu = [UIMenuController sharedMenuController];
        
        [self becomeFirstResponder];
        [menu setTargetRect:frame inView:self.contentView];
        menu.menuItems = @[changeNicknameMenuItem, copyAddressMenuItem];
        [menu setMenuVisible:YES animated:YES];
    }
}

- (void)updateActiveAccountNotification: (NSNotification*)note {
    Address *address = [note.userInfo objectForKey:@"address"];
    [self setAccountSelected:[address isEqualToAddress:_address] animated:YES];
}

- (void)updateAddressNotification: (NSNotification*)note {
    Address *address = [note.userInfo objectForKey:@"address"];
    if (![_address isEqual:address]) { return; }
    [self setAddress:_address];
}

- (void)setAddress:(Address *)address {
    _address = address;
    
    [self setAccountSelected:[_wallet.activeAccount isEqualToAddress:_address] animated:NO];    

    _nicknameTextField.text = [_wallet nicknameForAccount:address];
    _balanceLabel.balance = [_wallet balanceForAddress:address];
    _addressLabel.text  = address.checksumAddress;
}

- (void)setAccountSelected:(BOOL)accountSelected {
    [self setAccountSelected:accountSelected animated:NO];
}

- (void)setAccountSelected:(BOOL)accountSelected animated:(BOOL)animated {

    if (_accountSelected == accountSelected) { return; }
    _accountSelected = accountSelected;

    if (accountSelected) {
        // Prevent in-flight animations from compounding the scale
        [_selectedLabel.layer removeAllAnimations];
        
        void (^animate)() = ^() {
            _selectedLabel.alpha = 1.0f;
            _selectedLabel.transform = CGAffineTransformIdentity;
        };
        if (animated) {
            _selectedLabel.alpha = 0.0f;
            _selectedLabel.transform = CGAffineTransformMakeScale(0.15f, 0.15f);
            [UIView animateWithDuration:0.7f
                                  delay:0.0f
                 usingSpringWithDamping:0.4f
                  initialSpringVelocity:0.0f
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:animate
                             completion:nil];
        } else {
            animate();
        }
    
    } else {
        void (^animate)() = ^() {
            _selectedLabel.alpha = 0.0f;
            _selectedLabel.transform = CGAffineTransformMakeScale(0.15f, 0.15f);
        };
        if (animated) {
            [UIView animateWithDuration:0.5f
                                  delay:0.0f
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:animate
                             completion:nil];
        } else {
            animate();
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.isEditing) {
        CGAffineTransform transformLeft = CGAffineTransformMakeTranslation(-self.contentView.frame.origin.x, 0.0f);
        _addressLabel.transform = transformLeft;
        _balanceLabel.alpha = 0.0f;
        _isSelectedView.alpha = 0.5;
        _nicknameTextField.transform = transformLeft;

//        self.contentView.transform = CGAffineTransformMakeTranslation(-25.0f, 0.0f);

    } else {
        _addressLabel.transform = CGAffineTransformIdentity;
        _balanceLabel.alpha = 1.0f;
        _isSelectedView.alpha = 1.0;
        _nicknameTextField.transform = CGAffineTransformIdentity;
        
//        self.contentView.transform = CGAffineTransformIdentity;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)editingNickname {
    return [_nicknameTextField isFirstResponder];
}

- (NSString*)nickname {
    return _nicknameTextField.text;
}

- (void)setEditingNickname:(BOOL)editingNickname {
    if (editingNickname) {
        if (![_nicknameTextField isFirstResponder]) {
            _nicknameTextField.userInteractionEnabled = YES;
            [_nicknameTextField becomeFirstResponder];
        }
        
    } else {
        if ([_nicknameTextField isFirstResponder]) {
            [_nicknameTextField resignFirstResponder];
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([textField isFirstResponder]) {
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if ([_delegate respondsToSelector:@selector(accountTableViewCell:changedEditingNickname:)]) {
        [_delegate accountTableViewCell:self changedEditingNickname:YES];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    textField.userInteractionEnabled = NO;
    
    if ([_delegate respondsToSelector:@selector(accountTableViewCell:changedEditingNickname:)]) {
        [_delegate accountTableViewCell:self changedEditingNickname:NO];
    }
    
    if ([_delegate respondsToSelector:@selector(accountTableViewCell:changedNickname:)]) {
        [_delegate accountTableViewCell:self changedNickname:textField.text];
    }
}

@end
