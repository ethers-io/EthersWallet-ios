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

#import "TransactionTableViewCell.h"

#import "BalanceLabel.h"
#import "UIColor+hex.h"
#import "Utilities.h"
#import "Wallet.h"


NSString * const TransactionTableViewCellResuseIdentifier = @"TransactionTableViewCellResuseIdentifier";

const CGFloat TransactionTableViewCellHeightNormal     = 56.0f;
const CGFloat TransactionTableViewCellHeightSelected   = 100.0f;

static NSDateFormatter *DateFormat = nil;
static NSDateFormatter *TimeFormat = nil;


NSAttributedString *getTimestamp(NSTimeInterval timestamp) {
    NSDate *dateObject = [NSDate dateWithTimeIntervalSince1970:timestamp];
    
    NSString *date = [DateFormat stringFromDate:dateObject];
    NSString *time = [TimeFormat stringFromDate:dateObject];
    
    NSString *string = [NSString stringWithFormat:@"%@ %@", date, time];
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string];
    [attributedString setAttributes:@{
                                      NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:10.0f],
                                      }
                              range:NSMakeRange(0, date.length)];
    [attributedString setAttributes:@{
                                      NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:10.0f],
                                      }
                              range:NSMakeRange(date.length + 1, string.length - date.length - 1)];
    return attributedString;
}

@interface TransactionTableViewCell () {

    UILabel *_typeLabel;

    UILabel *_timestampLabel;
    UILabel *_addressLabel;

    BalanceLabel *_balanceLabel;
    BalanceLabel *_exactBalanceLabel;

    BalanceLabel *_feeLabel;
    
    UIView *_confirmationCount;
}



@end

@implementation TransactionTableViewCell

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DateFormat = [[NSDateFormatter alloc] init];
        DateFormat.locale = [NSLocale currentLocale];
        [DateFormat setDateFormat:@"yyyy-MM-dd"];

        TimeFormat = [[NSDateFormatter alloc] init];
        TimeFormat.locale = [NSLocale currentLocale];
        [TimeFormat setTimeStyle:NSDateFormatterShortStyle];
        
        // @TODO: Add notification to regenerate these on local change
    });
    
}


- (instancetype)init {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TransactionTableViewCellResuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        self.backgroundColor = [UIColor clearColor];
        CGRect frame = self.frame;

        _typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 6.0f, 100.0f, 24.0f)];
        _typeLabel.font = [UIFont fontWithName:FONT_BOLD_ITALIC size:12.0f];
        _typeLabel.textColor = [UIColor colorWithHex:ColorHexDark];
        [self.contentView addSubview:_typeLabel];
 
        _timestampLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 4.0f, frame.size.width, 24.0f)];
        _timestampLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _timestampLabel.textAlignment = NSTextAlignmentCenter;
        _timestampLabel.textColor = [UIColor colorWithHex:ColorHexNormal];
        [self.contentView addSubview:_timestampLabel];

        _addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 28.0f, frame.size.width - 15.0f - 100.0f, 22.0f)];
        _addressLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _addressLabel.font = [UIFont fontWithName:FONT_MONOSPACE_SMALL size:12.0f];
        _addressLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _addressLabel.textColor = [UIColor colorWithHex:ColorHexNormal];
        [self.contentView addSubview:_addressLabel];

        _balanceLabel = [BalanceLabel balanceLabelWithFrame:CGRectMake(frame.size.width - 115.0f, 0.0f, 100.0f, frame.size.height)
                                                   fontSize:15.0f
                                                      color:BalanceLabelColorStatus
                                                  alignment:BalanceLabelAlignmentAlignDecimal];
        _balanceLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
        [self.contentView addSubview:_balanceLabel];
        
        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 0.5f, frame.size.width, 0.5f)];
        separator.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        separator.backgroundColor = [UIColor colorWithWhite:0.8f alpha:1.0f];
        [self.contentView addSubview:separator];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(noticeTransactionUpdated:)
                                                     name:WalletTransactionChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)noticeTransactionUpdated: (NSNotification*)note {
    TransactionInfo *transactionInfo = [note.userInfo objectForKey:@"transaction"];
    if (_transactionInfo && [transactionInfo.transactionHash isEqualToHash:_transactionInfo.transactionHash]) {
        [self setAddress:_address transactionInfo:transactionInfo];
    }
}

- (void)setAddress:(Address *)address transactionInfo:(TransactionInfo *)transactionInfo {
    [self setAddress:address transactionInfo:transactionInfo animated:NO];
}

- (void)setAddress:(Address *)address transactionInfo:(TransactionInfo *)transactionInfo animated: (BOOL)animated {

    _address = address;
    _transactionInfo = transactionInfo;

    BigNumber *value = transactionInfo.value;
    
    if ([transactionInfo.toAddress isEqualToAddress:_address]) {
        if ([_transactionInfo.fromAddress isEqualToAddress:_address]) {
            _typeLabel.text = @"";
            _addressLabel.text = @"self";
        } else {
            _typeLabel.text = @"Received";
            _addressLabel.text = _transactionInfo.fromAddress.checksumAddress;
        }
    
    } else {
        if (_transactionInfo.contractAddress) {
            _typeLabel.text = @"Contract";
            _addressLabel.text = _transactionInfo.contractAddress.checksumAddress;
            value = [value mul:[BigNumber constantNegativeOne]];
        
        } else if ([_transactionInfo.fromAddress isEqualToAddress:_address]) {
            _typeLabel.text = @"Sent";
            _addressLabel.text = _transactionInfo.toAddress.checksumAddress;
            value = [value mul:[BigNumber constantNegativeOne]];
        
        } else {
            _typeLabel.text = @"unknown";
            _addressLabel.text = _transactionInfo.toAddress.checksumAddress;
        }
    }

    _timestampLabel.attributedText = getTimestamp(transactionInfo.timestamp);
    
    _balanceLabel.balance = value;
}

@end
