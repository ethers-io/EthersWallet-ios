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

#import "GasPriceKeyboardView.h"

#import "CrossfadeLabel.h"
#import "UIColor+hex.h"
#import "Utilities.h"



@implementation GasPriceKeyboardView {
    NSArray<NSString*> *_estimateText, *_gasPriceNameText, *_gasPriceValueText;
    NSArray<BigNumber*> *_gasPrices;
}

- (instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame stopCount:3];
    if (self) {

        _estimateText = @[
                          @"completes in about 14 minutes",
                          @"completes in about 3 minutes",
                          @"completes in about 48 seconds",
                          ];
        
        _gasPriceNameText = @[
                              @"SAFE LOW",
                              @"AVERAGE",
                              @"URGENT",
                              ];
        
        _gasPriceValueText = @[
                               @"2 GWei",
                               @"4 Gwei",
                               @"100 GWei",
                               ];
        
        _gasPrices = @[
                       [BigNumber bigNumberWithDecimalString:@"2000000000"],
                       [BigNumber bigNumberWithDecimalString:@"4000000000"],
                       [BigNumber bigNumberWithDecimalString:@"100000000000"],
                       ];
        
        __weak GasPriceKeyboardView *weakSelf = self;
        self.didChange = ^(SliderKeyboardView *view) {
            if (weakSelf.didChangeGasPrice) {
                weakSelf.didChangeGasPrice(weakSelf);
            }
        };

        [self refreshAnimated:NO];
    }
    return self;
}

- (void)refreshAnimated:(BOOL)animated {
    if (!_estimateText) { return ; }
    
    [self.titleLabel setText:[_gasPriceNameText objectAtIndex:self.selectedStopIndex] animated:animated];
    [self.topInfo setText:[_estimateText objectAtIndex:self.selectedStopIndex] animated:animated];
    [self.bottomInfo setText:[_gasPriceValueText objectAtIndex:self.selectedStopIndex] animated:animated];
}

- (BigNumber*)gasPrice {
    return [_gasPrices objectAtIndex:self.selectedStopIndex];
}

@end
