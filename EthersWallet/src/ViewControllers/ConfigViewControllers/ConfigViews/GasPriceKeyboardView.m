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
#import "SignedRemoteDictionary.h"
#import "UIColor+hex.h"
#import "Utilities.h"


static NSString *GasPriceDataUrl        = @"https://ethers.io/gas-prices-v2.raw";
static NSString *GasPriceDataAddress    = @"0xcf49182a885E87fD55f4215def0f56EC71bB7511";



@implementation GasPriceKeyboardView {
    NSArray<NSString*> *_titles, *_subtitles, *_details;
    NSMutableArray<BigNumber*> *_gasPrices;
}


NSArray<NSString*> *GasTierTitles = nil;
NSArray<NSString*> *GasTierSubtitles = nil;

NSArray<NSString*> *GasTierDetails = nil;
NSArray<NSString*> *GasPrices = nil;


+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GasTierTitles = @[
                          @"SAFE LOW",
                          @"AVERAGE",
                          @"URGENT",
                          ];
        
        GasTierSubtitles = @[
                             @"completes in about 25 minutes",
                             @"completes in about 6 minutes",
                             @"completes in about 48 seconds",
                             ];
        
        
        GasTierDetails = @[
                           @"2 GWei",
                           @"4 Gwei",
                           @"100 GWei",
                           ];
        
        GasPrices = @[
                      @"2000000000",
                      @"4000000000",
                      @"100000000000",
                      ];
    });
}


+ (Promise*)checkForUpdatedGasPrices {
    SignedRemoteDictionary *gasPriceData = [self signedGasPricesDictionary];
    [[gasPriceData data] onCompletion:^(DictionaryPromise *promise) {
        if (promise.error) { return; }
        
        // Make sure each field is the same length and an array of strings
        NSInteger count = -1;
        for (NSString *key in promise.value) {
            NSArray *values = [promise.value objectForKey:key];
            if (![values isKindOfClass:[NSArray class]]) {
                NSLog(@"GasPriceKeyboardView - invalid array: %@", values);
                return;
            }
            for (NSString *value in values) {
                if (![value isKindOfClass:[NSString class]]) {
                    NSLog(@"GasPriceKeyboardView -  invalid key/value: %@ = %@", key, value);
                    return;
                }
            }
            
            if (count == -1) {
                count = values.count;
            } else if (count != values.count) {
                NSLog(@"GasPriceKeyboardView - invalid length %@ %@.count != %d", key, values, (int)count);
                return;
            }
        }
        
        // Makes sure each field is specified
        if (![promise.value objectForKey:@"titles"]) {
            NSLog(@"GasPriceKeyboardView - missing titles");
            return;
        }
        if (![promise.value objectForKey:@"subtitles"]) {
            NSLog(@"GasPriceKeyboardView - missing subtitles");
            return;
        }
        if (![promise.value objectForKey:@"details"]) {
            NSLog(@"GasPriceKeyboardView - missing details");
            return;
        }
        if (![promise.value objectForKey:@"prices"]) {
            NSLog(@"GasPriceKeyboardView - missing prices");
            return;
        }
        
        BigNumber *tooExpensive = [BigNumber bigNumberWithDecimalString:@"200000000000"];

        // Make sure each price is a valid decimal number
        for (NSString *gasPriceString in [promise.value objectForKey:@"prices"]) {
            BigNumber *gasPrice = [BigNumber bigNumberWithDecimalString:gasPriceString];
            if (!gasPrice) {
                NSLog(@"GasPriceKeyboardView - invalid number: %@", gasPriceString);
                return;
            }
            if ([gasPrice greaterThanEqualTo:tooExpensive]) {
                NSLog(@"GasPriceKeyboardView - too expensive: %@", gasPriceString);
                return;
            }
        }
        
        // All good! Store the
        
        GasTierTitles = [promise.value objectForKey:@"titles"];
        GasTierSubtitles = [promise.value objectForKey:@"subtitles"];
        GasTierDetails = [promise.value objectForKey:@"details"];
        GasPrices = [promise.value objectForKey:@"prices"];
        
        NSLog(@"GasPriceKeyboardView: Updated Prices - %@", GasPrices);
    }];
    return [gasPriceData data];
}

+ (SignedRemoteDictionary*)signedGasPricesDictionary {
    NSDictionary *defaults = @{
                               @"titles": GasTierTitles,
                               @"subtitles": GasTierSubtitles,
                               @"details": GasTierDetails,
                               @"prices": GasPrices
                               };

    return [SignedRemoteDictionary dictionaryWithUrl:GasPriceDataUrl
                                             address:[Address addressWithString:GasPriceDataAddress]
                                         defaultData:defaults];
}

+ (BigNumber*)safeReplacementGasPrice {
    if ([GasPrices count] == 0) { return [BigNumber constantZero]; }
    return [BigNumber bigNumberWithDecimalString:[GasPrices objectAtIndex:([GasPrices count] - 1) / 2]];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame stopCount:GasPrices.count];
    if (self) {
        
        _titles = GasTierTitles;
        _subtitles = GasTierSubtitles;
        _details = GasTierDetails;
        
        
        _gasPrices = [NSMutableArray arrayWithCapacity:GasPrices.count];
        for (NSString *gasPriceString in GasPrices) {
            [_gasPrices addObject:[BigNumber bigNumberWithDecimalString:gasPriceString]];
        }
        
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
    [self.titleLabel setText:[_titles objectAtIndex:self.selectedStopIndex] animated:animated];
    [self.topInfo setText:[_subtitles objectAtIndex:self.selectedStopIndex] animated:animated];
    [self.bottomInfo setText:[_details objectAtIndex:self.selectedStopIndex] animated:animated];
}

- (BigNumber*)gasPrice {
    //if (self.selectedStopIndex == 0) { return [BigNumber bigNumberWithDecimalString:@"100000000"]; }
    return [_gasPrices objectAtIndex:self.selectedStopIndex];
}

@end
