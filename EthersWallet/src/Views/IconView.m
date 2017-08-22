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

#import "IconView.h"

#import "Utilities.h"

@implementation IconView {
    UILabel *_topLabel, *_bottomLabel, *_iconLabel;
}

- (instancetype)initWithIcon: (NSString*)icon topTitle: (NSString*)topTitle bottomTitle: (NSString*)bottomTitle {
    CGRect frame = CGRectMake(0.0f, 0.0f, 80.0f, 80.0f);
    self = [super initWithFrame:frame];
    
    if (self) {
        _iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width - 20.0f, frame.size.width - 20.0f)];
        _iconLabel.center = CGPointMake(frame.size.width / 2.0f, frame.size.height / 2.0f);
        _iconLabel.font = [UIFont fontWithName:FONT_ETHERS size:36.0f];
        _iconLabel.layer.cornerRadius = _iconLabel.frame.size.width / 2.0f;
        _iconLabel.layer.borderColor = [UIColor colorWithWhite:0.85f alpha:1.0f].CGColor;
        _iconLabel.layer.borderWidth = 3.0f;
        _iconLabel.text = icon;
        _iconLabel.textAlignment = NSTextAlignmentCenter;
        _iconLabel.textColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
        [self addSubview:_iconLabel];
        
        _topLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, 13.0f)];
        _topLabel.font = [UIFont fontWithName:FONT_BOLD size:12.0f];
        _topLabel.shadowColor = [UIColor colorWithWhite:0.3 alpha:1.0f];
        _topLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _topLabel.text = topTitle;
        _topLabel.textAlignment = NSTextAlignmentCenter;
        _topLabel.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        [self addSubview:_topLabel];
        
        _bottomLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 13.0f, frame.size.width, 13.0f)];
        _bottomLabel.font = _topLabel.font;
        _bottomLabel.shadowColor = _topLabel.shadowColor;
        _bottomLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        _bottomLabel.text = bottomTitle;
        _bottomLabel.textAlignment = NSTextAlignmentCenter;
        _bottomLabel.textColor = _topLabel.textColor;
        [self addSubview:_bottomLabel];
    }
    
    return self;
}

+ (instancetype)iconViewWithIcon: (NSString*)icon topTitle: (NSString*)topTitle bottomTitle: (NSString*)bottomTitle {
    return [[IconView alloc] initWithIcon:icon topTitle:topTitle bottomTitle:bottomTitle];
}

- (NSString*)topTitle {
    return _topLabel.text;
}

- (void)setTopTitle:(NSString *)topTitle {
    _topLabel.text = topTitle;
}

- (NSString*)bottomTitle {
    return _bottomLabel.text;
}

- (void)setBottomTitle:(NSString *)bottomTitle {
    _bottomLabel.text = bottomTitle;
}

@end
