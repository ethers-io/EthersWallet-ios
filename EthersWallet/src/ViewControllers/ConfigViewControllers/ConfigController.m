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

#import "ConfigController.h"

#import "BlockButton.h"
#import "ConfigView.h"
#import "ConfigTextField.h"
#import "UIColor+hex.h"
#import "FlexibleView.h"
#import "Utilities.h"


static NSRange rangeForMarkdown(NSString *text, NSString *pattern) {
    NSRange startRange = [text rangeOfString:pattern];
    if (startRange.location == NSNotFound) { return startRange; }
    
    NSUInteger startIndex = startRange.location + startRange.length;
    NSRange endRange = [text rangeOfString:pattern options:0 range:NSMakeRange(startIndex, text.length - startIndex)];
    
    if (endRange.location == NSNotFound) { return endRange; }
    
    return NSMakeRange(startRange.location, endRange.location + endRange.length - startRange.location);
}


#pragma mark -
#pragma mark - ConfigView private access to the title label

@interface ConfigView (private)

@property (nonatomic, readonly) UILabel *titleLabel;

@end


#pragma mark -
#pragma mark - ButtonFriendlyScrollView

// http://stackoverflow.com/questions/3642547/uibutton-touch-is-delayed-when-in-uiscrollview#3643087
@interface ButtonFriendlyScrollView2: UIScrollView
@end

@implementation ButtonFriendlyScrollView2

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.delaysContentTouches = NO;
    }
    return self;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ([view isKindOfClass:UIButton.class]) {
        return YES;
    }
    
    return [super touchesShouldCancelInContentView:view];
}

@end


#pragma mark - ConfigController

@interface ConfigController () <UIScrollViewDelegate>

@property (nonatomic, readonly) UIScrollView *scrollView;

@end


@implementation ConfigController {
    UIButton *_nextButton;

    FlexibleView *_views;
    NSMutableArray *_configViews;
}

- (instancetype)init {
    return [super initWithNibName:nil bundle:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    self.navigationItem.titleView = [Utilities navigationBarTitleWithString:title];
}

- (void)setStep:(NSUInteger)step totalSteps: (NSUInteger)totalSteps {
    _step = step;
    _totalSteps = totalSteps;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 120.0f, 44.0f)];
    label.font = [UIFont fontWithName:FONT_BOLD size:12.0f];
    label.text = [NSString stringWithFormat:@"Step %d of %d", (int)step, (int)totalSteps];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
    
    self.navigationItem.titleView = label;
}


#pragma mark - Views and gaps

- (void)addView: (UIView*)view {
    if ([view isKindOfClass:[ConfigView class]]) {
        [[self configViews] addObject:view];
    }
    [_views addSubview:view];
}

- (NSMutableArray*)configViews {
    if (!_configViews) { _configViews = [NSMutableArray arrayWithCapacity:4]; }
    return _configViews;
}

- (void)addGap: (CGFloat)height {
    [_views addSubview:[[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 1.0f, height)]];
}

- (void)addFlexibleGap {
    [_views addFlexibleGap];
}

- (UIView*)addSeparator {
    // Some devices are 3 pixels per point, some 2 per point, so target 1 pixel tall
    // with a slightly brighter line when thinner.
    
    CGFloat scale = [UIScreen mainScreen].scale;
    
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0, 320.0f, 1.0f / scale)];
    separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.6f + scale * 0.05f];
    [_views addSubview:separator];
    return separator;
}


- (void)addIcons:(NSArray<IconView *> *)icons {
    
    if ([icons count] == 0) { return; }

    // @TODO: Don't get width this way...
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    
    const float padding =15.0f;

    CGFloat iconHeight = [icons firstObject].frame.size.height;

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(padding, 0.0f, width - 2.0f * padding, iconHeight)];
    
    CGFloat dw = view.frame.size.width / ([icons count] + 1);
    
    for (NSUInteger index = 0; index < [icons count]; index++) {
        UIView *subview = [icons objectAtIndex:index];
        subview.center = CGPointMake((float)(1 + index) * dw, iconHeight / 2.0f);
        [view addSubview:subview];
    }
    
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, view.frame.size.height)];
    [container addSubview:view];
    
    [_views addSubview:container];
}

#pragma mark - Text

- (UITextView*)addAttributedText: (NSAttributedString*)attributedText padding: (CGFloat)padding {
    // @TODO: Don't get width this way...
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGRect frame = CGRectMake(padding, 0, width - 2.0f * padding, 1.0f);
    
    UITextView *textView = [[UITextView alloc] initWithFrame:frame];
    textView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    textView.backgroundColor = [UIColor clearColor];
    textView.contentInset = UIEdgeInsetsZero;
    textView.scrollEnabled = NO;
    textView.attributedText = attributedText;
    textView.textAlignment = NSTextAlignmentCenter;
    textView.textColor = [UIColor whiteColor];
    textView.userInteractionEnabled = NO;
    
    CGSize requiredSize = [textView sizeThatFits:textView.frame.size];
    
    frame.size.height = requiredSize.height;
    textView.frame = frame;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, textView.frame.size.height)];
    [container addSubview:textView];
    
    [_views addSubview:container];

    return textView;
}

- (UITextView*)addAttributedText: (NSAttributedString*)attributedText {
    return [self addAttributedText:attributedText padding:15.0f];
}

- (UITextView*)addText: (NSString*)text font: (UIFont*)font {
    if (!text) { text = @""; }
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:text];
    [attributedText setAttributes:@{NSFontAttributeName: font}
                            range:NSMakeRange(0, text.length)];
    
    return [self addAttributedText:attributedText];
}

- (UITextView*)addText: (NSString*)text fontSize: (CGFloat)fontSize {
    return [self addText:text font:[UIFont fontWithName:FONT_NORMAL size:fontSize]];
}

- (UITextView*)addHeadingText: (NSString*)text {
    return [self addText:text fontSize:25.0f];
}

- (UITextView*)addText: (NSString*)text {
    return [self addText:text fontSize:15.0f];
}

- (UITextView*)addNoteText: (NSString*)text {
    return [self addText:text fontSize:12.0f];
}

- (UITextView*)addMarkdown: (NSString*)markdown fontSize: (CGFloat)fontSize {
    if (!markdown) { markdown = @""; }
    
    CGFloat padding = 15.0f;
    if ([markdown hasPrefix:@">"]) {
        padding = 50.0f;
        markdown = [markdown substringFromIndex:1];
    }
    
    NSMutableArray *regions = [NSMutableArray arrayWithCapacity:8];
    
    NSDictionary *attributesBold = @{
                                     NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:fontSize],
                                     NSForegroundColorAttributeName: [UIColor whiteColor],
                                     };
    
    NSDictionary *attributesItalic = @{
                                       NSFontAttributeName: [UIFont fontWithName:FONT_ITALIC size:fontSize],
                                       };
    
    while (YES) {
        NSRange rangeBold = rangeForMarkdown(markdown, @"**");
        NSRange rangeItalic = rangeForMarkdown(markdown, @"//");
        
        NSDictionary *attributes = nil;
        
        NSRange range;
        
        if (rangeBold.location != NSNotFound) {
            range = rangeBold;
            attributes = attributesBold;
        }
        
        if (rangeItalic.location != NSNotFound) {
            if (rangeBold.location == NSNotFound || rangeItalic.location < rangeBold.location) {
                range = rangeItalic;
                attributes = attributesItalic;
            }
        }
        
        if (!attributes) { break; }
        
        [regions addObject:@{
                             @"range": [NSValue valueWithRange:NSMakeRange(range.location, range.length - 4)],
                             @"attributes": attributes,
                             }];
        markdown = [markdown stringByReplacingCharactersInRange:range
                                                     withString:[markdown substringWithRange:NSMakeRange(range.location + 2, range.length - 4)]];
    }
    
    NSDictionary *baseAttributes = @{
                                     NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:fontSize],
                                     NSForegroundColorAttributeName: [UIColor colorWithWhite:0.93f alpha:1.0f],
                                     };
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:markdown attributes:baseAttributes];
    for (NSDictionary *region in regions) {
        [attributedText setAttributes:[region objectForKey:@"attributes"]
                                range:[[region objectForKey:@"range"] rangeValue]];
    }
    
    return [self addAttributedText:attributedText padding:padding];
}

- (ConfigLabel*)addLabelTitle:(NSString *)title {
    ConfigLabel *label = [[ConfigLabel alloc] initWithTitle:title];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addView:label];
    return label;
}


#pragma mark - Interactive

- (UIButton*)addButton: (NSString*)text action: (void (^)(UIButton*))action {
    BlockButton *button = [BlockButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    button.frame = CGRectMake(0.0f, 0, 320.0f, 60.0f);
    button.titleLabel.font = [UIFont fontWithName:FONT_NORMAL size:20.0f];
    [button handleControlEvent:UIControlEventTouchUpInside withBlock:action];
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithHex:0x98beef] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithHex:0x98beef alpha:0.5f] forState:UIControlStateHighlighted];
    [button setTitleColor:[UIColor colorWithHex:0x98beef alpha:0.3f] forState:UIControlStateDisabled];
    [_views addSubview:button];
    
    return button;
}

- (ConfigToggle*)addToggle: (NSString*)title {
    ConfigToggle *toggle = [[ConfigToggle alloc] initWithTitle:title];
    toggle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addView:toggle];
    
    return toggle;
}

- (ConfigTextField*)addTextFieldTitle: (NSString*)title {
    return [self addTextFieldTitle:title options:ConfigTextFieldOptionNone];
}

- (ConfigTextField*)addTextFieldTitle: (NSString*)title options: (NSUInteger)options {
    ConfigTextField *textField = [[ConfigTextField alloc] initWithTitle:title options:options];
    textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addView:textField];
    
    textField.textField.returnKeyType = UIReturnKeyNext;
    textField.textField.textColor = [UIColor whiteColor];
    textField.textField.tintColor = [UIColor colorWithWhite:1.0f alpha:0.8];
    
    return textField;
}

- (ConfigTextField*)addPasswordTitle: (NSString*)title {
    ConfigTextField *textField = [self addTextFieldTitle:title];

    textField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.textField.secureTextEntry = YES;

    return textField;
}


#pragma mark - Next Title

- (void)setNextTitle:(NSString *)nextTitle {
    _nextButton = nil;
    
    if (nextTitle) {
        UIBarButtonItemStyle style = UIBarButtonItemStylePlain;
        if ([nextTitle isEqualToString:@"Done"] || [nextTitle isEqualToString:@"Delete"]) {
            style = UIBarButtonItemStyleDone;
        }
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:nextTitle
                                                                                  style:style
                                                                                 target:self
                                                                                 action:@selector(tapNext)];
        self.navigationItem.rightBarButtonItem.enabled = _nextEnabled;
        
        if ([nextTitle isEqualToString:@"Delete"]) {
            self.navigationItem.rightBarButtonItem.tintColor = [UIColor redColor];
        }
        
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

/*
- (void)setNextIcon:(NSString *)nextIcon action:(void (^)())action {
    _nextAction = action;
    
    if (nextIcon) {
        _nextButton = [Utilities ethersButton:nextIcon fontSize:30.0f color:ColorHexToolbarIcon];
        [_nextButton addTarget:self action:@selector(tapNext) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_nextButton];
        
        _nextButton.enabled = _nextEnabled;
        
    } else {
        _nextButton = nil;
        self.navigationItem.rightBarButtonItem = nil;
    }
}
*/

- (void)setNextEnabled:(BOOL)nextEnabled {
    _nextEnabled = nextEnabled;
    if (_nextButton) {
        // Using a button (i.e. icon)
        _nextButton.enabled = nextEnabled;
    } else {
        // Using a navigation button
        self.navigationItem.rightBarButtonItem.enabled = nextEnabled;
    }
}

- (void)tapNext {
    if (_onNext) { _onNext(self); }
}


#pragma mark - View Lfie-Cycle

- (void)loadView {
    [super loadView];
    
    _scrollView = [[ButtonFriendlyScrollView2 alloc] initWithFrame:self.view.bounds];
    _scrollView.delegate = self;
    [self.view addSubview:_scrollView];
    
    _views = [[FlexibleView alloc] initWithFrame:self.view.bounds];
    [_scrollView addSubview:_views];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(noticeWillShowKeyboard:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(noticeWillHideKeyboard:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (_onLoad) { _onLoad(self); }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    float topMargin = self.view.safeAreaInsets.top - 44.0f;
    float bottomMargin = self.view.safeAreaInsets.top;
    _views.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height - topMargin - bottomMargin);
    _scrollView.contentSize = _views.frame.size;

    if (!_configViews) { return; }
    
    CGFloat maximumX = 0;
    for (ConfigView *configView in _configViews) {
        CGFloat x = configView.titleLabel.frame.origin.x + configView.titleLabel.frame.size.width;
        if (x > maximumX) { maximumX = x; }
    }
    
    for (ConfigView *configView in _configViews) {
        CGRect frame =  configView.contentView.frame;
        frame.origin.x = maximumX;
        frame.size.width = self.view.frame.size.width - maximumX;
        configView.contentView.frame = frame;
    }
}


#pragma mark - UIScrollView

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.view endEditing:YES];
}


#pragma mark - Keyboard notifications

- (void)noticeWillShowKeyboard: (NSNotification*)note {
    CGRect newFrame = [[note.userInfo objectForKey:@"UIKeyboardFrameEndUserInfoKey"] CGRectValue];
    NSTimeInterval duration = [[note.userInfo objectForKey:@"UIKeyboardAnimationDurationUserInfoKey"] doubleValue];

    void (^animations)() = ^() {
        _scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, self.view.frame.size.height - newFrame.origin.y, 0.0f);
        _scrollView.scrollIndicatorInsets = _scrollView.contentInset;
        //            [_scrollView setNeedsDisplay];
    };
    
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:animations
                     completion:nil];
}

- (void)noticeWillHideKeyboard: (NSNotification*)note {
    CGRect newFrame = [[note.userInfo objectForKey:@"UIKeyboardFrameEndUserInfoKey"] CGRectValue];
    NSTimeInterval duration = [[note.userInfo objectForKey:@"UIKeyboardAnimationDurationUserInfoKey"] doubleValue];
    
    void (^animations)() = ^() {
        _scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, self.view.frame.size.height - newFrame.origin.y, 0.0f);
        _scrollView.scrollIndicatorInsets = _scrollView.contentInset;
    };
    
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:animations
                     completion:nil];
}

@end
