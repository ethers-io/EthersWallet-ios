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

#import "SectionHeaderView.h"

#import "UIColor+hex.h"
#import "Utilities.h"

@interface SectionHeaderView () {
    UILabel *_titleLabel, *_detailsLabel;
}

@end

@implementation SectionHeaderView

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 30.0f)];
    if (self) {

        UIView *background = [[UIView alloc] initWithFrame:self.bounds];
        background.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        background.backgroundColor = [UIColor colorWithHex:0xf5f9ff];
        [self addSubview:background];

        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.frame.size.height - 0.5f, self.frame.size.width, 0.5f)];
        separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        separator.backgroundColor = [UIColor colorWithHex:ColorHexLight];
        [self addSubview:separator];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 0.0f, self.frame.size.width - 30.0f, self.frame.size.height)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.font = [UIFont fontWithName:FONT_BOLD size:12.0f];
        _titleLabel.textAlignment = NSTextAlignmentLeft;
        _titleLabel.textColor = [UIColor colorWithHex:ColorHexToolbarIcon];
        [self addSubview:_titleLabel];

        _detailsLabel = [[UILabel alloc] initWithFrame:_titleLabel.frame];
        _detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _detailsLabel.font = [UIFont fontWithName:FONT_ITALIC size:10.0f];
        _detailsLabel.textAlignment = NSTextAlignmentRight;
        _detailsLabel.textColor = [UIColor colorWithHex:ColorHexNavigationBar];
        [self addSubview:_detailsLabel];
    }
    return self;
}

+ (instancetype)sectionHeaderViewWithTitle: (NSString*)title details: (NSString*)details {
    SectionHeaderView *sectionHeaerView = [[SectionHeaderView alloc] init];
    sectionHeaerView.title = title;
    sectionHeaerView.details = details;
    return sectionHeaerView;
}

- (void)setTitle:(NSString *)title {
    _titleLabel.text = title;
}

- (NSString*)title {
    return _titleLabel.text;
}

- (void)setDetails:(NSString *)details {
    _detailsLabel.text = details;
}

- (NSString*)details {
    return _detailsLabel.text;
}

@end
