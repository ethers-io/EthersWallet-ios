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

#import "MnemonicConfigController.h"

#import "MnemonicPhraseView.h"


@interface MnemonicConfigController () <MnemonicPhraseViewDelegate>

@end


@implementation MnemonicConfigController

+ (instancetype)mnemonicHeading: (NSString*)heading message: (NSString*)message note: (NSString*)note {
    return [[MnemonicConfigController alloc] initWithHeading:heading message:message note:note];
}

- (instancetype)initWithHeading: (NSString*)heading message: (NSString*)message note: (NSString*)note {
    self = [super init];
    if (self) {
        _heading = heading;
        _message = message;
        _note = note;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    [self addGap:44.0f];

    [self addHeadingText:_heading];
    
    [self addGap:20.0f];
    
    [self addMarkdown:_message fontSize:15.0f];
    
    [self addFlexibleGap];
    
    _mnemonicPhraseView = [[MnemonicPhraseView alloc] initWithFrame:CGRectZero withPhrase:nil];
    _mnemonicPhraseView.delegate = self;

    _mnemonicPhraseView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _mnemonicPhraseView.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 0.0f);
    _mnemonicPhraseView.userInteractionEnabled = NO;
    [self addView:_mnemonicPhraseView];
    
    [self addFlexibleGap];
    
    if (_note) {
        [self addMarkdown:_note fontSize:15.0f];
        [self addGap:15.0f];
    } else {
        [self addFlexibleGap];
    }
}

- (void)mnemonicPhraseViewDidChange:(MnemonicPhraseView *)mnemonicPhraseView {
    if (_didChange) { _didChange(self); }
}

@end
