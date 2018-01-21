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

#import "FireflyScannerConfigController.h"

#import <ethers/Account.h>
#import <ethers/SecureData.h>

#import "ConfigNavigationController.h"
#import "OutlineLabel.h"
#import "ScannerView.h"
#import "Utilities.h"

@interface FireflyScannerConfigController () <ScannerViewDelegate>

@property (nonatomic, readonly) UIImpactFeedbackGenerator *hapticGood;

@end

@implementation FireflyScannerConfigController {
    ScannerView *_scannerView;
    OutlineLabel *_details;
}

+ (instancetype)configWithSigner:(FireflySigner *)signer transaction:(Transaction *)transaction {
    return [[FireflyScannerConfigController alloc] initWithSigner:signer transaction:transaction];
}

+ (instancetype)configWithSigner:(FireflySigner *)signer message:(NSData *)message {
    return [[FireflyScannerConfigController alloc] initWithSigner:signer message:message];
}

- (instancetype)initWithSigner: (FireflySigner*)signer  transaction:(Transaction *)transaction {
    self = [self initWithSigner:signer];
    if (self) {
        _transaction = [transaction copy];
    }
    return self;
}

- (instancetype)initWithSigner: (FireflySigner*)signer  message:(NSData*)message {
    self = [self initWithSigner:signer];
    if (self) {
        _message = [message copy];
    }
    return self;
}

- (instancetype)initWithSigner: (FireflySigner*)signer {
    self = [super init];
    if (self) {
        _signer = signer;
        
        {
            UILabel *titleLabel = [Utilities navigationBarTitleWithString:ICON_LOGO_FIREFLY];
            titleLabel.font = [UIFont fontWithName:FONT_ETHERS size:32.0f];
            self.navigationItem.titleView = titleLabel;
        }
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                               target:self
                                                                                               action:@selector(cancel)];
        self.navigationItem.hidesBackButton = YES;
        
        _hapticGood = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    }
    return self;
}

- (void)cancel {
    __weak FireflyScannerConfigController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^() {
        if (_didCancel) {
            weakSelf.didCancel(weakSelf);
        }
    });
    
    [(ConfigNavigationController*)self.navigationController dismissWithNil];
}

- (void)loadView {
    [super loadView];
    
    _scannerView = [[ScannerView alloc] initWithFrame:self.view.bounds];
    _scannerView.delegate = self;
    [self.view insertSubview:_scannerView atIndex:0];
    
    [self addFlexibleGap];
    
    _details = [[OutlineLabel alloc] initWithFrame:CGRectMake(44.0f, 100.0f, self.view.frame.size.width - 88.0f, 60.0f)];
    _details.font = [UIFont fontWithName:FONT_NORMAL size:14.0f];
    _details.outlineColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
    _details.outlineWidth = 3.0f;
    if (_transaction) {
        _details.text = @"Confirm the transaction on the Firefly and then scan the two QR codes.";
    } else if (_message){
        _details.text = @"Confirm the message on the Firefly and then scan the two QR codes.";
    }
    _details.numberOfLines = 2;
    _details.textAlignment = NSTextAlignmentCenter;
    _details.textColor = [UIColor whiteColor];
    
    [self addView:_details];
    
    [self addGap:44.0f];
}

- (void)viewDidAppear:(BOOL)animated {
    [_scannerView startAnimated:YES];
}

- (void)hideDetails {
    __weak OutlineLabel *weakDetails = _details;
    void (^animate)() = ^() {
        weakDetails.alpha = 0.0;
    };
    [UIView animateWithDuration:0.5f animations:animate];
}

- (void)scannerView:(ScannerView *)scannerView didDetectMessages:(NSArray<NSString*> *)messages {
    NSLog(@"Scanned: %@", messages);
    __weak FireflyScannerConfigController *weakSelf = self;
    if (messages.count == 2 && [[messages firstObject] hasPrefix:@"SIG:R/"] && [[messages lastObject] hasPrefix:@"SIG:S/"]) {
        NSData *sigR = [SecureData hexStringToData:[@"0x" stringByAppendingString:[[messages firstObject] substringFromIndex:6]]];
        NSData *sigS = [SecureData hexStringToData:[@"0x" stringByAppendingString:[[messages lastObject] substringFromIndex:6]]];

        if (_transaction) {
            BOOL validSignature = [_transaction populateSignatureWithR:sigR s:sigS address:_signer.address];
            if (!validSignature) { return; }

            [scannerView pauseScanningHighlight:messages animated:YES];
            [weakSelf hideDetails];
            
            [weakSelf.hapticGood impactOccurred];

            if (_didSignTransaction) {
                _didSignTransaction(self, _transaction);
            }
            
        } else if (_message) {
            Signature *signature = [Account signatureWithMessage:_message r:sigR s:sigS address:_signer.address];
            if (!signature) { return; }

            [scannerView pauseScanningHighlight:messages animated:YES];
            [weakSelf hideDetails];

            [weakSelf.hapticGood impactOccurred];

            if (_didSignMessage) {
                _didSignMessage(self, signature);
            }
        }
    }
}

@end
