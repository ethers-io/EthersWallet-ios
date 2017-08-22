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

#import "ConfigToggle.h"

@implementation ConfigToggle {
    UISwitch *_toggle;
}

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithTitle:title];
    if (self) {
        CGSize size = self.contentView.frame.size;
        
        _toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
        _toggle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _toggle.center = CGPointMake(size.width - 15.0f - _toggle.frame.size.width / 2.0f, size.height / 2.0f);
        [self.contentView addSubview:_toggle];
        
        [_toggle addTarget:self action:@selector(didToggle:) forControlEvents:UIControlEventValueChanged];
    }
    return self;
}

- (void)setOn:(BOOL)on {
    _toggle.on = on;
}

- (BOOL)on {
    return _toggle.on;
}

- (void)didToggle: (UISwitch*)sender {
    if (_didChange) { _didChange(self); }
}

@end
