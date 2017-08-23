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

#import "ConfigLabel.h"
#import "ConfigToggle.h"
#import "ConfigTextField.h"
#import "IconView.h"

@interface ConfigController : UIViewController

- (void)setStep: (NSUInteger)step totalSteps: (NSUInteger)totalSteps;

@property (nonatomic, readonly) NSUInteger step;
@property (nonatomic, readonly) NSUInteger totalSteps;


//- (void)setNextIcon:(NSString*)nextIcon action:(void (^)())action;
@property (nonatomic, copy) NSString *nextTitle;
@property (nonatomic, assign) BOOL nextEnabled;

@property (nonatomic, copy) void (^onNext)(ConfigController *configController);

@property (nonatomic, copy) void (^onLoad)(ConfigController *configController);

- (void)addView: (UIView*)view;

- (void)addGap: (CGFloat)gapHeight;
- (void)addFlexibleGap;

- (UIView*)addSeparator;

- (UITextView*)addText: (NSString*)text font: (UIFont*)font;
- (UITextView*)addText: (NSString*)text fontSize: (CGFloat)fontSize;
- (UITextView*)addHeadingText: (NSString*)text;
- (UITextView*)addText: (NSString*)text;
- (UITextView*)addNoteText: (NSString*)text;
- (UITextView*)addMarkdown: (NSString*)markdown fontSize: (CGFloat)fontSize;

- (void)addIcons: (NSArray<IconView*>*)icons;


- (UIButton*)addButton: (NSString*)text action: (void (^)(UIButton*))action;

- (ConfigToggle*)addToggle: (NSString*)title;

- (ConfigLabel*)addLabelTitle: (NSString*)title;

- (ConfigTextField*)addTextFieldTitle: (NSString*)title;
- (ConfigTextField*)addTextFieldTitle: (NSString*)title options: (NSUInteger)options;
- (ConfigTextField*)addPasswordTitle: (NSString*)title;

@end
