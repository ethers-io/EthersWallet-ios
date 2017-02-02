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

/**
 *  Balance Label
 *
 *  A label to format numbers that represent an amount of Ethereum Wei. A Xi and
 *  space are prepended to the amount, which is converted to ether.
 *
 *  Standard Formatting:
 *    - There is at least one digit before the decimal point
 *    - There is at least one digit after the decimal point and no more than 5
 *
 *  BalanceLabelAlignmentAlignDecimal Formatting:
 *    - Exactly 5 decimal places are shown; trailing zeros are faint
 */


#import <UIKit/UIKit.h>

#import <ethers/BigNumber.h>


typedef enum BalanceLabelColor {
    BalanceLabelColorDark,
    BalanceLabelColorVeryDark,
    BalanceLabelColorBlack,
    BalanceLabelColorLight,
    BalanceLabelColorStatus
} BalanceLabelColor;

typedef enum BalanceLabelAlignment {
    BalanceLabelAlignmentLeft,
    BalanceLabelAlignmentCenter,
    BalanceLabelAlignmentRight,
    BalanceLabelAlignmentAlignDecimal
} BalanceLabelAlignment;

@interface BalanceLabel : UIView

+ (instancetype)balanceLabelWithFrame: (CGRect)frame
                             fontSize: (CGFloat)fontSize
                                color: (BalanceLabelColor)color
                            alignment: (BalanceLabelAlignment)alignment;

@property (nonatomic, readonly) CGFloat fontSize;
@property (nonatomic, readonly) BalanceLabelColor color;
@property (nonatomic, readonly) BalanceLabelAlignment alignment;

@property (nonatomic, strong) BigNumber *balance;

@end
