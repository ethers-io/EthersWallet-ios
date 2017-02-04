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

#import "CloudView.h"

#import "UIColor+hex.h"

@interface CloudView () {
    float _size;
    UIView *_cloudBackground, *_cloudsForeground;
}

@end

@implementation CloudView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        
        _size = frame.size.height;

        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = self.bounds;
        gradient.colors = @[(id)[UIColor colorWithHex:0x6696d8].CGColor,
                            (id)[UIColor colorWithHex:0x6696d8].CGColor,
                            (id)[UIColor colorWithHex:0xc5dde9].CGColor];
        gradient.locations = @[@(0.0f), @(0.7f), @(1.0f)];
        [self.layer addSublayer:gradient];
        
        _cloudBackground = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _size * 2.0f, frame.size.height)];
        _cloudBackground.alpha = 0.5f;

        _cloudsForeground = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _size * 2.0f, frame.size.height)];
        _cloudsForeground.alpha = 0.3f;

        
        UIImageView *cloud;
        
        cloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"cloud-0.png"]];
        cloud.frame = CGRectMake(0.0f, 0.0f, _size, _size);
        [_cloudBackground addSubview:cloud];

        cloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"cloud-0.png"]];
        cloud.frame = CGRectMake(_size, 0.0f, _size, _size);
        [_cloudBackground addSubview:cloud];

        cloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"cloud-1.png"]];
        cloud.frame = CGRectMake(0.0f, 0.0f, _size, _size);
        [_cloudsForeground addSubview:cloud];
        
        cloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"cloud-1.png"]];
        cloud.frame = CGRectMake(_size, 0.0f, _size, _size);
        [_cloudsForeground addSubview:cloud];

        
        [self addSubview:_cloudBackground];
        [self addSubview:_cloudsForeground];
    }
    return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];

    if (newWindow) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startAnimating {

    float multiplier = _size / 736.0f;
    
    if (_cloudBackground.layer.animationKeys.count == 0) {
        
        void (^animate)() = ^() {
            _cloudBackground.transform = CGAffineTransformMakeTranslation(-_size, 0.0f);
        };

        [_cloudBackground.layer removeAllAnimations];
        _cloudBackground.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:31.0f * multiplier
                              delay:0.0f
                            options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionRepeat | UIViewAnimationOptionBeginFromCurrentState
                         animations:animate
                         completion:nil];
    }
    
    if (_cloudsForeground.layer.animationKeys.count == 0) {

        void (^animate)() = ^() {
            _cloudsForeground.transform = CGAffineTransformMakeTranslation(-_size, 0.0f);
        };

        [_cloudsForeground.layer removeAllAnimations];
        _cloudsForeground.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:10.0f *multiplier
                              delay:0.0f
                            options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionRepeat | UIViewAnimationOptionBeginFromCurrentState
                         animations:animate
                         completion:nil];
    }
}

- (void)stopAnimating {
    [_cloudBackground.layer removeAllAnimations];
    [_cloudsForeground.layer removeAllAnimations];
}

@end
