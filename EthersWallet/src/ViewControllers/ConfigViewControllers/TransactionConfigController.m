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

#import "TransactionConfigController.h"

#import <ethers/Transaction.h>

#import <ethers/Payment.h>

#import "GasLimitKeyboardView.h"
#import "GasPriceKeyboardView.h"
#import "ConfigNavigationController.h"
#import "UIColor+hex.h"
#import "Utilities.h"




@interface LabelledValue : NSObject

@property (nonatomic, readonly) NSString *label;
@property (nonatomic, readonly) BigNumber *value;

@property (nonatomic, readonly) BOOL maxValue;

@end


@implementation LabelledValue

+ (instancetype)labelledValueWithLabel: (NSString*)label decimalString: (NSString*)decimalString {
    return [[self alloc] initWithLabel:label decimalString:decimalString];
}

- (instancetype)initWithLabel: (NSString*)label decimalString: (NSString*)decimalString {
    self = [super init];
    if (self) {
        _label = label;
        _value = [BigNumber bigNumberWithDecimalString:decimalString];
    }
    return self;
}

@end


@interface ConfigController (private)

@property (nonatomic, readonly) UIScrollView *scrollView;

@end


@interface TransactionConfigController () <UITextFieldDelegate>

@property (nonatomic, readonly) Transaction *transaction;

@property (nonatomic, readonly) ConfigTextField *valueTextField;
@property (nonatomic, readonly) ConfigTextField *passwordTextField;
@property (nonatomic, readonly) UITextView *warningTextView;
@property (nonatomic, readonly) UIButton *sendButton;

@property (nonatomic, assign) BOOL sending;

@property (nonatomic, assign) BOOL feeReady;

// nil if transfer transaction; otherwise estimated cost of contract execution
@property (nonatomic, strong) BigNumber *gasEstimate;

@end


@implementation TransactionConfigController {
    UILabel *_etherPriceLabel;
    
    ConfigLabel *_feeLabel;
    
    ArrayPromise *_addressInspectionPromise;
    
    UIView *_feeKeyboard;
    KeyboardView *_feeKeyboardPrice, *_feeKeyboardLimit;
}

+ (instancetype)configWithSigner: (Signer*)signer transaction: (Transaction*)transaction nameHint: (NSString*)nameHint {
    return [[TransactionConfigController alloc] initWithSigner:signer transaction:transaction nameHint:nameHint];
}

- (instancetype)initWithSigner: (Signer*)signer transaction: (Transaction*)transaction nameHint: (NSString*)nameHint {
    self = [super init];
    if (self) {
        self.navigationItem.titleView = [Utilities navigationBarLogoTitle];
        
        // Make sure we don't have an unlocked Signer (this should never happen)
        [signer lock];
        
        _signer = signer;
        _nameHint = nameHint;
        _transaction = [transaction copy];
        
        _transaction.chainId = _signer.provider.testnet ? ChainIdRopsten: ChainIdHomestead;
        _transaction.nonce = _signer.transactionCount;
        
        NSArray *promises = @[
                              [_signer.provider getCode:_transaction.toAddress],
                              [_signer.provider estimateGas:_transaction],
                              [GasPriceKeyboardView checkForUpdatedGasPrices]
                              ];
        
        NSLog(@"TX: %@", transaction);
        
        _addressInspectionPromise = [Promise all:promises];
    }
    return self;
}

- (void)addDoneButton: (UIView*)view {
    view.backgroundColor = [UIColor colorWithWhite:0.95f alpha:1.0f];

    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 0.5f)];
    topBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBorder.backgroundColor = [UIColor darkGrayColor];
    [view addSubview:topBorder];

    UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0.0f, view.frame.size.height - 0.5f, 320.0f, 0.5f)];
    bottomBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    bottomBorder.backgroundColor = [UIColor darkGrayColor];
    [view addSubview:bottomBorder];

//    UIButton *doneButton = [Utilities ethersButton:@"X" fontSize:17.0f color:0x5291e3];
    UIButton *doneButton = [Utilities ethersButton:@"X" fontSize:17.0f color:0x5555ff];
    doneButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    doneButton.titleLabel.font = [UIFont fontWithName:FONT_MEDIUM size:17.0f];
    doneButton.frame = CGRectMake(view.frame.size.width - 70.0f, 0.0f, 70.0f, 50.0f);
    [doneButton setTitle:@"Done" forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(dismissFirstResponder) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:doneButton];
}


- (void)dismissFirstResponder {
    [self.view endEditing:YES];
}

- (void)segmentDidChange: (UISegmentedControl*)tabs {
    
    void (^animate)() = ^() {
        BOOL left = (tabs.selectedSegmentIndex == 0);
        _feeKeyboardPrice.transform = CGAffineTransformMakeTranslation(left ? 0.0f: -160.0f, 0.0f);
        _feeKeyboardPrice.alpha = (left ? 1.0f: 0.0f);
        _feeKeyboardLimit.transform = CGAffineTransformMakeTranslation(left ? 160.0f: 0.0f, 0.0f);
        _feeKeyboardLimit.alpha = (left ? 0.0f: 1.0f);
    };
    
    [UIView animateWithDuration:0.35f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:animate completion:nil];
}


- (NSString*)getFiatValue: (BigNumber*)wei {
    float costFiat = [[Payment formatEther:wei] floatValue] * _etherPrice;
    
    if (costFiat > 100) {
        return [NSString stringWithFormat:@"$%d (approx.)", (int)costFiat];
    }
    
    return [NSString stringWithFormat:@"$%.02f (approx.)", costFiat];
}

- (BigNumber*)totalValue {
    return [[_transaction.gasLimit mul:_transaction.gasPrice] add:_transaction.value];
}

- (void)setupFeeKeyboardTransfer: (BOOL)transfer gasEstimate: (BigNumber *)gasEstimate {
    _gasEstimate = gasEstimate;
    _feeReady = YES;

    __weak TransactionConfigController *weakSelf = self;

    CGRect keyboardFrame = _feeKeyboard.bounds;
    keyboardFrame.origin.y += 50.0f;
    keyboardFrame.size.height -= 50.0f;

    {
        GasPriceKeyboardView *gasPriceView = [[GasPriceKeyboardView alloc] initWithFrame:keyboardFrame];
        _feeKeyboardPrice = gasPriceView;
        [_feeKeyboard addSubview:gasPriceView];

        _transaction.gasPrice = gasPriceView.gasPrice;

        gasPriceView.didChangeGasPrice = ^(GasPriceKeyboardView *view) {
            [_feeLabel pulse];
            weakSelf.transaction.gasPrice = view.gasPrice;
            [weakSelf updateFee:NO];
            [weakSelf updateButton];
        };
    }
    
    if (transfer) {
//        _gasLimitIndex = 0;
        _transaction.gasLimit = [GasLimitKeyboardView transferGasLimit];

        // Enable MAX spendable
        _valueTextField.buttonTitle = @"MAX";
        _valueTextField.onButton = ^(ConfigView *config) {
            BigNumber *fee = [weakSelf.transaction.gasLimit mul:weakSelf.transaction.gasPrice];
            weakSelf.transaction.value = [weakSelf.signer.balance sub:fee];
            [weakSelf updateValue:NO];
        };
        
        // Set up a static gas limit keyboard view (i.e. "tx costs 21k")
        KeyboardView *gasLimitView = [[KeyboardView alloc] initWithFrame:keyboardFrame];
        _feeKeyboardLimit = gasLimitView;
        {
            gasLimitView.titleLabel.text = @"TRANSFER";
            
            UILabel *gasLimitLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 40.0f)];
            gasLimitLabel.font = [UIFont fontWithName:FONT_ITALIC size:16.0f];
            gasLimitLabel.numberOfLines = 2;
            gasLimitLabel.textColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
            gasLimitLabel.text = @"This transaction requires exactly 21,000 gas and cannot be adjusted.";
            [gasLimitView addView:gasLimitLabel];
        }
    
    } else {
        GasLimitKeyboardView *gasLimitView = [[GasLimitKeyboardView alloc] initWithFrame:keyboardFrame gasEstimate:gasEstimate];
        _feeKeyboardLimit = gasLimitView;
        
        _transaction.gasLimit = gasLimitView.gasLimit;
        
        gasLimitView.didChangeGasLimit = ^(GasLimitKeyboardView *view) {
            [_feeLabel pulse];
            weakSelf.transaction.gasLimit = view.gasLimit;
            [self updateFee:NO];
            [self updateButton];
        };
        
        _feeLabel.title = @"Max Fee";
    }
    
    [_feeKeyboard addSubview:_feeKeyboardLimit];

    _feeKeyboardLimit.transform = CGAffineTransformMakeTranslation(160.0f, 0.0f);
    _feeKeyboardLimit.alpha = 0.0f;

    [self checkFunds];
    [self updateFee:NO];
}

- (void)checkFunds {
    if (!_feeReady) {
        _warningTextView.font = [UIFont fontWithName:FONT_ITALIC size:14.0f];
        _warningTextView.text = @"estimating fee...";
        _warningTextView.textColor = [UIColor whiteColor];
    
    } else if ([[self totalValue] compare:_signer.balance] != NSOrderedDescending) {
        if ([_feeKeyboardLimit isKindOfClass:[GasLimitKeyboardView class]] && !((GasLimitKeyboardView*)_feeKeyboardLimit).safeGasLimit) {
            _warningTextView.font = [UIFont fontWithName:FONT_BOLD size:14.0f];
            _warningTextView.text = @"Gas Limit is too low and may burn fee.";
            _warningTextView.textColor = [UIColor colorWithHex:0xf9674f];
        } else {
            _warningTextView.text = @"";
        }
        
    } else {
        _warningTextView.font = [UIFont fontWithName:FONT_BOLD size:14.0f];
        _warningTextView.text = @"Your balance is too low.";
        _warningTextView.textColor = [UIColor colorWithHex:0xf9674f];
    }
}

- (void)updateButton {
    BigNumber *totalValue = [self totalValue];
    
    if (self.sending) {
        _valueTextField.button.enabled = NO;
        _valueTextField.textField.enabled = NO;
        _feeLabel.userInteractionEnabled = NO;
        _sendButton.enabled = NO;
        
        self.navigationItem.leftBarButtonItem.enabled = NO;
    } else {

        _valueTextField.button.enabled = ![totalValue isEqual:_signer.balance];
        _valueTextField.textField.enabled = YES;
        _feeLabel.alpha = _feeReady ? 1.0f: 0.5f;
        _feeLabel.userInteractionEnabled = _feeReady;
        _sendButton.enabled = ([_signer.balance compare:totalValue] != NSOrderedAscending && _signer.unlocked && _feeReady);

        self.navigationItem.leftBarButtonItem.enabled = YES;
    }
}

- (void)updateFee: (BOOL)fiat {
    BigNumber *cost = [_transaction.gasLimit mul:_transaction.gasPrice];
    
    if (fiat) {
        [_feeLabel.label setText:[self getFiatValue:cost] animated:YES];
    } else {
        [_feeLabel.label setText:[NSString stringWithFormat:@"Ξ\u2009%@", [Payment formatEther:cost]] animated:YES];
    }
    
    [self checkFunds];
    [self updateButton];
}

- (void)updateValue: (BOOL)fiat {
    if (fiat) {
        _valueTextField.textField.text = [self getFiatValue:_transaction.value];
    } else {
        [_valueTextField setEther:_transaction.value];
    }
    
    [self checkFunds];
    [self updateButton];
}

- (void)loadView {
    [super loadView];
    
    __weak TransactionConfigController *weakSelf = self;

    _feeKeyboard = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 258.0f)];
    {
        _feeKeyboard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _feeKeyboard.backgroundColor = [UIColor whiteColor];
        
        
        UIView *toolbar = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
        [self addDoneButton:toolbar];
    
        [_feeKeyboard addSubview:toolbar];
        
        UISegmentedControl *tabs = [[UISegmentedControl alloc] initWithItems:@[@"Gas Price", @"Gas Limit"]];
        tabs.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        tabs.frame = CGRectMake(0.0f, 0.0f, 160.0f, 30.0f);
        tabs.selectedSegmentIndex = 0;
        tabs.tintColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
    
        tabs.center = CGPointMake(160.0f, 25.0f);
        [toolbar addSubview:tabs];

        [tabs addTarget:self action:@selector(segmentDidChange:) forControlEvents:UIControlEventValueChanged];
    }
    
    
    UIView *valueAccessoryView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
    {
        valueAccessoryView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        [self addDoneButton:valueAccessoryView];
        
        _etherPriceLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 4.0f, 100.0f, 44.0f)];
        _etherPriceLabel.adjustsFontSizeToFitWidth = YES;
        _etherPriceLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        _etherPriceLabel.minimumScaleFactor = 0.1f;
        _etherPriceLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
        _etherPriceLabel.font = [UIFont fontWithName:FONT_BOLD size:14.0f];
        
        _etherPriceLabel.text = [NSString stringWithFormat:@"$%.02f\u2009/\u2009ether", _etherPrice];
        
        [valueAccessoryView addSubview:_etherPriceLabel];
    }
    
    // Flare for testnet
    if (_signer.provider.testnet) {
        UILabel *networkLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 85.0f, 7.0f, 70.0f, 30.0f)];
        networkLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        networkLabel.font = [UIFont fontWithName:FONT_BOLD size:12];
        networkLabel.text = @"ROPSTEN";
        networkLabel.textAlignment = NSTextAlignmentRight;
        networkLabel.textColor = [UIColor colorWithHex:ColorHexRed];
        [self.scrollView addSubview:networkLabel];
    }
    

    [self addGap:44.0f];
    
    [self addHeadingText:@"Send Payment"];
    [self addText:_signer.nickname font:[UIFont fontWithName:FONT_ITALIC size:17.0f]];
    
    [self addFlexibleGap];
    
    [self addSeparator];
    
    ConfigLabel *toLabel = [self addLabelTitle:@"To"];
    toLabel.label.text = _transaction.toAddress.checksumAddress;
    toLabel.label.font = [UIFont fontWithName:FONT_MONOSPACE_SMALL size:14.0f];
    toLabel.label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    //toLabel.holdIncludesContentView = YES;

    if (_nameHint) {
        [[_signer.provider lookupName:_nameHint] onCompletion:^(AddressPromise *promise) {
            if (promise.error) { return; }
            [toLabel.label setText:weakSelf.nameHint animated:YES];
            toLabel.onHold = ^(ConfigView *view, ConfigViewHold holding) {
                BOOL on = (holding != ConfigViewHoldNone);
                [((ConfigLabel*)view).label setText:(on ? weakSelf.transaction.toAddress.checksumAddress: weakSelf.nameHint)
                                           animated:YES];
            };
        }];
        
    } else {
        [[_signer.provider lookupAddress:_transaction.toAddress] onCompletion:^(StringPromise *promise) {
            if (promise.error) { return; }
            [toLabel.label setText:promise.value animated:YES];
            toLabel.onHold = ^(ConfigView *view, ConfigViewHold holding) {
                BOOL on = (holding != ConfigViewHoldNone);
                [((ConfigLabel*)view).label setText:(on ? weakSelf.transaction.toAddress.checksumAddress: promise.value)
                                           animated:YES];
            };
        }];
    }
    
    [self addSeparator];
    
    if (_transaction.data.length) {
        ConfigLabel *dataLabel = [self addLabelTitle:@"Data"];
        dataLabel.label.font = [UIFont fontWithName:FONT_MONOSPACE size:14.0f];
        dataLabel.label.text = [NSString stringWithFormat:@"%d bytes", (int)_transaction.data.length];

        [self addSeparator];
    }

    _valueTextField = [self addTextFieldTitle:@"Amount"];
    _valueTextField.bottomMargin = 91.0f;
    _valueTextField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    _valueTextField.textField.delegate = self;
    _valueTextField.textField.inputAccessoryView = valueAccessoryView;
    _valueTextField.textField.keyboardType = UIKeyboardTypeDecimalPad;
    
    _valueTextField.didChange = ^(ConfigTextField *configTextField) {
        BigNumber *value = [weakSelf getTransactionValue:configTextField.textField.text];
        if (value) {
            weakSelf.transaction.value = value;
            [weakSelf checkFunds];
            [weakSelf updateButton];
            
        } else {
            NSLog(@"WARNING! Value changed outside of handled delegate calls; rolling back textField.text");
            [weakSelf updateValue:NO];
        }
    };
    _valueTextField.onHold = ^(ConfigView *configView, ConfigViewHold holding) {
        if (holding == ConfigViewHoldNone || holding == ConfigViewHoldTitle) {
            ConfigTextField *configTextField = (ConfigTextField*)configView;
            if ([configTextField.textField isFirstResponder]) {
                [configTextField.textField resignFirstResponder];
            }
            [weakSelf updateValue:(holding == ConfigViewHoldTitle)];
        }
    };
    
    [self addSeparator];
    
    _feeLabel = [self addLabelTitle:@"Fee"];
    _feeLabel.bottomMargin = 40.0f;
    _feeLabel.inputView = _feeKeyboard;
    _feeLabel.didTap = ^(ConfigView *configView) {
        [configView becomeFirstResponder];
    };
    
    _feeLabel.onHold = ^(ConfigView *configLabel, ConfigViewHold holding) {
        if (holding == ConfigViewHoldNone) {
            [weakSelf updateFee:NO];
        } else if (holding == ConfigViewHoldTitle || [configLabel isFirstResponder]) {
            [weakSelf updateFee:YES];
        }
    };
    
    [self addSeparator];
    
    _warningTextView = [self addText:@"estimating fee..." font:[UIFont fontWithName:FONT_ITALIC size:14.0f]];
    
    [self addFlexibleGap];
    
    [self addGap:17.0f];
    
    [self addSeparator];
    
    _passwordTextField = [self addPasswordTitle:@"Password"];
    _passwordTextField.bottomMargin = 40.0f;
    _passwordTextField.placeholder = @"Required";
    
    _passwordTextField.didChange = ^(ConfigTextField *configTextField) {
        [weakSelf.signer cancelUnlock];
        configTextField.status = ConfigTextFieldStatusSpinning;
        NSString *password = configTextField.textField.text;
        [weakSelf.signer unlock:configTextField.textField.text callback:^(Signer *signer, NSError *error) {
            
            // Expired unlock request
            if (![configTextField.textField.text isEqualToString:password]) {
                return;
            }
            
            NSLog(@"Unlock: %@ %@", signer, error);
            if (error) {
                configTextField.status = ConfigTextFieldStatusBad;
                
            } else {
                configTextField.status = ConfigTextFieldStatusGood;
                
                [weakSelf updateButton];
                
                if ([configTextField.textField isFirstResponder]) {
                    [configTextField.textField resignFirstResponder];
                }
                
                configTextField.userInteractionEnabled = NO;
            }
        }];
    };
    
    _passwordTextField.didReturn = ^(ConfigTextField *configTextField) {
        if ([configTextField.textField isFirstResponder]) {
            [configTextField.textField resignFirstResponder];
        }
    };
    
    [self addSeparator];
    
    [self addFlexibleGap];
    
    _sendButton = [self addButton:@"Send Payment" action:^(UIButton *button) {
        weakSelf.sending = YES;
        weakSelf.warningTextView.text = @"";
        [weakSelf updateButton];
        [weakSelf.signer send:weakSelf.transaction callback:^(Transaction *transaction, NSError *error) {
            if (error) {
                weakSelf.sending = NO;
                weakSelf.warningTextView.text = [error localizedDescription];
                [weakSelf updateButton];
            
            } else {
                if (weakSelf.onSign) {
                    // Notify the owner we are done
                    weakSelf.onSign(weakSelf, transaction);
                }

                // Lock the signer
                [weakSelf.signer lock];

                [(ConfigNavigationController*)(weakSelf.navigationController) dismissWithResult:transaction];
            }
        }];
    }];
    
    [_addressInspectionPromise onCompletion:^(ArrayPromise *promise) {
        if (promise.error) {
            weakSelf.warningTextView.text = [promise.error localizedDescription];
            return;
        }
        
        NSData *code = [promise.value objectAtIndex:0];
        BigNumber *gasEstimate = [promise.value objectAtIndex:1];
        
        [weakSelf setupFeeKeyboardTransfer:(code.length == 0 && weakSelf.transaction.data.length == 0) gasEstimate:gasEstimate];
    }];
    
    //[self addGap:44.0f];
    [self addFlexibleGap];

    [self updateValue:NO];
    [self updateFee:NO];
    
    /*
    if (firm) {
        amountTextField.userInteractionEnabled = NO;
    }
     */
}

#pragma mark - UITextField

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    NSString *text = @"";
    
    if (![_transaction.value isZero]) {
        text = [Payment formatEther:_transaction.value];
        
        if ([[NSLocale currentLocale].decimalSeparator isEqualToString:@","]) {
            text = [text stringByReplacingOccurrencesOfString:@"." withString:@","];
        }
    }
    
    textField.text = text;
}

- (BigNumber*)getTransactionValue: (NSString*)text {
    // Normalize to use a decimal place
    if ([[NSLocale currentLocale].decimalSeparator isEqualToString:@","]) {
        text = [text stringByReplacingOccurrencesOfString:@"," withString:@"."];
    }

    if (text.length == 0 || [text isEqualToString:@"."]) { text = @"0"; }
    
    return [Payment parseEther:text];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    BigNumber *value = [self getTransactionValue:textField.text];
    if (value) { _transaction.value = value; }
    [self updateValue:NO];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    return ([self getTransactionValue:text] != nil);
}

@end

/*
 Account *account = [_accounts objectForKey:activeAccount];
 if (account) {
 LAContext *context = [[LAContext alloc] init];
 NSError *error = nil;
 
 BOOL fingerprintReady = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
 
 if (error) {
 NSLog(@"Error: %@", error);
 fingerprintReady = NO;
 }
 
 if (fingerprintReady) {
 void (^acceptFingerprint)() = ^() {
 info.nextEnabled = NO;
 passwordTextField.userInteractionEnabled = NO;
 
 //passwordTextField.text = @"password";
 //passwordTextField.status = InfoTextFieldStatusGood;
 
 buttonSend.enabled = YES;
 
 };
 
 void (^rejectFingerprint)() = ^() {
 info.nextEnabled = NO;
 [passwordTextField pulse];
 };
 
 [info setNextIcon:ICON_NAME_FINGERPRINT action:^() {
 if (amountTextField.isFirstResponder) { [amountTextField resignFirstResponder]; }
 if (passwordTextField.isFirstResponder) { [passwordTextField resignFirstResponder]; }
 
 void (^handleFingerprintReply)(BOOL, NSError*) = ^(BOOL success, NSError *error) {
 // Fingerprint was good
 if (success) {
 dispatch_async(dispatch_get_main_queue(), ^() {
 acceptFingerprint();
 });
 
 } else {
 NSLog(@"Error1: %@", error);
 
 switch (error.code) {
 // Cases we need to verify by asking the user
 case kLAErrorTouchIDNotEnrolled:
 case kLAErrorPasscodeNotSet:
 case kLAErrorTouchIDNotAvailable:
 case kLAErrorTouchIDLockout:
 case kLAErrorUserFallback: {
 dispatch_async(dispatch_get_main_queue(), ^() {
 rejectFingerprint();
 });
 break;
 }
 
 // Cases where we have failed outright, but acceptably so
 case kLAErrorSystemCancel:
 case kLAErrorUserCancel: {
 
 //                                    dispatch_async(dispatch_get_main_queue(), ^() {
 //                                        callback(nil);
 //                                    });
 break;
 }
 
 // Cases where we have failed, but maybe for not a happy reason
 case kLAErrorAuthenticationFailed:
 default: {
 // @TODO: Show an error
 dispatch_async(dispatch_get_main_queue(), ^() {
 rejectFingerprint();
 });
 break;
 }
 }
 
 }
 };
 NSString *reason = [NSString stringWithFormat:@"Unlock account:\n%@", [self nicknameForAccount:activeAccount]];
 [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
 localizedReason:reason
 reply:handleFingerprintReply];
 }];
 info.nextEnabled = YES;
 }
 }
 */
/*
 info.navigationItem.titleView = [Utilities navigationBarLogoTitle];
 
 toLabel.font = [UIFont fontWithName:FONT_MONOSPACE_SMALL size:14.0f];
 toLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
 
 
 
 if (firm) {
 amountTextField.userInteractionEnabled = NO;
 }
 
 // @TODO: Make it so when you click next on value, it takes you to the next field.
 };
 */
