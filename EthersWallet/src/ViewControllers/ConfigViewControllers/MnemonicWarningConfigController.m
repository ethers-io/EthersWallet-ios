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

#import "MnemonicWarningConfigController.h"

#import "IconView.h"
#import "Utilities.h"

@implementation MnemonicWarningConfigController {
    NSString *_title;
    NSArray<NSString*> *_messages;
    NSString *_note;
}

+ (instancetype)mnemonicWarningTitle: (NSString*)title messages: (NSArray<NSString*>*)messages note: (NSString*)note {
    return [[MnemonicWarningConfigController alloc] initWithTitle:title messages:messages note:note];
}

- (instancetype)initWithTitle: (NSString*)title messages: (NSArray<NSString*>*)messages note: (NSString*)note {
    self = [super init];
    if (self) {
        _title = title;
        _messages = [messages copy];
        _note = note;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    [self addGap:15.0f];
    
    [self addHeadingText:_title];
    
    [self addGap:20.0f];
    
    for (NSString *message in _messages) {
        [self addMarkdown:message fontSize:15.0f];
    }
    
    [self addFlexibleGap];
    
    [self addMarkdown:@"When viewing your //backup phrase//, **watch for**:" fontSize:15.0f];
    
    [self addGap:15.0f];

    [self addIcons:@[
                     [IconView iconViewWithIcon:ICON_NAME_SECURITY_CAMERA topTitle:@"SECURITY" bottomTitle:@"CAMERAS"],
                     [IconView iconViewWithIcon:ICON_NAME_PRIVACY topTitle:@"NEARBY" bottomTitle:@"OBSERVERS"],
                     ]];
    
    [self addFlexibleGap];
    
    [self addMarkdown:_note fontSize:15.0f];
    
    [self addGap:15.0f];
    
    self.nextTitle = @"I Agree";
    
    __weak MnemonicWarningConfigController *weakSelf = self;
    
    [NSTimer scheduledTimerWithTimeInterval:2.0f repeats:NO block:^(NSTimer *timer) {
        weakSelf.nextEnabled = YES;
    }];
}

@end
