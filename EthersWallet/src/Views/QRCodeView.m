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

#import "QRCodeView.h"

//#import "Account.h"
#import "Utilities.h"

@interface QRCodeView () {
    UILabel *_addressLabel;
    UIImageView *_imageView;
    UIColor *_color;
}

@end


@implementation QRCodeView

- (instancetype)initWithWidth:(float)width color:(UIColor *)color {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, width, width)];
    if (self) {
        _color = color;
        self.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

- (void)setAddress:(Address *)address {
    _address = address;
    
    CGFloat width = self.frame.size.width;

    NSData *data = [[NSString stringWithFormat:@"iban:%@", _address.icapAddress] dataUsingEncoding:NSISOLatin1StringEncoding];
//    UIImage *qrCodeImage = qrCodeForData(data, width, [UIScreen mainScreen].scale, _color);
    UIImage *qrCodeImage = [Utilities qrCodeForData:data width:width color:_color padding:3.0f];
    
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithImage:qrCodeImage];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.center = CGPointMake(width / 2.0f, width / 2.0f);
        _imageView.layer.borderColor = _color.CGColor;
        _imageView.layer.borderWidth = 1.0f;
        [self addSubview:_imageView];
    } else {
        _imageView.image = qrCodeImage;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.address = _address;
}

@end
