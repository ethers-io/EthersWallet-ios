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

#import "MnemonicPhraseView.h"

typedef enum BlockTextFieldStatus {
    BlockTextFieldStatusNone = 0,
    BlockTextFieldStatusGood,
    BlockTextFieldStatusBad,
    BlockTextFieldStatusSpinning
} BlockTextFieldStatus;

@interface BlockTextField: UITextField

@property (nonatomic, copy) BOOL (^shouldChangeText)(BlockTextField*, NSRange, NSString*);
@property (nonatomic, copy) void (^didChangeText)(BlockTextField*);
@property (nonatomic, copy) void (^didBeginEditing)(BlockTextField*);
@property (nonatomic, copy) void (^didEndEditing)(BlockTextField*);

@property (nonatomic, copy) BOOL (^shouldReturn)(BlockTextField*);

@property (nonatomic, assign) BlockTextFieldStatus status;
- (void)setStatus:(BlockTextFieldStatus)status animated: (BOOL)animated;

- (void)pulse;

@end


@interface BlockMnemonicPhraseView : MnemonicPhraseView

@property (nonatomic, copy) void (^didChangeMnemonic)(BlockMnemonicPhraseView*);

@end


@interface InfoIconView : UIView

+ (instancetype)infoIconViewWithIcon: (NSString*)icon topTitle: (NSString*)topTitle bottomTitle: (NSString*)bottomTitle;

@property (nonatomic, copy) NSString *topTitle;
@property (nonatomic, copy) NSString *bottomTitle;

@property (nonatomic, copy) NSString *icon;

@end


@class InfoViewController;


@interface InfoNavigationController : UINavigationController

// Set this when the first view controller in the workflow has been added. It will be updated to step 1.
@property (nonatomic, assign) NSUInteger totalSteps;

@property (nonatomic, readonly) InfoViewController *rootInfoViewController;

- (void)dismissWithNil;
- (void)dismissWithResult: (NSObject*)result;

@end


@interface InfoViewController : UIViewController

+ (InfoNavigationController*)rootInfoViewControllerWithCompletionCallback: (void (^)(NSObject*))completionCallback;

@property (nonatomic, readonly) NSUInteger step;

@property (nonatomic, copy) void (^setupView)(InfoViewController*);

- (void)setNextTitle: (NSString*)nextTitle action: (void (^)())action;
- (void)setNextIcon:(NSString*)nextIcon action:(void (^)())action;
@property (nonatomic, assign) BOOL nextEnabled;

- (void)addGap: (CGFloat)height;
- (void)addFlexibleGap;

- (UIView*)addSeparator: (CGFloat)weight;

- (UITextView*)addMarkdown: (NSString*)html fontSize: (CGFloat)fontSize;
- (UITextView*)addAttributedText: (NSAttributedString*)attributedText;
- (UITextView*)addText: (NSString*)text font: (UIFont*)font;
- (UITextView*)addText: (NSString*)text fontSize: (CGFloat)fontSize;

- (UILabel*)addLabel: (NSString*)header value: (NSString*)value;

- (BlockMnemonicPhraseView*)addMnemonicPhraseView;

- (void)addView: (UIView*)view;
- (void)addViews: (NSArray<UIView*>*)views;

- (UITextView*)addHeadingText: (NSString*)text;
- (UITextView*)addText: (NSString*)text;
- (UITextView*)addNoteText: (NSString*)text;

- (UISwitch*)addToggle: (NSString*)title callback: (void (^)(BOOL))callback;

- (UIButton*)addButton: (NSString*)text action: (void (^)())action;
- (BlockTextField*)addTextEntry: (NSString*)title callback: (void (^)(BlockTextField*))callback;
- (BlockTextField*)addPasswordEntryCallback: (void (^)(BlockTextField*))callback;

- (NSUInteger)textFieldCount;
- (BlockTextField*)textFieldAtIndex: (NSUInteger)index;

@end
