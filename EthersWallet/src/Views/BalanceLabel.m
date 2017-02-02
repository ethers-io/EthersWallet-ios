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

#import "BalanceLabel.h"

#import <ethers/Payment.h>

#import "UIColor+hex.h"
#import "Utilities.h"


@interface BalanceLabel () {
    BigNumber *_balance;
    UILabel *_label;
}

@end


@implementation BalanceLabel

+ (instancetype)balanceLabelWithFrame: (CGRect)frame fontSize: (CGFloat)fontSize color:(BalanceLabelColor)color alignment:(BalanceLabelAlignment)alignment {
    return [[BalanceLabel alloc] initWithFrame:frame fontSize:fontSize color:color alignment:alignment];
}

- (instancetype)initWithFrame: (CGRect)frame fontSize: (CGFloat)fontSize color:(BalanceLabelColor)color alignment:(BalanceLabelAlignment)alignment {
    self = [super initWithFrame:frame];
    if (self) {
        _balance = [BigNumber constantZero];

        _fontSize = fontSize;
        _color = color;
        _alignment = alignment;

        
        _label = [[UILabel alloc] initWithFrame:self.bounds];
        _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_label];
        
        switch (_alignment) {
            case BalanceLabelAlignmentLeft:
                _label.textAlignment = NSTextAlignmentLeft;
                break;
            case BalanceLabelAlignmentCenter:
                _label.textAlignment = NSTextAlignmentCenter;
                break;
            case BalanceLabelAlignmentRight:
            case BalanceLabelAlignmentAlignDecimal:
                _label.textAlignment = NSTextAlignmentRight;
                break;
            default:
                break;
        }

        [self setBalance:_balance];
    }
    return self;
}

- (NSUInteger)colorForBalance: (BigNumber*)balance {
    switch (_color) {
        case BalanceLabelColorDark:
            return ColorHexGray;

        case BalanceLabelColorVeryDark:
            return 0x444444;
            
        case BalanceLabelColorLight:
            return ColorHexWhite;
        
        case BalanceLabelColorStatus:
            if ([_balance isNegative]) {
                return ColorHexRed;
            } else if ([_balance isZero]) {
                return ColorHexGray;
            }
            return ColorHexGreen;
        
        case BalanceLabelColorBlack:
            return ColorHexBlack;
    }
    
    return ColorHexBlack;
}

- (NSAttributedString*)attributedStringForBalance: (BigNumber*)balance {
    
    NSInteger color = [self colorForBalance:balance];
    
    NSString *string = [Payment formatEther:balance
                                    options:(EtherFormatOptionCommify | EtherFormatOptionApproximate)];
    string = [@"Ξ " stringByAppendingString:string];
    
    NSUInteger period = [string rangeOfString:@"."].location;
    
    NSInteger fadedStart = string.length;
    if (_alignment == BalanceLabelAlignmentAlignDecimal) {
        while(string.length - period - 1 < 5) {
            string = [string stringByAppendingString:@"0"];
        }
    }
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string];
    
    // Fade and shrink the Xi
    [attributedString setAttributes:@{
                                      NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:(_fontSize * 15.0f / 20.0f)],
                                      NSForegroundColorAttributeName: [UIColor colorWithHex:color alpha:0.9f]
                                      } range:NSMakeRange(0, 1)];
    
    [attributedString setAttributes:@{
                                      NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:_fontSize],
                                      NSForegroundColorAttributeName: [UIColor colorWithHex:color alpha:1.0f]
                                      } range:NSMakeRange(1, period + 1)];
    
    [attributedString setAttributes:@{
                                      NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:(_fontSize * 18.0f / 20.0f)],
                                      NSForegroundColorAttributeName: [UIColor colorWithHex:color alpha:1.0f]
                                      } range:NSMakeRange(period + 1, fadedStart - period - 1)];
    
    if (fadedStart < string.length) {
        [attributedString setAttributes:@{
                                          NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:(_fontSize * 18.0f / 20.0f)],
                                          NSForegroundColorAttributeName: [UIColor colorWithHex:color alpha:0.1f]
                                          } range:NSMakeRange(fadedStart, string.length - fadedStart)];
    }
    
    return attributedString;
}

- (void)updateAlignment {
    if (_alignment != BalanceLabelAlignmentAlignDecimal) { return; }
    
}

- (BigNumber*)balance {
    return _balance;
}

- (void)setBalance:(BigNumber *)balance {
    if (!balance) { balance = [BigNumber constantZero]; }
    _balance = balance;
    
    _label.attributedText = [self attributedStringForBalance:_balance];
}


@end
