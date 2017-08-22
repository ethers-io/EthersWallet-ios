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

typedef enum ConfigViewHold {
    ConfigViewHoldNone = 0,
    ConfigViewHoldTitle,
    ConfigViewHoldContent
} ConfigViewHold;

@interface ConfigView : UIView

- (instancetype)initWithTitle: (NSString*)title;

@property (nonatomic, copy) NSString *title;

// Subclasses can use this to place their content next to the title
@property (nonatomic, readonly) UIView *contentView;

- (void)pulse;

@property (nonatomic, copy) void (^onHold)(ConfigView*, ConfigViewHold);
@property (nonatomic, copy) void (^didTap)(ConfigView*);

@property (nonatomic, assign) CGFloat bottomMargin;

@end
