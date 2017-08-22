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
#import "ConfigView.h"


typedef enum ConfigTextFieldStatus {
    ConfigTextFieldStatusNone = 0,
    ConfigTextFieldStatusGood,
    ConfigTextFieldStatusBad,
    ConfigTextFieldStatusSpinning
} ConfigTextFieldStatus;


typedef enum ConfigTextFieldOption {
    ConfigTextFieldOptionNone                 = 0,
    ConfigTextFieldOptionNoCaret              = (1 << 0),
    ConfigTextFieldOptionNoMenu               = (1 << 1),
    ConfigTextFieldOptionNoInteraction        = (1 << 2),
} ConfigTextFieldOption;


@interface ConfigTextField : ConfigView

- (instancetype)initWithTitle: (NSString*)title options: (NSUInteger)options;

@property (nonatomic, assign) ConfigTextFieldStatus status;

@property (nonatomic, strong) NSString *placeholder;

@property (nonatomic, readonly) UITextField *textField;
@property (nonatomic, readonly) UIButton *button;

@property (nonatomic, copy) void (^didChange)(ConfigTextField*);
@property (nonatomic, copy) BOOL (^shouldChange)(ConfigTextField*, NSRange, NSString*);
@property (nonatomic, copy) void (^didReturn)(ConfigTextField*);

@property (nonatomic, copy) NSString *buttonTitle;
@property (nonatomic, copy) void (^onButton)(ConfigTextField*);


- (void)setEther:(BigNumber *)ether;

@end
