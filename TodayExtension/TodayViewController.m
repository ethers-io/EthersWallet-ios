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
    Address *_address;
    float _etherPrice;
    BigNumber *_totalBalance;
    
    UIImageView *_qrCodeView;

    UIView *_separator;

    BalanceLabel *_totalBalanceLabel;
    UILabel *_fiatBalanceLabel, *_fiatRateLabel;
    
    UILabel *_noAccountView;
}

@end

@implementation TodayViewController

static NSNumberFormatter *DecimalFormatter = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DecimalFormatter = [[NSNumberFormatter alloc] init];
        [DecimalFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    });
}

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
    
    
    _separator = [[UIView alloc] initWithFrame:CGRectZero];
    //_separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _separator.backgroundColor = [UIColor colorWithHex:0x444444];
    [self.view addSubview:_separator];
    
    _totalBalanceLabel = [BalanceLabel balanceLabelWithFrame:CGRectZero
                                                    fontSize:20.0f
                                                       color:BalanceLabelColorVeryDark
                                                   alignment:BalanceLabelAlignmentCenter];
    [self.view addSubview:_totalBalanceLabel];

    _fiatBalanceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _fiatBalanceLabel.textAlignment = NSTextAlignmentCenter;
    _fiatBalanceLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _fiatBalanceLabel.textColor = [UIColor colorWithHex:0x444444];
    _fiatBalanceLabel.font = [UIFont fontWithName:FONT_BOLD size:20.0f];
    [self.view addSubview:_fiatBalanceLabel];

    _fiatRateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _fiatRateLabel.textAlignment = NSTextAlignmentCenter;
    _fiatRateLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _fiatRateLabel.textColor = [UIColor colorWithHex:0x444444];
    _fiatRateLabel.font = [UIFont fontWithName:FONT_NORMAL size:12.0f];
    [self.view addSubview:_fiatRateLabel];

    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapWidget)]];
}

- (void)tapWidget {
    NSString *url = @"ethers://wallet";
    [self.extensionContext openURL:[NSURL URLWithString:url] completionHandler:^(BOOL success) { }];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    SharedDefaults *sharedDefaults = [SharedDefaults sharedDefaults];

    _address = sharedDefaults.address;
    _totalBalance = sharedDefaults.totalBalance;
    _etherPrice = sharedDefaults.etherPrice;

    if (_address) {
        CGSize size = self.view.frame.size;
        
        const float padding = 10.0f;
        float height = size.height;
        float qrSize = height - 2.0f * padding;
        
        NSData *data = [[@"iban:" stringByAppendingString:_address.icapAddress] dataUsingEncoding:NSASCIIStringEncoding];
        
        _qrCodeView.image = [Utilities qrCodeForData:data width:qrSize color:[UIColor colorWithHex:0x444444] padding:0.0f];
        _qrCodeView.frame = CGRectMake(padding, padding, qrSize, qrSize);
        
        _totalBalanceLabel.balance = _totalBalance;
        _totalBalanceLabel.frame = CGRectMake(qrSize + 2.0f * padding,
                                              0,
                                              size.width - qrSize - 3.0f * padding,
                                              size.height / 2.0f);
        
        _separator.frame = CGRectMake(qrSize + 2.0f * padding,
                                      size.height / 2.0f,
                                      size.width - qrSize - 3.0f * padding,
                                      0.5f);
        
        BigNumber *fiatValue = _totalBalance;
        //fiatValue = [BigNumber constantZero];
        fiatValue = [fiatValue mul:[BigNumber bigNumberWithInteger:(int)(100 * _etherPrice)]];
        fiatValue = [fiatValue div:[BigNumber constantWeiPerEther]];
        NSString *fiatValueString = fiatValue.decimalString;
        
        // Make sure we have at least 1 dollar and 2 cent characters
        while (fiatValueString.length < 3) { fiatValueString = [@"0" stringByAppendingString:fiatValueString]; }
        
        NSUInteger dollars = [[fiatValueString substringToIndex:fiatValueString.length - 2] intValue];

        NSString *dollarsString = [DecimalFormatter stringFromNumber:@(dollars)];
        NSString *centsString = [fiatValueString substringFromIndex:fiatValueString.length - 2];
        
        NSString *fiatDetails = [NSString stringWithFormat:@"$ %@ %@", dollarsString, centsString];
        
        NSMutableAttributedString *label = [[NSMutableAttributedString alloc] initWithString:fiatDetails];
        NSUInteger offset = 0;
        
        // Dollar sign
        [label setAttributes:@{NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:12.0f], NSBaselineOffsetAttributeName: @(4)}
                       range:NSMakeRange(offset, 1)];
        offset += 1;

        // Space
        [label setAttributes:@{NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:4.0f]}
                       range:NSMakeRange(offset, 1)];
        offset += 1;

        // Dollars
        [label setAttributes:@{NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:20.0f]}
                       range:NSMakeRange(offset, dollarsString.length)];
        offset += dollarsString.length;

        // Decimal Point
        /*
        [label setAttributes:@{NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:14.0f], NSBaselineOffsetAttributeName: @(3)}
                       range:NSMakeRange(offset, 1)];
        offset += 1;
         */

        // Space
        [label setAttributes:@{NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:4.0f]}
                       range:NSMakeRange(offset, 1)];
        offset += 1;

        // Cents
        [label setAttributes:@{
                               NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:12.0f],
                               NSBaselineOffsetAttributeName: @(6),
                               //NSForegroundColorAttributeName: [UIColor colorWithHex:0x666666],
                               NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)}
                       range:NSMakeRange(offset, 2)];
        offset += 2;

        float x = qrSize + 2.0f * padding, w = (size.width - qrSize - 3 * padding) / 2.0f;
        _fiatBalanceLabel.attributedText = label;
        _fiatBalanceLabel.frame = CGRectMake(x, size.height / 2.0f, w, size.height / 2.0f);

        _fiatRateLabel.text = [NSString stringWithFormat:@"$%.02f\u2009/\u2009ether", _etherPrice];
        _fiatRateLabel.frame = CGRectMake(x + w, size.height / 2.0f, w, size.height / 2.0f);

        _noAccountView.hidden = YES;
        _qrCodeView.hidden = NO;
        _separator.hidden = NO;
        _totalBalanceLabel.hidden = NO;
        _fiatRateLabel.hidden = NO;
        _fiatBalanceLabel.hidden = NO;
        
    } else {
        _noAccountView.frame = self.view.bounds;
        
        _noAccountView.hidden = NO;
        _qrCodeView.hidden = YES;
        _separator.hidden = YES;
        _totalBalanceLabel.hidden = YES;
        _fiatRateLabel.hidden = YES;
        _fiatBalanceLabel.hidden = YES;
    }
}
- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    SharedDefaults *sharedDefaults = [SharedDefaults sharedDefaults];
    
    NCUpdateResult result = NCUpdateResultNoData;
    
    if (![sharedDefaults.totalBalance isEqual:_totalBalance]) {
        result = NCUpdateResultNewData;
    } else if (![sharedDefaults.address isEqualToAddress:_address]) {
        result = NCUpdateResultNewData;
    } else if (sharedDefaults.etherPrice != _etherPrice) {
        result = NCUpdateResultNewData;
    }
    
    completionHandler(result);
}

@end
