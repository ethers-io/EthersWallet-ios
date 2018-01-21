//
//  SigningConfigController.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-12-12.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "SigningConfigController.h"

#import <ethers/SecureData.h>

#import "ConfigNavigationController.h"
#import "UIColor+hex.h"
#import "Utilities.h"


@interface ConfigController (private)

@property (nonatomic, readonly) UIScrollView *scrollView;

@end


@interface SigningConfigController ()

@property (nonatomic, readonly) ConfigTextField *passwordTextField;
@property (nonatomic, readonly) UITextView *passwordWarningTextView;
@property (nonatomic, readonly) UIButton *sendButton;
@property (nonatomic, readonly) UIButton *fingerprintButton;

@property (nonatomic, assign) BOOL sending;

@end


@implementation SigningConfigController

- (instancetype)initWithSigner: (Signer*)signer message: (NSData*)message {
    self = [super init];
    if (self) {
        self.navigationItem.titleView = [Utilities navigationBarLogoTitle];
        
        // Make sure we don't have an unlocked Signer (this should never happen)
        [signer lock];
        
        _signer = signer;
        _message = message;
    }
    return self;
}

+ (instancetype)configWithSigner: (Signer*)signer message: (NSData*)message {
    return [[SigningConfigController alloc] initWithSigner:signer message:message];
}

- (void)loadViewPassword {
    __weak SigningConfigController *weakSelf = self;

    _passwordTextField = [self addPasswordTitle:@"Password"];
    _passwordTextField.bottomMargin = 40.0f;
    _passwordTextField.placeholder = @"Required";
    
    _passwordTextField.didChange = ^(ConfigTextField *configTextField) {
        [weakSelf.signer cancelUnlock];
        
        configTextField.status = ConfigTextFieldStatusSpinning;
        
        weakSelf.passwordWarningTextView.text = @"";
        
        NSString *password = configTextField.textField.text;
        [weakSelf.signer unlockPassword:configTextField.textField.text callback:^(Signer *signer, NSError *error) {
            
            // Expired unlock request
            if (![configTextField.textField.text isEqualToString:password]) {
                return;
            }
            
            if (error) {
                configTextField.status = ConfigTextFieldStatusBad;
                
            } else {
                configTextField.status = ConfigTextFieldStatusGood;
                
                [weakSelf updateButton];
                
                if ([configTextField.textField isFirstResponder]) {
                    [configTextField.textField resignFirstResponder];
                }
                
                configTextField.userInteractionEnabled = NO;
                
                weakSelf.fingerprintButton.enabled = NO;
            }
        }];
    };
    
    _passwordTextField.didReturn = ^(ConfigTextField *configTextField) {
        if ([configTextField.textField isFirstResponder]) {
            [configTextField.textField resignFirstResponder];
        }
    };
    
    _passwordWarningTextView = [self addText:@"" font:[UIFont fontWithName:FONT_BOLD size:14.0f]];
    _passwordWarningTextView.font = [UIFont fontWithName:FONT_BOLD size:14.0f];
    _passwordWarningTextView.textColor = [UIColor colorWithHex:0xf9674f];
    
    [self addSeparator];
}

- (void)loadView {
    [super loadView];
    
    __weak SigningConfigController *weakSelf = self;

    // Flare for testnet
    NSString *networkName = chainName(_signer.provider.chainId);
    if (![networkName isEqualToString:chainName(ChainIdHomestead)]) {
        UILabel *networkLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 85.0f, 7.0f, 70.0f, 30.0f)];
        networkLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        networkLabel.font = [UIFont fontWithName:FONT_BOLD size:12];
        networkLabel.text = [networkName uppercaseString];
        networkLabel.textAlignment = NSTextAlignmentRight;
        networkLabel.textColor = [UIColor colorWithHex:ColorHexRed];
        [self.scrollView addSubview:networkLabel];
    }

    _fingerprintButton = [Utilities ethersButton:ICON_NAME_FINGERPRINT fontSize:30.0f color:ColorHexToolbarIcon];
    [_fingerprintButton addTarget:self action:@selector(tapFingerprint:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_fingerprintButton];
    
    // This must be set after assiging to the rightBarButtonItem (which automatically enables it)
    _fingerprintButton.enabled = [_signer supportsBiometricUnlock];

    [self addGap:44.0f];
    
    [self addHeadingText:@"Sign Message"];
    [self addText:_signer.nickname font:[UIFont fontWithName:FONT_ITALIC size:17.0f]];
    
    [self addFlexibleGap];
    
    [self addSeparator];
    
    BOOL ascii = YES;
    const uint8_t *bytes = _message.bytes;
    for (NSInteger i = 0; i < _message.length; i++) {
        uint8_t c = bytes[i];
        if (c >= 32 && c < 127) { continue; }
        if (c == 10) { continue; }
        ascii = NO;
        break;
    }
    
    if (ascii) {
        ConfigLabel *label = [self addLabelTitle:@"Message"];
        label.label.font = [UIFont fontWithName:FONT_MONOSPACE_SMALL size:14.0f];
        label.label.lineBreakMode = NSLineBreakByTruncatingMiddle;
        label.label.text = [[NSString alloc] initWithData:_message encoding:NSUTF8StringEncoding];
    } else {
        ConfigLabel *label = [self addLabelTitle:@"Data"];
        label.label.text = [SecureData dataToHexString:_message];
    }
    
    [self addSeparator];
    
    [self addNoteText:@"By signing this message, you are proving you control this Ethereum account. This is free, and no funds will be spent."];

    if (_signer.supportsPasswordUnlock) {
        [self addFlexibleGap];
        
        [self addGap:17.0f];
        
        [self addSeparator];

        [self loadViewPassword];
    }
    
    [self addFlexibleGap];
    
    _sendButton = [self addButton:[_signer textMessageFor:SignerTextMessageSignButton] action:^(UIButton *button) {
        weakSelf.sending = YES;
        [weakSelf updateButton];
        
        ConfigController *config = [weakSelf.signer signMessage:weakSelf.message callback:^(Signature *signature, NSError *error) {
            if (error) {
                weakSelf.sending = NO;
                [weakSelf updateButton];
                
            } else {
                if (weakSelf.onSign) {
                    // Notify the owner we are done
                    weakSelf.onSign(weakSelf, signature);
                }
                
                // Lock the signer
                [weakSelf.signer lock];
                
                [(ConfigNavigationController*)(weakSelf.navigationController) dismissWithResult:signature];
            }
        }];
        
        if (config) {
            [(ConfigNavigationController*)(weakSelf.navigationController) pushViewController:config animated:YES];
        }
    }];
    
    [self addGap:44.0f];
}

- (void)updateButton {
}

- (void)tapFingerprint: (UIButton*)sender {
    __weak SigningConfigController *weakSelf = self;
    [_signer unlockBiometricCallback:^(Signer *signer, NSError *error) {
        if (signer.unlocked) {
            weakSelf.passwordTextField.status = ConfigTextFieldStatusGood;
            
            [weakSelf updateButton];
            
            if ([weakSelf.passwordTextField.textField isFirstResponder]) {
                [weakSelf.passwordTextField.textField resignFirstResponder];
            }
            
            weakSelf.passwordTextField.textField.text = @"DummyPasswordText";
            weakSelf.passwordTextField.userInteractionEnabled = NO;
            
            weakSelf.fingerprintButton.enabled = NO;
            
            weakSelf.passwordWarningTextView.text = @"";
            
        } else {
            if (![signer supportsBiometricUnlock]) {
                weakSelf.fingerprintButton.enabled = NO;
            }
            
            if (error && [error.domain isEqualToString:SignerErrorDomain]) {
                if (error.code == SignerErrorFailed) {
                    weakSelf.passwordWarningTextView.text = @"Please verify your password.";
                } else {
                    weakSelf.passwordWarningTextView.text = @"";
                }
            }
        }
    }];
}

@end
