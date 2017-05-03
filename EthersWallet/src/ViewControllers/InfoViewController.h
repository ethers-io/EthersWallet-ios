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

#import <ethers/Account.h>
#import <ethers/BigNumber.h>
#import "MnemonicPhraseView.h"


@interface InfoView : UIView

@property (nonatomic, readonly) NSString *title;

- (void)pulse;

@end



@interface InfoTextField: InfoView

@property (nonatomic, readonly) UITextField *textField;

- (void)setEther: (BigNumber*)ether;

- (UIButton*)setButton: (NSString*)title callback: (void (^)(UIButton*))callback;

@end

/*
@interface InfoOptionsView : InfoView

@property (nonatomic, readonly) NSInteger selectedIndex;

- (UILabel*)addOptionCallback: (void (^)(InfoOptionsView*, UILabel*))callback;

@end
*/

@interface InfoMnemonicPhraseView : MnemonicPhraseView

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

- (UIView*)addSeparator;

- (UITextView*)addMarkdown: (NSString*)html fontSize: (CGFloat)fontSize;
- (UITextView*)addAttributedText: (NSAttributedString*)attributedText;
- (UITextView*)addText: (NSString*)text font: (UIFont*)font;
- (UITextView*)addText: (NSString*)text fontSize: (CGFloat)fontSize;

- (UILabel*)addLabel: (NSString*)header value: (NSString*)value;

- (void)addView: (UIView*)view;
- (void)addViews: (NSArray<UIView*>*)views;

- (UITextView*)addHeadingText: (NSString*)text;
- (UITextView*)addText: (NSString*)text;
- (UITextView*)addNoteText: (NSString*)text;

- (UISwitch*)addToggle: (NSString*)title callback: (void (^)(BOOL))callback;

//- (InfoOptionsView*)addOptionsView: (NSString*)title didChange: (void (^)(InfoOptionsView*))didchange;

- (InfoMnemonicPhraseView*)addMnemonicPhraseView: (NSString*)mnemonic didChange:(void (^)(InfoMnemonicPhraseView*))didChange;

- (UIButton*)addButton: (NSString*)text action: (void (^)(UIButton*))action;

- (InfoTextField*)addTextEntry: (NSString*)title callback: (void (^)(InfoTextField*))callback;
- (InfoTextField*)addPasswordAccount: (NSString*)json verified: (void (^)(InfoTextField*, Account*))verified;
- (InfoTextField*)addPasswordEntryDidChange: (BOOL (^)(InfoTextField*))didChange didReturn: (void (^)(InfoTextField*))didReturn;
- (InfoTextField*)addEtherEntry: (NSString*)title value: (BigNumber*)value didChange: (void (^)(InfoTextField*, BigNumber*))didChange;

+ (void)setEtherPrice: (float)etherPrice;

@end
