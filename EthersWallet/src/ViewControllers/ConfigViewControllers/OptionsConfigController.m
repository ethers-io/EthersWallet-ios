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


#import "OptionsConfigController.h"

#import "Utilities.h"


@implementation OptionsConfigController

+ (instancetype)configWithHeading:(NSString *)heading
                       subheading:(NSString *)subheading
                         messages:(NSArray<NSString *> *)messages
                          options:(NSArray<NSString *> *)options {
    return [[OptionsConfigController alloc] initWithHeading:heading subheading:subheading messages:messages options:options];
}

- (instancetype)initWithHeading:(NSString *)heading
                     subheading:(NSString *)subheading
                       messages:(NSArray<NSString *> *)messages
                        options:(NSArray<NSString *> *)options {
    
    self = [super init];
    if (self) {
        _heading = heading;
        _subheading = subheading;
        _messages = [messages copy];
        _options = [options copy];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    [self addFlexibleGap];
    
    if (_heading) {
        if (!self.step) {
            self.navigationItem.titleView = [Utilities navigationBarLogoTitle];
        }
        [self addHeadingText:_heading];

    } else {
        [self addText:ICON_NAME_LOGO font:[UIFont fontWithName:FONT_ETHERS size:100.0f]];
    }
    
    if (_subheading) {
        [self addText:_subheading font:[UIFont fontWithName:FONT_ITALIC size:17.0f]];
    }
    
    if (_messages) {
        [self addGap:64.0f];
        for (NSString *message in _messages) {
            [self addMarkdown:message fontSize:17.0f];
        }
    }
    
    [self addFlexibleGap];
    [self addFlexibleGap];

    __weak OptionsConfigController *weakSelf = self;
    
    void (^tapButton)(UIButton *button)  = ^(UIButton *button) {
        if (weakSelf.onOption) {
            weakSelf.onOption(weakSelf, button.tag);
        }
    };
    
    NSUInteger index = 0;
    for (NSString *option in _options) {
        UIButton *button = [self addButton:option action:tapButton];
        button.tag = index++;
    }

    [self addGap:44.0f];
}

@end
