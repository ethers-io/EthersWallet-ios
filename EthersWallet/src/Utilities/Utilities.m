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

#import "Utilities.h"

#import <ethers/Promise.h>
#import "UIColor+hex.h"


CIImage* createQRForString(NSData *qrData, UIColor *color) {
    
    // Create the filter
    CIFilter *filterQr = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    // Set the message content
    [filterQr setValue:qrData forKey:@"inputMessage"];
    
    // Correction Level: L=7%, M=15%, Q=25%, H=30%
    [filterQr setValue:@"L" forKey:@"inputCorrectionLevel"];
    
    CIColor *foregroundColor = [CIColor colorWithCGColor:color.CGColor];
    CIColor *backgroundColor = [CIColor colorWithRed:1.0f green:1.0f blue:0.0f alpha:0.0f];
    
    // Color the QR code
    CIFilter *filterColor = [CIFilter filterWithName:@"CIFalseColor"
                                       keysAndValues:
                             @"inputImage", filterQr.outputImage,
                             @"inputColor0", foregroundColor,
                             @"inputColor1", backgroundColor,
                             nil];
    
    return filterColor.outputImage;
}


UIImage* createNonInterpolatedUIImageFromCIImage(CIImage *image, CGFloat width, CGFloat border, CGFloat scale) {
    
    int moduleWidth = image.extent.size.width;
    
    float padding = border * (width / (moduleWidth + (2.0f * border)));
    
    // Render the CIImage into a CGImage
    CGImageRef cgImage = [[CIContext contextWithOptions:nil] createCGImage:image fromRect:image.extent];
    
    // Now we'll rescale using CoreGraphics
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, width), NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // We don't want to interpolate (since we've got a pixel-correct image)
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGRect box = CGContextGetClipBoundingBox(context);
    
    // Flip the Y
    CGContextConcatCTM(context, CGAffineTransformMake(1, 0, 0, -1, 0, box.size.height));
    
    //CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    //CGContextFillRect(context, box);
    
    box.origin.x += padding;
    box.origin.y += padding;
    box.size.width -= 2.0f * padding;
    box.size.height -= 2.0f * padding;
    CGContextDrawImage(context, box, cgImage);
    
    // Get the image out
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // Tidy up
    UIGraphicsEndImageContext();
    CGImageRelease(cgImage);
    
    return scaledImage;
}



@implementation Utilities

static NSArray *WeekdayNames = nil, *MonthNames = nil;
static NSDateFormatter *DateFormatter = nil;
static NSCalendar *Calendar = nil;

static NSDateFormatter *DateFormat = nil;
static NSDateFormatter *TimeFormat = nil;

static NSMutableDictionary *FetchDedup = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        WeekdayNames = @[@"none", @"Sunday", @"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday"];
        MonthNames = @[@"none", @"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December",];
        
        DateFormatter = [[NSDateFormatter alloc] init];
        [DateFormatter setDateFormat:@"yyyy-MM-dd  hh:mma"];

        DateFormat = [[NSDateFormatter alloc] init];
        DateFormat.locale = [NSLocale currentLocale];
        [DateFormat setDateFormat:@"yyyy-MM-dd"];
        
        TimeFormat = [[NSDateFormatter alloc] init];
        TimeFormat.locale = [NSLocale currentLocale];
        [TimeFormat setTimeStyle:NSDateFormatterShortStyle];
        
        // @TODO: Add notification to regenerate these on local change

        FetchDedup = [NSMutableDictionary dictionary];
    });
}

+ (NSString*)timeAgo:(NSTimeInterval)timestamp {

    NSTimeInterval secondsAgo = [NSDate timeIntervalSinceReferenceDate] - timestamp;
    if (secondsAgo < 60.0f) {
        return @"Just Now";
    }
    
    NSTimeInterval minutesAgo = roundf(secondsAgo / 60.0f);
    if (minutesAgo < 60) {
        return [NSString stringWithFormat:@"%d Minute%@ Ago", (int)minutesAgo, ((minutesAgo != 1.0f) ? @"s": @"")];
    }
    
    NSTimeInterval hoursAgo = roundf(secondsAgo / (60.0f * 60.0f));
    if (hoursAgo < 4) {
        return [NSString stringWithFormat:@"%d Hour%@ Ago", (int)hoursAgo, ((hoursAgo != 1.0f) ? @"s": @"")];
    }
    
    NSCalendarUnit components = NSCalendarUnitDay | NSCalendarUnitWeekday | NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitTimeZone;
    NSDateComponents *dateComponents = [Calendar components:components fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:timestamp]];
    NSDateComponents *nowComponents = [Calendar components:components fromDate:[NSDate date]];

    //NSLog(@"g: %@ %@", dateComponents.timeZone, nowComponents.timeZone);

    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp];
    
    // Return "at HH:MM"
    if (dateComponents.day == nowComponents.day) {
        return [NSString stringWithFormat:@"At %@", [TimeFormat stringFromDate:date]];
    }

    // Return "on YYYY-mm-dd"
    return [@"On " stringByAppendingString:[DateFormat stringFromDate:date]];
}

+ (UIButton*)ethersButton:(NSString *)iconName fontSize:(CGFloat)fontSize color:(NSUInteger)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
    button.titleLabel.font = [UIFont fontWithName:FONT_ETHERS size:fontSize];
    [button setTitle:iconName forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithHex:color] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithHex:color alpha:0.3f] forState:UIControlStateHighlighted];
    [button setTitleColor:[UIColor colorWithHex:color alpha:0.3f] forState:UIControlStateDisabled];
    [button addTarget:self action:@selector(fade:) forControlEvents:UIControlEventTouchUpInside];

    return button;
}

+ (void)fade: (UIButton*)sender {
    sender.alpha = 0.3f;
    [UIView animateWithDuration:0.3f animations:^() {
        sender.alpha = 1.0f;
    }];
}

+ (void)setupNavigationBar: (UINavigationBar*)navigationBar backgroundColor: (UIColor*)backgroundColor {
    static UIImage *blank = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blank = [[UIImage alloc] init];
    });

    navigationBar.backgroundColor = [UIColor clearColor];
    navigationBar.tintColor = [UIColor whiteColor];
    [navigationBar setBackgroundImage:blank forBarPosition:UIBarPositionTop barMetrics:UIBarMetricsDefault];
    

    UIView *colorView = [[UIView alloc] initWithFrame:navigationBar.bounds];
    colorView.tag = 100;
    colorView.backgroundColor = backgroundColor;
    [navigationBar insertSubview:colorView atIndex:0];

    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    visualEffectView.frame = navigationBar.bounds;
    visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [navigationBar insertSubview:visualEffectView atIndex:0];
}

+ (UINavigationBar*)addNavigationBarToView: (UIView*)view {
    UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, view.frame.size.width, 64.0f)];
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [view addSubview:navigationBar];
    
    [self setupNavigationBar:navigationBar backgroundColor:[UIColor colorWithHex:ColorHexNavigationBar overHex:ColorHexWhite alpha:0.5f]];
    
    return navigationBar;
}

+ (UILabel*)navigationBarTitleWithString: (NSString*)title {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 44.0f)];
    label.font = [UIFont fontWithName:FONT_BOLD size:20.0f];
    label.text = title;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor colorWithHex:ColorHexNavigationBarTitle];
    
    return label;
}

+ (UILabel*)navigationBarLogoTitle {
    UILabel *label = [Utilities navigationBarTitleWithString:ICON_NAME_LOGO];
    label.font = [UIFont fontWithName:FONT_ETHERS size:40.0f];
    return label;
}

+ (UIImage*)qrCodeForData: (NSData*)data width: (CGFloat)width color: (UIColor*)color padding:(CGFloat)padding {
//UIImage* qrCodeForData(NSData *data, CGFloat width, CGFloat scale, UIColor *color) {
    return createNonInterpolatedUIImageFromCIImage(createQRForString(data, color), width, padding, [UIScreen mainScreen].scale);
}

+ (DataPromise*)fetchUrl: (NSString*)url body: (NSData*)body dedupToken: (NSString*)dedupToken {
    DataPromise *promise = nil;
    
    @synchronized (FetchDedup) {
        promise = [FetchDedup objectForKey:dedupToken];
        
        if (promise) { return promise; }

        promise = [DataPromise promiseWithSetup:^(Promise *promise) {
            void (^handleResponse)(NSData*, NSURLResponse*, NSError*) = ^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    [promise reject:error];
                    return;
                }
                
                if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
                    NSDictionary *userInfo = @{@"reason": @"response not NSHTTPURLResponse", @"url": url};
                    [promise reject:[NSError errorWithDomain:@"UtilityError" code:0 userInfo:userInfo]];
                    return;
                }
                
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                if (httpResponse.statusCode != 200) {
                    NSDictionary *userInfo = @{@"statusCode": @(httpResponse.statusCode), @"url": url};
                    [promise reject:[NSError errorWithDomain:@"UtilityError" code:0 userInfo:userInfo]];
                    return;
                }
                
                [promise resolve:data];
            };
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
                NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
                [request setValue:[Utilities userAgent] forHTTPHeaderField:@"User-Agent"];
                
                if (body) {
                    [request setHTTPMethod:@"POST"];
                    [request setValue:[NSString stringWithFormat:@"%d", (int)body.length] forHTTPHeaderField:@"Content-Length"];
                    [request setHTTPBody:body];
                }
                
                NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
                NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:handleResponse];
                [task resume];
            });
        }];
    
        [FetchDedup setObject:promise forKey:dedupToken];
    }
    
    [promise onCompletion:^(DataPromise *promise) {
        @synchronized (FetchDedup) {
            [FetchDedup removeObjectForKey:dedupToken];
        }
    }];
    
    return promise;
}

+ (NSString*)userAgent {
    static NSString *userAgentString = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
        NSString *platform = [UIDevice currentDevice].systemVersion;
        userAgentString = [NSString stringWithFormat:@"io.ethers.app/%@ (iOS/%@)", version, platform];
    });
    
    return userAgentString;
}
@end
