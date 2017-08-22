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

#import "InfoViewController.h"

#import <ethers/Payment.h>
#import <ethers/SecureData.h>

#import "BlockButton.h"
#import "UIColor+hex.h"
#import "Utilities.h"


#pragma mark - AnimationTransition

NSRange rangeForMarkdown(NSString *text, NSString *pattern) {
    NSRange startRange = [text rangeOfString:pattern];
    if (startRange.location == NSNotFound) { return startRange; }
    
    NSUInteger startIndex = startRange.location + startRange.length;
    NSRange endRange = [text rangeOfString:pattern options:0 range:NSMakeRange(startIndex, text.length - startIndex)];

    if (endRange.location == NSNotFound) { return endRange; }

    return NSMakeRange(startRange.location, endRange.location + endRange.length - startRange.location);
}

// This provides a nice transition for View Controllers which have transparent backgrounds

@interface AnimatedTransition2 : NSObject <UIViewControllerAnimatedTransitioning> {
    UINavigationControllerOperation _operation;
    CGFloat _width;
}
@end


@implementation AnimatedTransition2

- (instancetype)initWithOperation: (UINavigationControllerOperation)operation width: (CGFloat)width {
    self = [super init];
    if (self) {
        _operation = operation;
        _width = width;
    }
    return self;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    BOOL push = (_operation == UINavigationControllerOperationPush);
    
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    
    fromViewController.view.alpha = 1.0f;
    fromViewController.view.transform = CGAffineTransformIdentity;
    fromViewController.view.userInteractionEnabled = NO;
    
    toViewController.view.alpha = 0.0f;
    toViewController.view.transform = CGAffineTransformMakeTranslation((push ? _width: -_width / 3.0f), 0.0f);
    toViewController.view.userInteractionEnabled = NO;
    
    [transitionContext.containerView addSubview:toViewController.view];
    
    void (^animations)() = ^() {
        fromViewController.view.alpha = 0.0f;
        fromViewController.view.transform = CGAffineTransformMakeTranslation((push ? -_width / 3.0f: _width), 0.0f);
        
        toViewController.view.alpha = 1.0f;
        toViewController.view.transform = CGAffineTransformIdentity;
    };
    
    void (^animationsComplete)(BOOL) = ^(BOOL complete) {
        toViewController.view.userInteractionEnabled = YES;
        [transitionContext completeTransition:YES];
    };
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:animations
                     completion:animationsComplete];
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.3f;
}

@end



#pragma mark -
#pragma mark - ButtonFriendlyScrollView

// http://stackoverflow.com/questions/3642547/uibutton-touch-is-delayed-when-in-uiscrollview#3643087
@interface ButtonFriendlyScrollView: UIScrollView
@end

@implementation ButtonFriendlyScrollView

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



#pragma mark -
#pragma mark - BlockSwitch

@interface BlockSwitch: UISwitch {
    void (^_action)();
    UIImpactFeedbackGenerator *_feedbackGenerator;
    
}

@end


@implementation BlockSwitch

- (void)handleControlEvent:(UIControlEvents)event withBlock: (void (^)(BlockSwitch*))action {
    if (!_action) {
        [self addTarget:self action:@selector(callAction:) forControlEvents:event];
    }
    
    if (!_feedbackGenerator) {
        _feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    _action = action;
}

- (void)callAction: (id)sender{
    if (_action) { _action(self); }
}

- (void)toggleOn {
    if (self.enabled) {
        [self setOn:!self.on animated:YES];
        [_feedbackGenerator impactOccurred];
    }
}

@end

/*
#pragma mark -
#pragma mark - BlockButton

// http://stackoverflow.com/questions/3908003/uibutton-block-equivalent-to-addtargetactionforcontrolevents-method#3977305
@interface BlockButton : UIButton {
    void (^_action)(UIButton*);
}

@end

@implementation BlockButton

- (void)handleControlEvent:(UIControlEvents)event withBlock: (void (^)())action {
    if (!_action) {
        [self addTarget:self action:@selector(callAction:) forControlEvents:event];
    }
    _action = action;
}

- (void)callAction: (id)sender{
    if (_action) { _action(self); }
}

@end
*/

#pragma mark -
#pragma mark - BlockTextField


typedef enum InfoTextFieldStatus {
    InfoTextFieldStatusNone = 0,
    InfoTextFieldStatusGood,
    InfoTextFieldStatusBad,
    InfoTextFieldStatusSpinning
} InfoTextFieldStatus;


@interface BlockTextField : UITextField <UITextFieldDelegate> {
    UIActivityIndicatorView *_spinner;
    UILabel *_statusLabel;
}

@property (nonatomic, copy) void (^completeCallback)(BlockTextField*);

@property (nonatomic, copy) BOOL (^shouldChangeText)(BlockTextField*, NSRange, NSString*);
@property (nonatomic, copy) void (^didChangeText)(BlockTextField*);
@property (nonatomic, copy) void (^didBeginEditing)(BlockTextField*);
@property (nonatomic, copy) void (^didEndEditing)(BlockTextField*);

@property (nonatomic, copy) BOOL (^shouldReturn)(BlockTextField*);

@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, assign) InfoTextFieldStatus status;

@end


@implementation BlockTextField

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = self;
        float width = frame.size.height;
        
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _spinner.bounds = CGRectMake(0.0f, 0.0f, width, width);
        _spinner.center = CGPointMake(frame.size.width - 10.0f, width / 2.0f);
        _spinner.color = [UIColor whiteColor];
        _spinner.transform = CGAffineTransformMakeScale(0.75f, 0.75f);
        [self addSubview:_spinner];
        
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width - 20.0f, 0.0f, 20.0f, frame.size.height)];
        _statusLabel.alpha = 0.0f;
        _statusLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
        _statusLabel.font = [UIFont fontWithName:FONT_ETHERS size:16.0f];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.textColor = [UIColor colorWithHex:ColorHexLightRed];
        _statusLabel.text = @"X";
        [self addSubview:_statusLabel];
        
        [self addTarget:self action:@selector(textEditingChanged) forControlEvents:UIControlEventEditingChanged];
    }
    return self;
}

- (void)setPlaceholder:(NSString *)placeholder {
    [super setPlaceholder:placeholder];
    
    NSDictionary *placeholderAttributes = @{
                                            NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:17.0f],
                                            NSForegroundColorAttributeName: [UIColor colorWithWhite:0.9f alpha:1.0f]
                                            };
    NSMutableAttributedString *attributedPlaceholder = [[NSMutableAttributedString alloc] initWithString:placeholder
                                                                                              attributes:placeholderAttributes];
    
    self.attributedPlaceholder = attributedPlaceholder;
}

- (void)setStatus:(InfoTextFieldStatus)status {
    [self setStatus:status animated:NO];
}

- (void)setStatus:(InfoTextFieldStatus)status animated: (BOOL)animated {
    _status = status;
    
    if (status == InfoTextFieldStatusSpinning) {
        [_spinner startAnimating];
        _statusLabel.alpha = 0.0f;

    } else {
        [_spinner stopAnimating];
        
        if (status == InfoTextFieldStatusNone) {
            _statusLabel.alpha = 0.0f;
        
        } else {
            
            if (status == InfoTextFieldStatusGood) {
                _statusLabel.text = @"C";
                _statusLabel.textColor = [UIColor colorWithHex:ColorHexLightGreen];

            } else if (status == InfoTextFieldStatusBad) {
                _statusLabel.text = @"X";
                _statusLabel.textColor = [UIColor colorWithHex:ColorHexLightRed];
            }

            void (^animate)() = ^() {
                _statusLabel.transform = CGAffineTransformIdentity;
                _statusLabel.alpha = 1.0f;
            };

            if (animated) {
                _statusLabel.alpha = 0.0f;
                _statusLabel.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
                
                [UIView animateWithDuration:1.3f
                                      delay:0.0f
                     usingSpringWithDamping:0.4f
                      initialSpringVelocity:0.0f
                                    options:UIViewAnimationOptionBeginFromCurrentState
                                 animations:animate
                                 completion:nil];
            
            } else {
                animate();
            }
        
        }
    }
    

}

- (void)pulse {
    void (^animate)() = ^() {
        _titleLabel.transform = CGAffineTransformIdentity;
    };
    
    _titleLabel.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
    
    [UIView animateWithDuration:1.3f
                          delay:0.0f
         usingSpringWithDamping:0.4f
          initialSpringVelocity:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:animate
                     completion:nil];

}

- (void)textEditingChanged {
    if (_didChangeText) {
        _didChangeText(self);
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    BOOL shouldReturn = YES;
    if (_shouldReturn) {
        shouldReturn = _shouldReturn(self);
    }
    
    if (shouldReturn && _completeCallback) {
        _completeCallback(self);
    }
    
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (_didBeginEditing) {
        _didBeginEditing(self);
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (_didEndEditing) {
        _didEndEditing(self);
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (_shouldChangeText) {
        return _shouldChangeText(self, range, string);
    }
    return YES;
}

@end

#pragma mark -
#pragma mark - BlockPickerView
/*
@interface InfoOptionsView ()

@property (nonatomic, copy) void (^callback)(InfoOptionsView*, UILabel*);

@end

@implementation BlockPickerLabel

@end


@interface BlockPickerView () <UIPickerViewDelegate> {
    UIView *_pickerView;
    NSMutableArray *_options;
    UIView *_inputView;
}

@end

@implementation BlockPickerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _selectedIndex = -1;
        _options = [NSMutableArray array];
        
        _inputView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 100.0f)];
        _inputView.backgroundColor = [UIColor redColor];
        
        self.userInteractionEnabled = YES;
    }
    return self;
}

- (UIView*)inputView {
    return _inputView;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}


- (UILabel*)addOptionCallback: (void (^)(BlockPickerView*, UILabel*))callback {
    BlockPickerLabel *label = [[BlockPickerLabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 44.0f)];
    label.callback = callback;
    return label;
}

@end
*/
#pragma mark -
#pragma mark - BlockMnemonicPhraseView

@interface InfoMnemonicPhraseView () <MnemonicPhraseViewDelegate> {

}

@property (nonatomic, copy) void (^didChangeMnemonic)(InfoMnemonicPhraseView*);

@end

@implementation InfoMnemonicPhraseView

- (instancetype)initWithFrame:(CGRect)frame withPhrase:(NSString *)phrase {
    self = [super initWithFrame:frame withPhrase:phrase];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (void)mnemonicPhraseViewDidChange:(MnemonicPhraseView *)mnemonicPhraseView {
    if (_didChangeMnemonic) {
        _didChangeMnemonic(self);
    }
}

@end


#pragma mark -
#pragma mark - InfoView

@interface InfoView ()

@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, readonly) UILabel *titleLabel;

@end


@implementation InfoView

- (instancetype)initWithTitle: (NSString*)title {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
    if (self){
        
        UIFont *labelFont = [UIFont fontWithName:FONT_BOLD size:17.0f];;
        
        CGSize labelSize = [title boundingRectWithSize:self.frame.size
                                               options:NSStringDrawingUsesFontLeading
                                            attributes:@{ NSFontAttributeName: labelFont }
                                               context:nil].size;
        
        // Bold font isn't lined up with non-bold font...
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 0.0f, labelSize.width + 24.0f, 47.0f)];
        _titleLabel.font = labelFont;
        _titleLabel.text = title;
        _titleLabel.textColor = [UIColor whiteColor];
        [self addSubview:_titleLabel];

        _contentView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
        [self addSubview:_contentView];
    }
    
    return self;
}

- (void)layoutMaxTitleWidth: (CGFloat)width {
    CGRect frame = _contentView.frame;
    frame.origin.x = width;
    frame.size.width = self.frame.size.width - width - 15.0f;
    _contentView.frame = frame;
}

- (void)pulse {
    void (^animate)() = ^() {
        _titleLabel.transform = CGAffineTransformIdentity;
    };
    
    _titleLabel.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
    
    [UIView animateWithDuration:1.3f
                          delay:0.0f
         usingSpringWithDamping:0.4f
          initialSpringVelocity:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:animate
                     completion:nil];
    
}

- (NSString*)title {
    return _titleLabel.text;
}

@end

#pragma mark -
#pragma mark - InfoTextField

@interface InfoTextField () {
    BlockButton *_button;
}

@property (nonatomic, strong) BlockTextField *blockTextField;

@end

@implementation InfoTextField

- (instancetype)initWithTitle: (NSString*)title completeCallback: (void (^)())completeCallback {
    self = [super initWithTitle:title];
    if (self) {
        _blockTextField = [[BlockTextField alloc] initWithFrame:self.frame];
        _blockTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_blockTextField];
        
        __weak InfoTextField *weakSelf = self;
        _blockTextField.completeCallback = ^(BlockTextField *textField) {
            if (completeCallback) {
                completeCallback(weakSelf);
            }
        };
        
        _textField = _blockTextField;
    }
    return self;
}

- (InfoTextFieldStatus)status {
    return _blockTextField.status;
}

- (void)setStatus:(InfoTextFieldStatus)status animated: (BOOL)animated {
    [_blockTextField setStatus:status animated:animated];
}

- (void)setEther:(BigNumber *)ether {
    
    // Set the initial value
    NSString *etherString = @"0.0";
    if (ether) { etherString = [Payment formatEther:ether]; }
    
    if ([[[NSLocale currentLocale] decimalSeparator] isEqualToString:@","]) {
        etherString = [etherString stringByReplacingOccurrencesOfString:@"." withString:@","];
    }
    
    if (self.textField.isFirstResponder) {
        self.textField.text = etherString;
    } else {
        self.textField.text = [@"Ξ\u2009" stringByAppendingString:etherString];
    }
}

- (UIButton*)setButton: (NSString*)title callback: (void (^)(UIButton*))callback {
    if (!_button) {
        _button = [BlockButton buttonWithType:UIButtonTypeCustom];
        [self addSubview:_button];
    }
    
    [_button handleControlEvent:UIControlEventTouchUpInside withBlock:callback];
    [_button setTitle:title forState:UIControlStateNormal];

    UIFont *font = [UIFont fontWithName:FONT_BOLD size:14.0f];
    
    CGSize labelSize = [title boundingRectWithSize:self.bounds.size
                                           options:NSStringDrawingUsesFontLeading
                                        attributes:@{ NSFontAttributeName:font }
                                           context:nil].size;

    _button.frame = CGRectMake(self.frame.size.width - labelSize.width - 20.0f, 0.0f, labelSize.width + 20, 50.0f);
    _button.titleLabel.textAlignment = NSTextAlignmentCenter;
    _button.titleLabel.font = font;
    [_button setTitleColor:[UIColor colorWithHex:0x88aedf] forState:UIControlStateNormal];
    [_button setTitleColor:[UIColor colorWithHex:0x88aedf alpha:0.5f] forState:UIControlStateHighlighted];
    [_button setTitleColor:[UIColor colorWithHex:0x88aedf alpha:0.3f] forState:UIControlStateDisabled];
    
    return _button;
}

@end

#pragma mark -
#pragma mark - InfoIconView

@interface InfoIconView () {
    UILabel *_topLabel, *_bottomLabel, *_iconLabel;
}

@end

@implementation InfoIconView

- (instancetype)initWithIcon: (NSString*)icon topTitle: (NSString*)topTitle bottomTitle: (NSString*)bottomTitle {
    CGRect frame = CGRectMake(0.0f, 0.0f, 80.0f, 80.0f);
    self = [super initWithFrame:frame];
    
    if (self) {
        _iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width - 20.0f, frame.size.width - 20.0f)];
        _iconLabel.center = CGPointMake(frame.size.width / 2.0f, frame.size.height / 2.0f);
        _iconLabel.font = [UIFont fontWithName:FONT_ETHERS size:36.0f];
        _iconLabel.layer.cornerRadius = _iconLabel.frame.size.width / 2.0f;
        _iconLabel.layer.borderColor = [UIColor colorWithWhite:0.85f alpha:1.0f].CGColor;
        _iconLabel.layer.borderWidth = 3.0f;
        _iconLabel.text = icon;
        _iconLabel.textAlignment = NSTextAlignmentCenter;
        _iconLabel.textColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
        [self addSubview:_iconLabel];
        
        _topLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, 13.0f)];
        _topLabel.font = [UIFont fontWithName:FONT_BOLD size:12.0f];
        _topLabel.shadowColor = [UIColor colorWithWhite:0.3 alpha:1.0f];
        _topLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _topLabel.text = topTitle;
        _topLabel.textAlignment = NSTextAlignmentCenter;
        _topLabel.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        [self addSubview:_topLabel];

        _bottomLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 13.0f, frame.size.width, 13.0f)];
        _bottomLabel.font = _topLabel.font;
        _bottomLabel.shadowColor = _topLabel.shadowColor;
        _bottomLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        _bottomLabel.text = bottomTitle;
        _bottomLabel.textAlignment = NSTextAlignmentCenter;
        _bottomLabel.textColor = _topLabel.textColor;
        [self addSubview:_bottomLabel];
    }
    
    return self;
}

+ (instancetype)infoIconViewWithIcon: (NSString*)icon topTitle: (NSString*)topTitle bottomTitle: (NSString*)bottomTitle {
    return [[InfoIconView alloc] initWithIcon:icon topTitle:topTitle bottomTitle:bottomTitle];
}

- (NSString*)topTitle {
    return _topLabel.text;
}

- (void)setTopTitle:(NSString *)topTitle {
    _topLabel.text = topTitle;
}

- (NSString*)bottomTitle {
    return _bottomLabel.text;
}

- (void)setBottomTitle:(NSString *)bottomTitle {
    _bottomLabel.text = bottomTitle;
}

@end


#pragma mark -
#pragma mark - InfoNavigationController

@interface InfoViewController (step)

@property (nonatomic, assign) NSUInteger step;

@end


@interface InfoNavigationController ()

@property (nonatomic, copy) void (^onDismiss)(NSObject *result);

@end


@implementation InfoNavigationController

- (instancetype)initWithRootInfoViewController:(InfoViewController*)rootInfoViewController {
    self = [super initWithRootViewController:rootInfoViewController];
    if (self) {
        _rootInfoViewController = rootInfoViewController;
    }
    return self;
}

- (void)setTotalSteps:(NSUInteger)totalSteps {
    _totalSteps = totalSteps;
    ((InfoViewController*)self.topViewController).step = 1; //((InfoViewController*)self.topViewController).step;
}

- (void)pushViewController:(InfoViewController *)viewController animated:(BOOL)animated {
    InfoViewController *topViewController = (InfoViewController*)(self.topViewController);

    [super pushViewController:viewController animated:animated];

    if (topViewController.step) {
        viewController.step = topViewController.step + 1;
    }
}

- (void)dismissWithNil {
    [self dismissWithResult:nil];
}

- (void)dismissWithResult:(NSObject *)result {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^() {
        if (_onDismiss) {
            _onDismiss(result);
        }
    }];
}

@end



#pragma mark -
#pragma mark - InfoViewController

@interface InfoViewController () <UINavigationControllerDelegate> {
    CGFloat _currentTop;
    NSUInteger _flexibleTag;
    
    //NSMutableArray <BlockTextField*> *_textFields;
    
    // We store all views that have a title, so we can align them after the view is setup
    //NSMutableArray <UIView*> *_titleViews;
    
    void (^_nextAction)();
    UIScrollView *_scrollView;
    NSUInteger _preparedStep, _preparedTotalSteps;
    UIButton *_nextButton;
}

@property (nonatomic, readonly) UIView *infoViews;

@property (nonatomic, assign) NSUInteger step;

@end


@implementation InfoViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        //_textFields = [NSMutableArray array];
        //_titleViews = [NSMutableArray array];
    }
    return self;
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    self.navigationItem.titleView = [Utilities navigationBarTitleWithString:title];
}

- (void)setStep:(NSUInteger)step {
    _step = step;
    if (_step == 0 && _preparedStep) {
        self.navigationItem.titleView = nil;
        _preparedStep = 0;
    }
    
    [self prepareStepLabel];
}

- (void)prepareStepLabel {
    int totalSteps = (int)((InfoNavigationController*)self.navigationController).totalSteps;

    if (_step == _preparedStep && totalSteps == _preparedTotalSteps) { return; }

    _preparedStep = _step;
    _preparedTotalSteps = totalSteps;
    
    if (_step == 0) { return; }
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 120.0f, 44.0f)];
    label.font = [UIFont fontWithName:FONT_BOLD size:12.0f];
    label.text = [NSString stringWithFormat:@"Step %d of %d", (int)_step, totalSteps];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
    
    self.navigationItem.titleView = label;
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    [super willMoveToParentViewController:parent];
    [self prepareStepLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self prepareStepLabel];
}


#pragma mark - Next Title

- (void)setNextTitle:(NSString *)nextTitle action:(void (^)())action {
    _nextButton = nil;
    
    _nextAction = action;
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

- (void)setNextEnabled:(BOOL)nextEnabled {
    _nextEnabled = nextEnabled;
    if (_nextButton) {
        _nextButton.enabled = nextEnabled;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = nextEnabled;
    }
}

- (void)tapNext {
    if (_nextAction) { _nextAction(); }
}


#pragma mark - View Life-Cycle

+ (InfoNavigationController*)rootInfoViewControllerWithCompletionCallback: (void (^)(NSObject*))completionCallback {
//+ (UINavigationController*)rootInfoViewController {
    InfoViewController *info = [[InfoViewController alloc] init];
    info.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                target:info
                                                                                                action:@selector(tapCancel)];
    
    InfoNavigationController *navigationController = [[InfoNavigationController alloc] initWithRootInfoViewController:info];
    navigationController.delegate = info;
    navigationController.navigationBar.barStyle = UIBarStyleBlack;
    navigationController.navigationBar.tintColor = [UIColor colorWithHex:0x5ca2fe];
    navigationController.onDismiss = completionCallback;
    
    // Add the background to the navigation
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    visualEffectView.frame = navigationController.view.bounds;
    visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [navigationController.view insertSubview:visualEffectView atIndex:0];
    
    return navigationController;
}

- (void)tapCancel {
    [(InfoNavigationController*)self.navigationController dismissWithResult:nil];
}

- (void)loadView {
    [super loadView];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    CGSize size = self.view.frame.size;
    
    _scrollView = [[ButtonFriendlyScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.contentInset = UIEdgeInsetsMake(64.0f, 0.0f, 0.0f, 0.0f);
    _scrollView.scrollIndicatorInsets = _scrollView.contentInset;
    [self.view addSubview:_scrollView];
    
    //[_scrollView setNeedsDisplay];
    
    _infoViews = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height - 64.0f)];
    [_scrollView addSubview:_infoViews];
    
    if (self.setupView) { self.setupView(self); }
    
    // Adjust views for flexible gaps (if everything fit on one screen)
    if (_flexibleTag && _currentTop < _infoViews.frame.size.height) {
        float remainingHeight = size.height - 64.0f - _currentTop;
        
        float deltaHeight = remainingHeight / (float)_flexibleTag;
        
        for (UIView *subview in _infoViews.subviews) {
            CGRect frame = subview.frame;
            frame.origin.y += subview.tag * deltaHeight;
            subview.frame = frame;
            
            CGFloat currentTop = frame.origin.y + frame.size.height;
            if (currentTop > _currentTop) { _currentTop = currentTop; }
        }
    }

    _scrollView.contentSize = CGSizeMake(size.width, _currentTop);
    _infoViews.frame = CGRectMake(0.0f, 0.0f, size.width, _currentTop);
    
    CGFloat maximumX = 0;
    for (InfoView *view in _infoViews.subviews) {
        if (![view isKindOfClass:[InfoView class]]) { continue; }
        CGFloat x = view.titleLabel.frame.origin.x + view.titleLabel.frame.size.width;
        if (x > maximumX) { maximumX = x; }
    }
    
    for (InfoView *view in _infoViews.subviews) {
        if ([view respondsToSelector:@selector(layoutMaxTitleWidth:)]) {
            [view layoutMaxTitleWidth:maximumX];
        }
        /*
        CGRect frame = view.frame;
        frame.origin.x = maximumX;
        frame.size.width = _infoViews.frame.size.width - maximumX - 15.0f;
        view.frame = frame;
         */
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(noticeWillShowKeyboard:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(noticeWillHideKeyboard:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
}

- (void)noticeWillShowKeyboard: (NSNotification*)note {
    CGRect newFrame = [[note.userInfo objectForKey:@"UIKeyboardFrameEndUserInfoKey"] CGRectValue];
    NSTimeInterval duration = [[note.userInfo objectForKey:@"UIKeyboardAnimationDurationUserInfoKey"] doubleValue];
    
    void (^animations)() = ^() {
        _scrollView.contentInset = UIEdgeInsetsMake(64.0f, 0.0f, self.view.frame.size.height - newFrame.origin.y, 0.0f);
        _scrollView.scrollIndicatorInsets = _scrollView.contentInset;
        //            [_scrollView setNeedsDisplay];
    };
    
    void (^complete)(BOOL) = ^(BOOL complete) {
        
    };
    
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:animations
                     completion:complete];
}

- (void)noticeWillHideKeyboard: (NSNotification*)note {
    CGRect newFrame = [[note.userInfo objectForKey:@"UIKeyboardFrameEndUserInfoKey"] CGRectValue];
    NSTimeInterval duration = [[note.userInfo objectForKey:@"UIKeyboardAnimationDurationUserInfoKey"] doubleValue];
    
    void (^animations)() = ^() {
        _scrollView.contentInset = UIEdgeInsetsMake(64.0f, 0.0f, self.view.frame.size.height - newFrame.origin.y, 0.0f);
        _scrollView.scrollIndicatorInsets = _scrollView.contentInset;
    };
    
    void (^complete)(BOOL) = ^(BOOL complete) {
        
    };
    
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:animations
                     completion:complete];
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    switch (operation) {
        case UINavigationControllerOperationPush:
        case UINavigationControllerOperationPop:
            return [[AnimatedTransition2 alloc] initWithOperation:operation width:self.view.frame.size.width];
        case UINavigationControllerOperationNone:
        default:
            break;
    }
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - Layout Adjustments

- (void)addGap: (CGFloat)height {
    [self addView:[[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 1.0f, height)]];
}

- (void)addFlexibleGap {
    _flexibleTag++;
}

- (UIView*)addSeparator {
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, _currentTop, self.view.frame.size.width, 0.5f)];
    separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7f];
    [self addView:separator];
    return separator;
}

- (void)addView: (UIView*)view {
    CGRect frame = view.frame;
    if ([view isKindOfClass:[InfoView class]]) {
        frame.size.width = self.view.frame.size.width;
        view.frame = frame;
    }
    view.center = CGPointMake(self.view.frame.size.width / 2.0f, _currentTop + frame.size.height / 2.0f);
    [self.infoViews addSubview:view];
    
    view.tag = _flexibleTag;
    
    _currentTop += frame.size.height;
}

- (void)addViews:(NSArray<UIView *> *)views {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 1.0f)];
    
    CGFloat originY = 0.0f;
    for (UIView *view in views) {
        CGFloat y = view.frame.size.height / 2.0f;
        if (y > originY) { originY = y; }
    }
    
    CGFloat dw = view.frame.size.width / ([views count] + 1);
    
    for (NSUInteger index = 0; index < [views count]; index++) {
        UIView *subview = [views objectAtIndex:index];
        subview.center = CGPointMake((float)(1 + index) * dw, originY);
        [view addSubview:subview];
    }
    
    view.frame = CGRectMake(15.0f, 0.0f, view.frame.size.width, 2.0f * originY);
    
    [self addView:view];
}


#pragma mark - Text

- (UITextView*)addAttributedText: (NSAttributedString*)attributedText padding: (CGFloat)padding {
    CGRect frame = CGRectMake(padding, _currentTop, self.view.frame.size.width - 2.0f * padding, 1.0f);
    
    UITextView *textView = [[UITextView alloc] initWithFrame:frame];
    textView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    textView.backgroundColor = [UIColor clearColor];
    textView.contentInset = UIEdgeInsetsZero;
    textView.scrollEnabled = NO;
    textView.attributedText = attributedText;
    textView.tag = _flexibleTag;
    textView.textAlignment = NSTextAlignmentCenter;
    textView.textColor = [UIColor whiteColor];
    textView.userInteractionEnabled = NO;
    [self.infoViews addSubview:textView];
    
    CGSize requiredSize = [textView sizeThatFits:frame.size];
    
    frame.size.height = requiredSize.height;
    textView.frame = frame;
    _currentTop += requiredSize.height;
    
    return textView;
}

- (UITextView*)addAttributedText: (NSAttributedString*)attributedText {
    return [self addAttributedText:attributedText padding:15.0f];
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

- (UITextView*)addText: (NSString*)text font: (UIFont*)font {
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

- (UILabel*)addLabel: (NSString*)title value: (NSString*)value {
    
    InfoView *infoView = [[InfoView alloc] initWithTitle:title];
    
    UILabel *valueLabel = [[UILabel alloc] initWithFrame:infoView.contentView.bounds];
    valueLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    valueLabel.text = value;
    valueLabel.textColor = [UIColor whiteColor];
    valueLabel.tintColor = [UIColor colorWithWhite:1.0f alpha:0.8];
    [infoView.contentView addSubview:valueLabel];
    
    [self addView:infoView];

    return valueLabel;
}



#pragma mark - Interactive

- (UISwitch*)addToggle: (NSString*)title callback: (void (^)(BOOL))callback {
    InfoView *infoView = [[InfoView alloc] initWithTitle:title];

    CGSize size = infoView.contentView.frame.size;

    BlockSwitch *toggle = [[BlockSwitch alloc] initWithFrame:CGRectZero];
    toggle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    toggle.center = CGPointMake(size.width - toggle.frame.size.width / 2.0f, infoView.contentView.frame.size.height / 2.0f);
    [toggle handleControlEvent:UIControlEventValueChanged withBlock:^(BlockSwitch *toggle) {
        if (callback) {
            callback(toggle.on);
        }
    }];
    [infoView.contentView addSubview:toggle];

    [infoView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:toggle action:@selector(toggleOn)]];
    
    [self addView:infoView];
    
    return toggle;
}

- (BlockButton*)addButton: (NSString*)text action: (void (^)(UIButton*))action {
    BlockButton *button = [BlockButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    button.frame = CGRectMake(0.0f, _currentTop, self.view.frame.size.width, 60.0f);
    button.titleLabel.font = [UIFont fontWithName:FONT_NORMAL size:20.0f];
    [button handleControlEvent:UIControlEventTouchUpInside withBlock:action];
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithHex:0x98beef] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithHex:0x98beef alpha:0.5f] forState:UIControlStateHighlighted];
    [button setTitleColor:[UIColor colorWithHex:0x98beef alpha:0.3f] forState:UIControlStateDisabled];
    [self addView:button];
    
    return button;
}

- (InfoTextField*)addTextEntry:(NSString *)title callback:(void (^)(InfoTextField *))callback {
    InfoTextField *infoTextField = [[InfoTextField alloc] initWithTitle:title completeCallback:callback];
    
    infoTextField.textField.returnKeyType = UIReturnKeyNext;
    infoTextField.textField.textColor = [UIColor whiteColor];
    infoTextField.textField.tintColor = [UIColor colorWithWhite:1.0f alpha:0.8];

    [self addView:infoTextField];
    /*
    [_textFields addObject:textField];
    [_titleViews addObject:textField];
     */
    
    return infoTextField;
}

- (InfoTextField*)addPasswordAccount: (NSString*)json verified: (void (^)(InfoTextField*, Account*))verified {
    InfoTextField *infoTextField = [self addTextEntry:@"Password" callback:nil];
    infoTextField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    infoTextField.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    infoTextField.textField.placeholder = @"Required";
    infoTextField.textField.secureTextEntry = YES;

    __weak InfoTextField *weakInfoTextField = infoTextField;

    __block Cancellable *cancellable = nil;
    
    infoTextField.blockTextField.didChangeText = ^(BlockTextField *textField) {
        if (cancellable) {
            [cancellable cancel];
            cancellable = nil;
        }
        
        NSString *password = textField.text;
        NSLog(@"PS: %@", password);
        
        if ([password isEqualToString:@""]) {
            textField.status = InfoTextFieldStatusNone;
        } else {
            [textField setStatus:InfoTextFieldStatusSpinning animated:YES];
        }
        
        // Start derivation...
        NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
        cancellable = [Account decryptSecretStorageJSON:json password:password callback:^(Account *account, NSError *error) {

            // We have an account, so the password was correct
            if (account) {
                NSLog(@"decrypted: %@ dt=%f", account.address, [NSDate timeIntervalSinceReferenceDate] - t0);
                
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [textField setStatus:InfoTextFieldStatusGood animated:YES];
                    textField.userInteractionEnabled = NO;
                    verified(weakInfoTextField, account);
                });
                
            } else if (error.code != kAccountErrorCancelled) {
                if (error.code != kAccountErrorWrongPassword) {
                    NSLog(@"Decryption error: %@", error);
                }
                
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [textField setStatus:InfoTextFieldStatusBad animated:YES];
                });
            }
        }];
    };
    /*
    infoTextField.blockTextField.shouldReturn = shouldReturn;
    
    Account* (^sendAccount)(NSString*) = ^Account*(NSString *password) {
        NSString *cacheKey = [[[SecureData secureDataWithData:[password dataUsingEncoding:NSUTF8StringEncoding]] KECCAK256] hexString];
        return [[passwordToAccount objectForKey:cacheKey] objectForKey:@"account"];
    };
    return sendAccount;
     */

    
    return infoTextField;
}

- (InfoTextField*)addPasswordEntryDidChange: (BOOL (^)(InfoTextField*))didChange didReturn: (void (^)(InfoTextField*))didReturn {

    InfoTextField *infoTextField = [self addTextEntry:@"Password" callback:nil];
    infoTextField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    infoTextField.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    infoTextField.textField.placeholder = @"Required";
    infoTextField.textField.secureTextEntry = YES;
    
    __weak InfoTextField *weakInfoTextField = infoTextField;
    __block BOOL valid = NO;
    
    infoTextField.blockTextField.shouldReturn = ^BOOL(BlockTextField *textField) {
        if (valid) {
            didReturn(weakInfoTextField);
        }
        return valid;
    };
    
    infoTextField.blockTextField.didChangeText = ^(BlockTextField *textField) {
        valid = didChange(weakInfoTextField);
        if (valid) {
            if (weakInfoTextField.status != InfoTextFieldStatusGood) {
                [weakInfoTextField setStatus:InfoTextFieldStatusGood animated:YES];
            }
        } else {
            if (weakInfoTextField.status != InfoTextFieldStatusBad) {
                [weakInfoTextField setStatus:InfoTextFieldStatusBad animated:YES];
            }
        }
    };
    
    /*
    __weak InfoTextField *weakSelf = self;
    infoTextField.blockTextField.didChangeText = ^(BlockTextField *textField) {
        if ([textField.text isEqualToString:@""]) {
            [weakSelf setStatus:InfoTextFieldStatusNone animated:NO];
            return;
        }
        
        [weakSelf setStatus:InfoTextFieldStatusSpinning animated:YES];
        
        [callback(weakSelf, textField.text) onCompletion:^(Promise *promise) {
            if (promise.error) {
                [weakSelf setStatus:InfoTextFieldStatusBad animated:YES];
            } else {
                [weakSelf setStatus:InfoTextFieldStatusGood animated:YES];

                // Trigger checking for return in the near future (which will enable the "next" button)
                dispatch_async(dispatch_get_main_queue(), ^() {
                    textField.didChangeText(textField);
                });
                

            }
        }];
        
    };
    */
    return infoTextField;
}

static UILabel *EtherPriceLabel = nil;

+ (void)setEtherPrice:(float)etherPrice {
    if (!EtherPriceLabel) {
        EtherPriceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 44.0f)];
        EtherPriceLabel.adjustsFontSizeToFitWidth = YES;
        EtherPriceLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        EtherPriceLabel.minimumScaleFactor = 0.1f;
        EtherPriceLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
        EtherPriceLabel.font = [UIFont fontWithName:FONT_BOLD size:14.0f];
    }
    
    EtherPriceLabel.text = [NSString stringWithFormat:@"$%.02f\u2009/\u2009ether", etherPrice];
}

- (InfoTextField*)addEtherEntry: (NSString*)title value: (BigNumber*)value didChange: (void (^)(InfoTextField*, BigNumber*))didChange {
    
    InfoTextField *infoTextField = [self addTextEntry:title callback:nil];
    infoTextField.textField.keyboardType = UIKeyboardTypeDecimalPad;

    [infoTextField setEther:value];
    
    // Custom Keyboard
    UIView *amountInputView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 44.0f)];
    infoTextField.textField.inputAccessoryView = amountInputView;

    amountInputView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:amountInputView.bounds];
    toolbar.items = @[
                      [[UIBarButtonItem alloc] initWithCustomView:EtherPriceLabel],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                    target:nil
                                                                    action:nil],
                      //maxButton,
//                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
//                                                                    target:nil
//                                                                    action:nil],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                    target:infoTextField.textField
                                                                    action:@selector(resignFirstResponder)],
                      ];
    [amountInputView addSubview:toolbar];
    
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 43.5f, amountInputView.frame.size.width, 0.5f)];
    separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    separator.backgroundColor = [UIColor colorWithWhite:0.8f alpha:1.0f];
    [amountInputView addSubview:separator];
    
    
    // Began editing...
    infoTextField.blockTextField.didBeginEditing = ^(BlockTextField *textField) {
        // Trim off the units
        if ([textField.text hasPrefix:@"Ξ\u2009"]) {
            textField.text = [textField.text substringFromIndex:2];
        }
        
        NSString *text = textField.text;
        if ([[[NSLocale currentLocale] decimalSeparator] isEqualToString:@","]) {
            text = [text stringByReplacingOccurrencesOfString:@"," withString:@"."];
        }
        
        // If there is no meaningful amount, clear the whole field
        if ([[Payment parseEther:text] isEqual:[BigNumber constantZero]]) {
            textField.text = @"";
        }
    };
    
    
    // Value changed...
    __weak InfoTextField *weakSelf = infoTextField;
    infoTextField.blockTextField.didChangeText = ^(BlockTextField *textField) {
        NSLog(@"Changed: %@", textField.text);
        
        NSString *text = textField.text;
        if ([[[NSLocale currentLocale] decimalSeparator] isEqualToString:@","]) {
            text = [text stringByReplacingOccurrencesOfString:@"," withString:@"."];
        }
        
        didChange(weakSelf, [Payment parseEther:text]);
    };
    
    
    // Done editing...
    infoTextField.blockTextField.didEndEditing = ^(BlockTextField *textField) {
        NSString *text = textField.text;
        if ([[[NSLocale currentLocale] decimalSeparator] isEqualToString:@","]) {
            text = [text stringByReplacingOccurrencesOfString:@"," withString:@"."];
        }
        
        BigNumber *value = [Payment parseEther:text];
        if (!value) { value = [BigNumber constantZero]; }
        
        NSString *ether = [Payment formatEther:value];
        if ([[[NSLocale currentLocale] decimalSeparator] isEqualToString:@","]) {
            ether = [ether stringByReplacingOccurrencesOfString:@"." withString:@","];
        }
        
        textField.text = [@"Ξ\u2009" stringByAppendingString:ether];
    };
    
    infoTextField.blockTextField.shouldChangeText = ^BOOL(BlockTextField *textField, NSRange range, NSString *string) {
        NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
        
        if ([[[NSLocale currentLocale] decimalSeparator] isEqualToString:@","]) {
            text = [text stringByReplacingOccurrencesOfString:@"," withString:@"."];
        }
        
        return (text.length == 0 || [text isEqualToString:@"."] || [Payment parseEther:text] != nil);
    };
    
    return infoTextField;
}

/*
- (BlockPickerView*)addPickerView: (NSString*)title callback: (void (^)(BOOL))callback {
    CGSize size = self.infoViews.frame.size;
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, 50.0f)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
 
    UIFont *labelFont = [UIFont fontWithName:FONT_BOLD size:17.0f];;
    
    CGSize labelSize = [title boundingRectWithSize:view.bounds.size
                                           options:NSStringDrawingUsesFontLeading
                                        attributes:@{
                                                     NSFontAttributeName: labelFont
                                                     }
                                           context:nil].size;
    
    // Bold font isn't lined up with non-bold font...
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 0.0f, labelSize.width + 24.0f, 47.0f)];
    label.font = labelFont;
    label.text = title;
    label.textColor = [UIColor whiteColor];
    [view addSubview:label];

    [self addView:view];
    
    [_titleViews addObject:label];
    
    CGFloat blockPickerX = label.frame.origin.x + label.frame.size.width;
    CGRect blockPickerFrame = CGRectMake(blockPickerX, 0.0f, size.width - blockPickerX - 15.0f, 50.0f);
    BlockPickerView *blockPickerView = [[BlockPickerView alloc] initWithFrame:blockPickerFrame];
    [view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:blockPickerView action:@selector(becomeFirstResponder)]];
    
    return blockPickerView;
}
*/

- (InfoMnemonicPhraseView*)addMnemonicPhraseView:(NSString *)mnemonic didChange:(void (^)(InfoMnemonicPhraseView *))didChange {
    CGRect frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 100.0f);
    InfoMnemonicPhraseView *mnemonicPhraseView = [[InfoMnemonicPhraseView alloc] initWithFrame:frame withPhrase:mnemonic];
    mnemonicPhraseView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    mnemonicPhraseView.didChangeMnemonic = didChange;
    [self addView:mnemonicPhraseView];
    return mnemonicPhraseView;
}

/*
- (NSUInteger)textFieldCount {
    return [_textFields count];
}

- (BlockTextField*)textFieldAtIndex:(NSUInteger)index {
    return [_textFields objectAtIndex:index];
}
*/
@end
