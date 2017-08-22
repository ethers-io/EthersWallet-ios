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

#import "KeyboardView.h"

#import "Utilities.h"

@implementation KeyboardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        CGSize size = self.frame.size;
        
        _titleLabel = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(0.0f, 30.0f, size.width, 20.0f)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.font = [UIFont fontWithName:FONT_BOLD size:18.0f];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0f];
        [self addSubview:_titleLabel];

        _contentView = [[UIView alloc] initWithFrame:CGRectMake(35.0f, 60.0f, size.width - 70.0f, size.height - 60.0f - 25.0f)];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_contentView];
    }
    return self;
}

- (void)reflow {
    NSArray<UIView*> *subviews = _contentView.subviews;
    
    CGSize size = _contentView.frame.size;
    
    if (subviews.count == 1) {
        [subviews firstObject].center = CGPointMake(size.width / 2.0f, size.height / 2.0f);
        return;
    }
    
    CGFloat staticHeight = 0.0f;
    for (UIView *view in subviews) {
        staticHeight += view.frame.size.height;
    }
    
    CGFloat gap = (size.height - staticHeight) / (subviews.count - 1);

    CGFloat y = 0.0f;
    for (UIView *view in subviews) {
        
        view.center = CGPointMake(size.width / 2.0f, y + view.frame.size.height / 2.0f);
        
        y += view.frame.size.height + gap;
    }
}

- (void)addView:(UIView *)view {
    if ([view isKindOfClass:[UILabel class]]) {
        CGRect frame = view.frame;
        frame.size.width = _contentView.frame.size.width;
        view.frame = frame;
        
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        ((UILabel*)view).textAlignment = NSTextAlignmentCenter;
    } else {
        view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    }
    
    [_contentView addSubview:view];
    [self reflow];
}

@end
