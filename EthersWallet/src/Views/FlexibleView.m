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

#import "FlexibleView.h"

@implementation FlexibleView {
    NSInteger _nextTag;
    NSUInteger _gaps;
    CGFloat _staticHeight;
}

- (void)addFlexibleGap {
    _nextTag++;
    _gaps++;
}

- (void)addSubview:(UIView *)view {
    UIView *container = [[UIView alloc] initWithFrame:view.bounds];
    [super addSubview:container];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    container.tag = _nextTag++;

    [container addSubview:view];
    
    _staticHeight += view.frame.size.height;
}

- (void)layoutSubviews {
    CGFloat flexibleHeight = (self.frame.size.height - _staticHeight) / _gaps;
    CGFloat width = self.frame.size.width;
    
    CGFloat y = 0.0f;

    NSInteger tag = 0;
    for (UIView *view in self.subviews) {
        while (tag < view.tag) {
            y += flexibleHeight;
            tag++;
        }

        CGRect frame = view.frame;
        frame.origin.x = 0;
        frame.origin.y = y;
        frame.size.width = width;
        view.frame = frame;
        
        y += frame.size.height;
        
        tag++;
    }
}

@end
