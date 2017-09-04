//
//  BoxView.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-09-01.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "BoxView.h"

@implementation BoxView {
    CGPoint _boxPoints[4];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
    }
    return self;
}

- (void)setPoints:(NSArray *)points {
    if (points && points.count == 4) {
        _points = points;
        for (int i = 0; i < 4; i++) {
            _boxPoints[i] = [self pointAt:i];
        }
    } else {
        _points = nil;
    }
    
    [self setNeedsDisplay];
}

- (CGPoint)pointAt: (NSUInteger)index {
    CGPoint point = CGPointFromString([_points objectAtIndex:index]);
    CGPoint pointOpposite = CGPointFromString([_points objectAtIndex:(index + 2) % 4]);
    CGPoint delta = CGPointMake(pointOpposite.x - point.x, pointOpposite.y - point.y);
    return CGPointMake(point.x - 0.1 * delta.x, point.y - 0.1 * delta.y);
}

- (void)makePath: (CGContextRef)context {
    CGContextBeginPath(context);

    for (NSInteger i = 0; i < 4; i++) {
        CGPoint point = _boxPoints[i];
        if (i == 0) {
            CGContextMoveToPoint(context, point.x, point.y);
        } else {
            CGContextAddLineToPoint(context, point.x, point.y);
        }
    }
    
    CGContextClosePath(context);
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    if (!_points) { return; }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Fill the outside of the QR code with a dark black
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.0f green:0.0 blue:0.0 alpha:0.65f].CGColor);
    [self makePath:context];
    CGContextAddRect(context, self.bounds);
    CGContextEOFillPath(context);
    
    // Prepare a clipping mask to protect the QR code from the shadows
    [self makePath:context];
    CGContextAddRect(context, self.bounds);
    CGContextEOClip(context);

    // Prepare the outline + shadow
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.0f), 15.0f, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(context, 4.0f);
    
    // Draw it twice to get e thicker shadow
    for (NSInteger i = 0; i < 2; i++) {
        [self makePath:context];
        CGContextStrokePath(context);
    }
}

@end
