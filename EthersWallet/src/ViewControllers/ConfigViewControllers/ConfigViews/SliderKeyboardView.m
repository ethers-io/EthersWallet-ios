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

#import "SliderKeyboardView.h"

#import "UIColor+hex.h"
#import "Utilities.h"


@implementation SliderKeyboardView

- (instancetype)initWithFrame:(CGRect)frame stopCount:(NSUInteger)stopCount {
    self = [super initWithFrame:frame];
    if (self) {
        _stopCount = stopCount;
        
        _topInfo = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 20.0f)];
        _topInfo.font = [UIFont fontWithName:FONT_ITALIC size:16.0f];
        _topInfo.textColor = [UIColor colorWithWhite:0.35 alpha:1.0f];
        [self addView:_topInfo];
        
        _slider = [[UISlider alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 240.0f, 30.0f)];
        [_slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        _slider.minimumTrackTintColor = [UIColor colorWithHex:0x5555ff];
        _slider.minimumValue = 0;
        _slider.maximumValue = stopCount - 1;
        [self addView:_slider];
        
        _bottomInfo = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320, 20.0f)];
        _bottomInfo.font = [UIFont fontWithName:FONT_MEDIUM size:13.0f];
        _bottomInfo.textColor = [UIColor colorWithWhite:0.35 alpha:1.0f];
        [self addView:_bottomInfo];
        
        [self refreshAnimated:NO];
    }
    return self;
}

- (void)sliderChanged: (UISlider*)slider {
    NSUInteger newValue = roundf(slider.value);
    slider.value = newValue;
    
    if (newValue != _selectedStopIndex) {
        _selectedStopIndex = newValue;
        [self refreshAnimated:YES];
        if (_didChange) { _didChange(self); }
    }
}

- (void)refreshAnimated:(BOOL)animated {
}

- (void)setSelectedStopIndex:(NSUInteger)selectedStopIndex {
    [self setSelectedStopIndex:selectedStopIndex animated:NO];
}

- (void)setSelectedStopIndex: (NSUInteger)selectedStopIndex animated: (BOOL)animated {
    _slider.value = selectedStopIndex;
    _selectedStopIndex = selectedStopIndex;
    [self refreshAnimated:animated];
}

@end
