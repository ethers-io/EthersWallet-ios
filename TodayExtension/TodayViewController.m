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

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>

#import <ethers/Address.h>

#import "BalanceLabel.h"
#import "SharedDefaults.h"
#import "UIColor+hex.h"
#import "Utilities.h"

@interface TodayViewController () <NCWidgetProviding> {
    UILabel *_addressLabel;
    BalanceLabel *_balanceLabel;
    UIImageView *_qrCodeView;
    UILabel *_noAccountView;
}

@end

@implementation TodayViewController

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    _noAccountView = [[UILabel alloc] initWithFrame:CGRectZero];
    _noAccountView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _noAccountView.font = [UIFont fontWithName:FONT_ITALIC size:15.0f];
    _noAccountView.text = @"You do not have any accounts.";
    _noAccountView.textAlignment = NSTextAlignmentCenter;
    _noAccountView.textColor = [UIColor colorWithHex:0x444444];
    [self.view addSubview:_noAccountView];
    
    _qrCodeView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _qrCodeView.backgroundColor = [UIColor clearColor];
    _qrCodeView.layer.cornerRadius = 5.0f;
    _qrCodeView.layer.masksToBounds = YES;
    [self.view addSubview:_qrCodeView];
    
    _addressLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _addressLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _addressLabel.text = @"";
    _addressLabel.textColor = [UIColor colorWithHex:0x444444];
    _addressLabel.font = [UIFont fontWithName:FONT_BOLD size:12.0f];
    [self.view addSubview:_addressLabel];
    
    _balanceLabel = [BalanceLabel balanceLabelWithFrame:CGRectZero
                                               fontSize:20.0f
                                                  color:BalanceLabelColorVeryDark
                                              alignment:BalanceLabelAlignmentLeft];
    [self.view addSubview:_balanceLabel];
    
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapWidget)]];
}

- (void)tapWidget {
    NSString *url = @"ethers://wallet";
    [self.extensionContext openURL:[NSURL URLWithString:url] completionHandler:^(BOOL success) { }];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    SharedDefaults *sharedDefaults = [SharedDefaults sharedDefaults];
    Address *address = sharedDefaults.address;
    
    if (address) {
        BigNumber *balance = sharedDefaults.balance;
        
        CGSize size = self.view.frame.size;
        
        const float padding = 10.0f;
        float height = size.height;
        float qrSize = height - 2.0f * padding;
        
        NSData *data = [[@"iban:" stringByAppendingString:address.icapAddress] dataUsingEncoding:NSASCIIStringEncoding];
        
        _qrCodeView.image = [Utilities qrCodeForData:data width:qrSize color:[UIColor colorWithHex:0x444444] padding:0.0f];
        _qrCodeView.frame = CGRectMake(padding, padding, qrSize, qrSize);
        
        _addressLabel.text = address.checksumAddress;
        _addressLabel.frame = CGRectMake(qrSize + 2.0f * padding, padding + 4.0f, size.width - qrSize - 3.0f * padding, qrSize / 2.0f - 4.0f);
        
        _balanceLabel.balance = balance;
        _balanceLabel.frame = CGRectMake(qrSize + 2.0f * padding, padding + qrSize / 2.0f, size.width - qrSize - 3.0f * padding, qrSize / 2.0f - 4.0f);
        
        _noAccountView.hidden = YES;
        _qrCodeView.hidden = NO;
        _addressLabel.hidden = NO;
        _balanceLabel.hidden = NO;
        
    } else {
        _noAccountView.frame = self.view.bounds;
        
        _noAccountView.hidden = NO;
        _qrCodeView.hidden = YES;
        _addressLabel.hidden = YES;
        _balanceLabel.hidden = YES;
    }
    
    
}
- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    SharedDefaults *sharedDefaults = [SharedDefaults sharedDefaults];
    if ([sharedDefaults.address.checksumAddress isEqualToString:_addressLabel.text] && [sharedDefaults.balance isEqual:_balanceLabel.balance]) {
        completionHandler(NCUpdateResultNoData);
        
    } else {
        completionHandler(NCUpdateResultNewData);
    }
}

@end
