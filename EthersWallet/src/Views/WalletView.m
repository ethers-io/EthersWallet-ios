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

#import "WalletView.h"

#import "ModalViewController.h"
#import "QRCodeView.h"
#import "UIColor+hex.h"
#import "Utilities.h"

@interface WalletView () {
    QRCodeView *_qrCodeView;
    UILabel *_addressLabel;
}

@end

@implementation WalletView

- (instancetype)initWithAddress: (Address*)address width: (CGFloat)width {
    float qrWidth = width - 130.0f;

    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, width, qrWidth)];
    if (self) {
        _address = address;
        
        _qrCodeView = [[QRCodeView alloc] initWithWidth:qrWidth
                                                  color:[UIColor colorWithHex:ColorHexDark]];
        _qrCodeView.center = CGPointMake(width / 2.0f, qrWidth / 2.0f);
        _qrCodeView.transform = CGAffineTransformMakeRotation(-M_PI_2);
        [self addSubview:_qrCodeView];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, qrWidth - 20.0f, 44.0f)];
        titleLabel.center = CGPointMake(65.0f - 22.0f, _qrCodeView.center.y);
        //        titleLabel.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:12.0f];
        titleLabel.font = [UIFont fontWithName:FONT_MONOSPACE size:12.0f];
        titleLabel.text = @"Your Public Address";
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = [UIColor colorWithHex:ColorHexNormal];
        titleLabel.transform = CGAffineTransformMakeRotation(-M_PI_2);
        [self addSubview:titleLabel];
        
        _addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, qrWidth - 10.0f, 44.0f)];
        _addressLabel.adjustsFontSizeToFitWidth = YES;
        _addressLabel.center = CGPointMake(width - 65.0f + 22.0f, _qrCodeView.center.y);
        _addressLabel.font = [UIFont fontWithName:FONT_MONOSPACE_SMALL size:12.0f];
        _addressLabel.minimumScaleFactor = 0.1f;
        _addressLabel.textAlignment = NSTextAlignmentCenter;
        _addressLabel.textColor = [UIColor colorWithHex:ColorHexNormal];
        _addressLabel.transform = CGAffineTransformMakeRotation(-M_PI_2);
        [self addSubview:_addressLabel];
        
        self.userInteractionEnabled = YES;
        [self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)]];
    }
    return self;
}

- (void)setAddress:(Address *)address {
    _address = address;
    _addressLabel.text = address.checksumAddress;
    _qrCodeView.address = address;
}

- (void)tapped: (UILongPressGestureRecognizer*)longPressGestureRecognizer {
    if ([longPressGestureRecognizer state] != UIGestureRecognizerStateBegan) { return; }
    
    CGPoint point = [longPressGestureRecognizer locationInView:longPressGestureRecognizer.view.superview];
    
    CGRect targetRect = longPressGestureRecognizer.view.frame;
     targetRect.origin.y = point.y;
     targetRect.size.height = 0.0f;
    
    UIMenuController *menu = [UIMenuController sharedMenuController];
    
    [self becomeFirstResponder];
    [menu setTargetRect:targetRect inView:longPressGestureRecognizer.view.superview];
    menu.menuItems = @[
                       [[UIMenuItem alloc] initWithTitle:@"Copy Address" action:@selector(copyAddress:)],
                       [[UIMenuItem alloc] initWithTitle:@"Share Address" action:@selector(shareAddress:)],
                       ];
    [menu setMenuVisible:YES animated:YES];
}

- (void)copyAddress: (id)sender {
    [[UIPasteboard generalPasteboard] setString:_address.checksumAddress];
    
    // Flash the address we are copying
    //_addressLabel.textColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
    //[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(animateAddressLabel) userInfo:nil repeats:NO];
    
    void (^animate)() = ^() {
        _qrCodeView.transform = CGAffineTransformIdentity;
    };
    
    _qrCodeView.transform = CGAffineTransformMakeScale(0.9f, 0.9f);
    [UIView animateWithDuration:1.0f
                          delay:0.0f
         usingSpringWithDamping:0.3f
          initialSpringVelocity:0.0f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:animate
                     completion:nil];
}

- (void)shareAddress: (id)sender {

    NSArray *shareItems = @[
                            [NSURL URLWithString:[NSString stringWithFormat:@"iban:%@", _address.icapAddress]]
                            ];

    UIActivityViewController *shareViewController = [[UIActivityViewController alloc] initWithActivityItems:shareItems
                                                                                      applicationActivities:nil];

    ModalViewController *modalViewController = [ModalViewController presentViewController:shareViewController animated:YES completion:nil];

    shareViewController.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        NSLog(@"type=%@ compl=%d returned=%@ error=%@", type, completed, items, error);
        [modalViewController dismissViewControllerAnimated:YES completion:nil];
    };

}


#pragma mark - UIResponder

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(shareAddress:) || action == @selector(copyAddress:)) {
        return YES;
    }
    return NO;
}

@end
