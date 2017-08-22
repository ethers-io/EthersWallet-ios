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

#import "PasswordConfigController.h"

#import "ConfigTextField.h"


@implementation PasswordConfigController

+ (instancetype)configWithHeading:(NSString *)heading message:(NSString *)message note:(NSString *)note {
    return [[PasswordConfigController alloc] initWithHeading:heading message:message note:note];
}

- (instancetype)initWithHeading:(NSString *)heading message:(NSString *)message note:(NSString *)note {
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
    
    [self addFlexibleGap];
    
    [self addHeadingText:_heading];
    
    [self addGap:20.0f];
    
    [self addMarkdown:_message fontSize:15.0f];
    
    [self addFlexibleGap];
    
    [self addSeparator];
    
    _passwordField = [self addPasswordTitle:@"Password"];
    _passwordField.placeholder = @"Required";
    
    __weak PasswordConfigController *weakSelf = self;
    
    _passwordField.didReturn = ^(ConfigTextField *textField) {
        if (weakSelf.onReturn) { weakSelf.onReturn(weakSelf); }
    };

    _passwordField.didChange = ^(ConfigTextField *textField) {
        if (weakSelf.didChange) { weakSelf.didChange(weakSelf); }
    };

    [self addSeparator];
    
    // optionally add a note
    if (_note) {
        [self addGap:7.0f];
        UITextView *noteTextView = [self addText:_note fontSize:12.0f];
        noteTextView.alpha = 0.7f;
    }
    
    // @TODO: Add a flexible-like gap for keyboards
    [self addFlexibleGap];
    [self addFlexibleGap];
    [self addFlexibleGap];
    [self addFlexibleGap];
}


@end
