//
//  OutlineLabel.m
//  EthersWallet
//
//  Created by Richard Moore on 2018-01-19.
//  Copyright © 2018 ethers.io. All rights reserved.
//

#import "OutlineLabel.h"

@implementation OutlineLabel

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _outlineColor = [UIColor whiteColor];
        _outlineWidth = 1.0f;
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor *textColor = self.textColor;
    
    CGContextSetLineWidth(context, _outlineWidth);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetTextDrawingMode(context, kCGTextStroke);
    self.textColor = _outlineColor;
    [super drawTextInRect:rect];
    
    CGContextSetTextDrawingMode(context, kCGTextFill);
    self.textColor = textColor;
    [super drawTextInRect:rect];
}

@end
