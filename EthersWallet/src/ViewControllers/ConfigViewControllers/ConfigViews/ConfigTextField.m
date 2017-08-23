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

#import "ConfigTextField.h"

#import <ethers/Payment.h>
#import "UIColor+hex.h"
#import "Utilities.h"



@interface OptionsTextField: UITextField

@property (nonatomic, readonly) NSUInteger options;

@property (nonatomic, assign) CGFloat bottomMargin;

@end


@implementation OptionsTextField

- (instancetype)initWithFrame: (CGRect)frame options: (NSUInteger)options {
    self = [super initWithFrame:frame];
    if (self) {
        _options = options;
    }
    return self;
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    if (_options & ConfigTextFieldOptionNoCaret) {
        return CGRectZero;
    }
    
    return [super caretRectForPosition:position];
}

- (BOOL)becomeFirstResponder {
    if ([super becomeFirstResponder]) {
        if (_bottomMargin) {
            UIView *view = self.superview;
            while (view) {
                if ([view isKindOfClass:[UIScrollView class]]) {
                    CGRect rect = [view convertRect:self.bounds fromView:self];
                    rect.size.height += _bottomMargin;
                    dispatch_async(dispatch_get_main_queue(), ^() {
                        [((UIScrollView*)view) scrollRectToVisible:rect animated:YES];
                    });
                    break;
                }
                view = view.superview;
            }
        }
        
        return YES;
    }
    return NO;
}

- (NSArray *)selectionRectsForRange:(UITextRange *)range {
    if (_options & ConfigTextFieldOptionNoCaret) {
        self.selectedTextRange = nil;
        return @[];
    }
    
    return [super selectionRectsForRange:range];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    
    // Is the menu diabled?
    if (_options & ConfigTextFieldOptionNoMenu) {
        [UIMenuController sharedMenuController].menuVisible = NO;
        self.selectedTextRange = nil;
    
        return NO;
    }
    
    // @TODO: Wrap this up into the options
    
    static NSSet *enableActions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        enableActions = [NSSet setWithArray:@[
                                              @"copy:",
                                              @"cut:",
                                              @"select:",
                                              @"selectAll:",
                                              @"paste:",
                                              ]];
    });
    
    if ([enableActions containsObject:NSStringFromSelector(action)]) {
        return [super canPerformAction:action withSender:sender];
    }
    
    return NO;
}
@end



@interface ConfigView () <UITextFieldDelegate>

@end


@implementation ConfigTextField {
    UIActivityIndicatorView *_spinner;
    OptionsTextField *_textField;
    UILabel *_statusLabel;
}

- (instancetype)initWithTitle: (NSString*)title options:(NSUInteger)options {
    self = [super initWithTitle:title];
    if (self) {
        CGRect frame = self.contentView.bounds;
        frame.size.width -= 15.0f;
        _textField = [[OptionsTextField alloc] initWithFrame:frame options:options];
        [self.contentView addSubview:_textField];
        [_textField addTarget:self action:@selector(didChange:) forControlEvents:UIControlEventEditingChanged];
        _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        //_textField.userInteractionEnabled = NO;
        
        _textField.delegate = self;
        
        if (options & ConfigTextFieldOptionNoInteraction) {
            _textField.userInteractionEnabled = NO;
        }
        
        CGSize size = self.contentView.frame.size;
        
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _spinner.bounds = CGRectMake(0.0f, 0.0f, size.height, size.height);
        _spinner.center = CGPointMake(size.width - 10.0f - 15.0f, size.height / 2.0f);
        _spinner.color = [UIColor whiteColor];
        _spinner.transform = CGAffineTransformMakeScale(0.75f, 0.75f);
        [self.contentView addSubview:_spinner];
        
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(size.width - 20.0f - 15.0f, 0.0f, 20.0f, size.height)];
        _statusLabel.alpha = 0.0f;
        _statusLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
        _statusLabel.font = [UIFont fontWithName:FONT_ETHERS size:16.0f];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.textColor = [UIColor colorWithHex:ColorHexLightRed];
        _statusLabel.text = @"X";
        [self.contentView addSubview:_statusLabel];
    }
    return self;
}

- (void)setBottomMargin:(CGFloat)bottomMargin {
    [super setBottomMargin:bottomMargin];
    _textField.bottomMargin = bottomMargin;
}

- (UITextField*)textField {
    return _textField;
}

- (instancetype)initWithTitle: (NSString*)title {
    return [self initWithTitle:title options:ConfigTextFieldOptionNone];
}

- (NSString*)placeholder {
    return _textField.attributedText.string;
}

- (void)setPlaceholder: (NSString *)placeholder {
    
    NSDictionary *placeholderAttributes = @{
                                            NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:17.0f],
                                            NSForegroundColorAttributeName: [UIColor colorWithWhite:0.9f alpha:1.0f]
                                            };
    NSMutableAttributedString *attributedPlaceholder = [[NSMutableAttributedString alloc] initWithString:placeholder
                                                                                              attributes:placeholderAttributes];
    
    _textField.attributedPlaceholder = attributedPlaceholder;
}

- (void)setStatus:(ConfigTextFieldStatus)status {
    [self setStatus:status animated:NO];
}

- (void)setStatus:(ConfigTextFieldStatus)status animated: (BOOL)animated {
    _status = status;
    
    if (status == ConfigTextFieldStatusSpinning) {
        [_spinner startAnimating];
        _statusLabel.alpha = 0.0f;
        
    } else {
        [_spinner stopAnimating];
        
        if (status == ConfigTextFieldStatusNone) {
            _statusLabel.alpha = 0.0f;
            
        } else {
            
            if (status == ConfigTextFieldStatusGood) {
                _statusLabel.text = @"C";
                _statusLabel.textColor = [UIColor colorWithHex:ColorHexLightGreen];
                
            } else if (status == ConfigTextFieldStatusBad) {
                _statusLabel.text = @"X";
                _statusLabel.textColor = [UIColor colorWithHex:ColorHexLightRed];
            }
            
            void (^animate)() = ^() {
                _statusLabel.transform = CGAffineTransformIdentity;
                _statusLabel.alpha = 1.0f;
            };
            
            if (animated) {
                _statusLabel.alpha = 0.0f;
                _statusLabel.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
                
                [UIView animateWithDuration:1.3f
                                      delay:0.0f
                     usingSpringWithDamping:0.4f
                      initialSpringVelocity:0.0f
                                    options:UIViewAnimationOptionBeginFromCurrentState
                                 animations:animate
                                 completion:nil];
                
            } else {
                animate();
            }
            
        }
    }
}

- (void)setEther:(BigNumber *)ether {
    
    // Set the initial value
    NSString *etherString = @"0.0";
    if (ether) { etherString = [Payment formatEther:ether]; }
    
    if ([[[NSLocale currentLocale] decimalSeparator] isEqualToString:@","]) {
        etherString = [etherString stringByReplacingOccurrencesOfString:@"." withString:@","];
    }
    
    if (self.textField.isFirstResponder) {
        self.textField.text = etherString;
    } else {
        self.textField.text = [@"Ξ\u2009" stringByAppendingString:etherString];
    }
}

- (void)setButtonTitle:(NSString *)buttonTitle {
    
    // Remove the button
    if (!buttonTitle) {
        [_button removeFromSuperview];
        _button = nil;
        return;
    }
    
    // Create the button
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.contentView addSubview:_button];
        _button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;

        //_button.titleLabel.textAlignment = NSTextAlignmentRight;
        _button.titleLabel.font = [UIFont fontWithName:FONT_BOLD size:14.0f];
        
        [_button setTitleColor:[UIColor colorWithHex:0x98beef] forState:UIControlStateNormal];
        [_button setTitleColor:[UIColor colorWithHex:0x98beef alpha:0.5f] forState:UIControlStateHighlighted];
        [_button setTitleColor:[UIColor colorWithHex:0x98beef alpha:0.3f] forState:UIControlStateDisabled];

        [_button addTarget:self action:@selector(tapButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    // Set the button title
    [_button setTitle:buttonTitle forState:UIControlStateNormal];
    
    CGFloat width = [buttonTitle sizeWithAttributes:@{ NSFontAttributeName: _button.titleLabel.font }].width + 40.0f;
    _button.frame = CGRectMake(self.contentView.frame.size.width - width, 0.0f, width, 50.0f);
}

- (void)tapButton: (UIButton*)sender {
    if (_onButton) { _onButton(self); }
}

- (NSString*)buttonTitle {
    return [_button titleForState:UIControlStateNormal];
}

- (void)didChange: (UITextField*)textField {
    __weak ConfigTextField *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^() {
        if (weakSelf.didChange) {
            weakSelf.didChange(self);
        }
    });
}

#pragma mark - U?IResponder

/*
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == _textField) {
        hit = self;
    }
    return hit;
}
*/
/*
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    [super becomeFirstResponder];
    NSLog(@"A3");
    BOOL a = [_textField becomeFirstResponder];
    NSLog(@"A4: %d %d %@", a, _textField.userInteractionEnabled, _textField);
    return a;
}

- (BOOL)isFirstResponder {
    return [_textField isFirstResponder];
}

- (BOOL)resignFirstResponder {
    BOOL resign = [_textField resignFirstResponder];
//    if (resign) {
//        _textField.userInteractionEnabled = NO;
//    }
    return resign;
}
*/

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    __weak ConfigTextField *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^() {
        if (weakSelf.didReturn) {
            weakSelf.didReturn(weakSelf);
        }
    });
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (_shouldChange) {
        return _shouldChange(self, range, string);
    }
    return YES;
}


@end
