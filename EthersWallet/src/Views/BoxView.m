//
//  BoxView.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-09-01.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "BoxView.h"
#import "UIColor+hex.h"

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

static CGFloat distance(CGPoint pointA, CGPoint pointB) {
    CGFloat dx = (pointB.x - pointA.x), dy = (pointB.y - pointA.y);
    return sqrt((dx * dx) + (dy * dy));
}

// Computes the point from origin that is length units toward target
static CGPoint normalize(CGPoint origin, CGPoint target, CGFloat length) {
    CGFloat ratio = length / distance(origin, target);
    return CGPointMake(origin.x + ratio * (target.x - origin.x), origin.y + ratio * (target.y - origin.y));
}

- (CGPoint)pointAt: (NSUInteger)index {
    CGPoint point = CGPointFromString([_points objectAtIndex:index]);

    // Normalize our adjacent points
    CGPoint adj0 = normalize(point, CGPointFromString([_points objectAtIndex:(index + 3) % 4]), 100);
    CGPoint adj1 = normalize(point, CGPointFromString([_points objectAtIndex:(index + 1) % 4]), 100);
    
    // Compute the midpoint of our normalized adjacent points
    CGPoint center = CGPointMake((adj0.x + adj1.x) / 2.0f, (adj0.y + adj1.y) / 2.0f);

    // And draw 20% ((4 modules quiet zone) / (29 modules data) + (small fuzz factor)) larger box
    return normalize(point, center, -0.2 * distance(point, center));
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
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.0f green:0.0 blue:0.0 alpha:0.55f].CGColor);
    [self makePath:context];
    CGContextAddRect(context, self.bounds);
    CGContextEOFillPath(context);
    
    // Prepare a clipping mask to protect the QR code from the shadows
    [self makePath:context];
    CGContextAddRect(context, self.bounds);
    CGContextEOClip(context);

    // Prepare the outline + shadow
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithHex:ColorHexNavigationBar].CGColor);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.0f), 15.0f, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(context, 8.0f);
    
    // Draw it twice to get e thicker shadow
    for (NSInteger i = 0; i < 2; i++) {
        [self makePath:context];
        CGContextStrokePath(context);
    }
}

@end
