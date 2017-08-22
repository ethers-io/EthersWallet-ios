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

#import "GasLimitKeyboardView.h"

#import "UIColor+hex.h"
#import "Utilities.h"


@implementation GasLimitKeyboardView {
    //NSArray<NSString*> *_texts;
    NSArray<BigNumber*> *_limits;
    BigNumber *_fuzzyEstimate;
}

+ (BigNumber*)transferGasLimit {
    return [BigNumber bigNumberWithInteger:21000];
}

- (instancetype)initWithFrame:(CGRect)frame gasEstimate:(BigNumber *)gasEstmimate {
    self = [super initWithFrame:frame stopCount:6];
    if (self) {
        _gasEstimate = gasEstmimate;
        
        // Add 20% for good measure
        _fuzzyEstimate = [_gasEstimate div:[BigNumber bigNumberWithInteger:(100 / 20)]];
        _fuzzyEstimate = [_fuzzyEstimate add:gasEstmimate];
        
        
        [self.titleLabel setText:@"CONTRACT EXECUTION" animated:NO];

        _limits = @[
                    [BigNumber bigNumberWithDecimalString:@"21000"],
                    [BigNumber bigNumberWithDecimalString:@"150000"],
                    [BigNumber bigNumberWithDecimalString:@"250000"],
                    [BigNumber bigNumberWithDecimalString:@"500000"],
                    [BigNumber bigNumberWithDecimalString:@"750000"],
                    [BigNumber bigNumberWithDecimalString:@"1500000"],
                    ];

        self.selectedStopIndex = _limits.count - 1;
        for (NSInteger i = _limits.count - 2; i >= 0; i--) {
            if ([[_limits objectAtIndex:i] compare:_fuzzyEstimate] != NSOrderedDescending) {
                break;
            }
            self.selectedStopIndex = i;
        }
        
        __weak GasLimitKeyboardView *weakSelf = self;
        self.didChange = ^(SliderKeyboardView *view) {
            if (weakSelf.didChangeGasLimit) {
                weakSelf.didChangeGasLimit(weakSelf);
            }
        };
        
        [self refreshAnimated:NO];
        
    }
    return self;
}

- (BigNumber*)gasLimit {
    return [_limits objectAtIndex:self.selectedStopIndex];
}

- (BOOL)safeGasLimit {
    return ([self.gasLimit compare:_fuzzyEstimate] != NSOrderedAscending);
}
- (void)refreshAnimated:(BOOL)animated {
    if (!_limits) { return; }

    NSString *formattedLimit = [NSNumberFormatter localizedStringFromNumber:@(self.gasLimit.integerValue)
                                                                numberStyle:NSNumberFormatterDecimalStyle];
    [self.topInfo setText:[NSString stringWithFormat:@"allow up to %@ gas", formattedLimit] animated:YES];
    
    NSString *formattedGas = [NSNumberFormatter localizedStringFromNumber:@(_gasEstimate.integerValue)
                                                              numberStyle:NSNumberFormatterDecimalStyle];
    [self.bottomInfo setText:[NSString stringWithFormat:@"Estimated Gas Required: %@ gas", formattedGas] animated:animated];
    
    if (!self.safeGasLimit) {
        self.bottomInfo.textColor = [UIColor redColor];
        self.bottomInfo.font = [UIFont fontWithName:FONT_BOLD size:15.0f];
    } else {
        self.bottomInfo.textColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
        self.bottomInfo.font = [UIFont fontWithName:FONT_MEDIUM size:13.0f];
   
    }
}


@end
