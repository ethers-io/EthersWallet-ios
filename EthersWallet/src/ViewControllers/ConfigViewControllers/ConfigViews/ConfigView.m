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

#import "ConfigView.h"

#import "CrossfadeLabel.h"
#import "Utilities.h"


@interface TouchLabel: CrossfadeLabel

@property (nonatomic, copy) void (^onHold)(TouchLabel*, BOOL on);

@end


@implementation TouchLabel

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_onHold) { _onHold(self, YES); }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_onHold) { _onHold(self, NO); }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_onHold) { _onHold(self, NO); }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}


@end


@interface ConfigView ()

@property (nonatomic, readonly) CrossfadeLabel *titleLabel;

@end


@implementation ConfigView


- (instancetype)initWithTitle: (NSString*)title {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
    if (self) {
        
        UIFont *labelFont = [UIFont fontWithName:FONT_BOLD size:17.0f];;
        
        CGSize labelSize = [title boundingRectWithSize:self.frame.size
                                               options:NSStringDrawingUsesFontLeading
                                            attributes:@{ NSFontAttributeName: labelFont }
                                               context:nil].size;

        if (labelSize.width < 65) { labelSize.width = 65.0f; }
        
        // Bold font isn't lined up with non-bold font...
        _titleLabel = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(15.0f, 0.0f, labelSize.width + 24.0f, 47.0f)];
        _titleLabel.font = labelFont;
        _titleLabel.text = title;
        _titleLabel.textColor = [UIColor whiteColor];
        [self addSubview:_titleLabel];
        
        _contentView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
        _contentView.userInteractionEnabled = YES;
        [self addSubview:_contentView];

        [_contentView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)]];
    }
    return self;
}

- (NSString*)title {
    return _titleLabel.text;
}

- (void)setTitle:(NSString *)title {
    
    CGSize labelSize = [title boundingRectWithSize:self.frame.size
                                           options:NSStringDrawingUsesFontLeading
                                        attributes:@{ NSFontAttributeName: _titleLabel.font }
                                           context:nil].size;
    
    if (labelSize.width < 65) { labelSize.width = 65.0f; }
    _titleLabel.frame = CGRectMake(15.0f, 0.0f, labelSize.width + 24.0f, 47.0f);
    [_titleLabel setText:title animated:YES];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    if ([super becomeFirstResponder]) {
        UIView *view = self.superview;
        while (view) {
            if ([view isKindOfClass:[UIScrollView class]]) {
                CGRect rect = [view convertRect:self.bounds fromView:self];
                rect.size.height += _bottomMargin;
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [((UIScrollView*)view) scrollRectToVisible:rect animated:YES];
                });
                break;
            }
            view = view.superview;
        }
        return YES;
    }
    return NO;
}

- (void)pulse {
    void (^animate)() = ^() {
        self.backgroundColor = [UIColor clearColor];
    };
    
    self.backgroundColor = [UIColor colorWithWhite:0.8f alpha:0.25f];
    
    [UIView animateWithDuration:0.3f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:animate
                     completion:nil];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_onHold) { return; }
    
    BOOL holdingContent = NO;
    for (UITouch *touch in touches) {
        if ([_contentView hitTest:[touch locationInView:_contentView] withEvent:event]) {
            holdingContent = YES;
        }
    }
    
    _onHold(self, holdingContent ? ConfigViewHoldContent: ConfigViewHoldTitle);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_onHold) { _onHold(self, ConfigViewHoldNone); }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_onHold) { _onHold(self, ConfigViewHoldNone); }
}

- (void)didTap: (UIGestureRecognizer*)gestureRecognizer {
    if (_didTap) { _didTap(self); }
}

@end
