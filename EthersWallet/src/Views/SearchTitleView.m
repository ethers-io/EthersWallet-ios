//
//  SearchTitleView.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-11-25.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "SearchTitleView.h"

#import "Utilities.h"


@interface SearchTitleView () <UITextFieldDelegate>

@end;


@implementation SearchTitleView {
    UIButton *_cancelButton;
    UITextField *_textField;

    UIView *_background, *_logo;
}

- (instancetype) init {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, SEARCH_TITLE_HIDDEN_WIDTH, 44.0f)];
    if (self) {
        _logo = [Utilities navigationBarLogoTitle];
        _logo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _logo.center = CGPointMake(self.frame.size.width / 2.0f, 22.0f);
        [self addSubview:_logo];
        
        _background = [[UIView alloc] initWithFrame:CGRectMake(10.0f, 6.0f, self.frame.size.width - 70.0f - 20.0, 32.0f)];
        _background.alpha = 0.5;
        _background.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _background.backgroundColor = [UIColor whiteColor];
        _background.layer.cornerRadius = 16.0f;
        [self addSubview:_background];
        
        _textField = [[UITextField alloc] initWithFrame:CGRectMake(15.0f, 0.0f, _background.frame.size.width - 30.0f, 32.0f)];
        _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _textField.autocorrectionType = UITextAutocorrectionTypeNo;
        _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _textField.delegate = self;
        _textField.keyboardType = UIKeyboardTypeURL;
        _textField.placeholder = @"Enter an Ethers URL";
        _textField.returnKeyType = UIReturnKeyGo;
        _textField.textAlignment = NSTextAlignmentCenter;
        _textField.tintColor = [UIColor blueColor];
        [_textField addTarget:self action:@selector(didChangeTextField:) forControlEvents:UIControlEventEditingChanged];
        [_background addSubview:_textField];
        
        _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _cancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _cancelButton.frame = CGRectMake(self.frame.size.width - 75.0f, 0.0f, 75.0f, 44.0f);
        [_cancelButton addTarget:self action:@selector(tapCancelButton) forControlEvents:UIControlEventTouchUpInside];
        [_cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
        [self addSubview:_cancelButton];
        
        [self setWidth:SEARCH_TITLE_HIDDEN_WIDTH animated:NO];
    }
    return self;
}

- (void)setWidth:(BOOL)width {
    [self setWidth:width animated:NO];
}

- (void)setWidth:(CGFloat)width animated:(BOOL)animated {
    __weak SearchTitleView *weakSelf = self;
    void (^animate)() = ^() {
        if (width == SEARCH_TITLE_HIDDEN_WIDTH) {
            _background.alpha = 0.0f;
            _textField.enabled = NO;
            _cancelButton.alpha = 0.0f;
            _cancelButton.enabled = NO;
            _logo.alpha = 1.0f;
        } else {
            _background.alpha = 1.0f;
            _textField.enabled = YES;
            _cancelButton.alpha = 1.0f;
            _cancelButton.enabled = YES;
            _logo.alpha = 1.0f;
        }
        weakSelf.bounds = CGRectMake(0.0f, 0.0f, width, 44.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:animate completion:nil];
    } else {
        animate();
    }
}

- (NSString*)searchText {
    return _textField.text;
}

- (void)tapCancelButton {
    if ([self.delegate respondsToSelector:@selector(searchTitleViewDidCancel:)]) {
        [self.delegate searchTitleViewDidCancel:self];
    }
}

- (BOOL)becomeFirstResponder {
    return [_textField becomeFirstResponder];
}

- (BOOL)isFirstResponder {
    return [_textField isFirstResponder];
}

- (BOOL)resignFirstResponder {
    return [_textField resignFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (void)didChangeTextField: (UITextField*)textField {
    NSLog(@"Search: %@", textField.text);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if ([self.delegate respondsToSelector:@selector(searchTitleViewDidConfirm:)]) {
        [self.delegate searchTitleViewDidConfirm:self];
    }
    return YES;
}

@end
