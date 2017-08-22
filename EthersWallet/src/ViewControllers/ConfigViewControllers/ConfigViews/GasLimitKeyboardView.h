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

#import <UIKit/UIKit.h>

#import <ethers/BigNumber.h>

#import "SliderKeyboardView.h"


@interface GasLimitKeyboardView : SliderKeyboardView

- (instancetype)initWithFrame:(CGRect)frame gasEstimate: (BigNumber*)gasEstmimate;

@property (nonatomic, readonly) BigNumber *gasEstimate;

@property (nonatomic, readonly) BigNumber *gasLimit;
@property (nonatomic, readonly) BOOL safeGasLimit;

@property (nonatomic, copy) void (^didChangeGasLimit)(GasLimitKeyboardView*);

+ (BigNumber*)transferGasLimit;

@end

/*

 Gas Price - about 3 minutes - The **lowest safe** gas price

 The **Gas Price** is how the price you are willing to pay (in Wei) per unit of gas. 
 A higher **Gas Prices** will increase the transaction fee but will confirm faster.
 
 Gas Limit - XXX gas - This transaction is estimated to require a minimum of YYY gas. It may require more.
 
 Gas Limit - XXX gas - This transaction is estimated to require a minimum of YYY gas. It may require more.
 
 Gas Price - <b>Safe Low</b><br />about 3 miuntes - The "Safe Low"

 
 Gas Limit (Contract) - ==Contract Execution== \n The estimated gas requirement is YYY. It is recommended to use more since unused gas is refunded immediately after execution.
 Gas Limit (EOA) - ==Transfer== \n This transaction requires exactly 21,000 units of gas.
 
 Transfers to other users require exactly 21,000 gas. This address is a standard account (not a contract) which requires exactly 21,000 gas to
 This address belongs to another user (not a contract)Sending to Non-Contracts require exactly 21,000 gas.

*/
