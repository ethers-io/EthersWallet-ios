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

#import "ScannerViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "UIImage+resize.h"
#import "UIColor+hex.h"
#import "Utilities.h"

#define unhex(v) (((float)(v))/255.0f)


CGPoint pointFromArray(NSArray *points, int index) {
    CGPoint point;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)[points objectAtIndex:index], &point);
    return point;
}


@interface OutlineLabel : UILabel

@property(nonatomic) UIColor *outlineColor;
@property(nonatomic) CGFloat outlineWidth;

@end


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



@interface ScannerViewController () <AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    AVCaptureSession *_captureSession;
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    BOOL _scanning;
    
    UIButton *_cameraRollButton;
    UIView *_previewView, *_photoPreviewView;
    
    OutlineLabel *_messageLabel;
    NSTimer *_messageTimer;
    
    UIView *_noCameraView;
    BOOL _cameraConfigured;
}

@end


@implementation ScannerViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        _cameraRollButton = [Utilities ethersButton:ICON_NAME_CAMERA_ROLL fontSize:30.0f color:0xeeeeee];
        [_cameraRollButton addTarget:self action:@selector(tapCameraRoll) forControlEvents:UIControlEventTouchUpInside];
        
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_cameraRollButton];
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                               target:self
                                                                                               action:@selector(tapCancel)];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(tapCancel)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - View Life-Cycle

- (void)loadView {
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _previewView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_previewView];
    
    _photoPreviewView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_photoPreviewView];
    
    _noCameraView = [[UIView alloc] initWithFrame:self.view.bounds];
    _noCameraView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_noCameraView];

    {
        CGRect frame = _noCameraView.frame;
        
        UITextView *label = [[UITextView alloc] initWithFrame:CGRectMake(15.0f, 0.0f, frame.size.width - 30.0f, 100.0f)];
        label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
        label.backgroundColor = [UIColor clearColor];
        label.center = CGPointMake(frame.size.width / 2.0f, frame.size.height / 3.0f);
        label.font = [UIFont fontWithName:FONT_ITALIC size:17.0f];
        label.text = @"To scan QR codes, please enable access to the Camera.";
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor colorWithHex:ColorHexNormal];
        label.userInteractionEnabled = NO;
        [_noCameraView addSubview:label];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin  | UIViewAutoresizingFlexibleBottomMargin;
        button.bounds = CGRectMake(0.0f, 0.0f, frame.size.width, 60.0f);
        button.center = CGPointMake(frame.size.width / 2.0f, 7.0f * frame.size.height / 10.0f);
        [_noCameraView addSubview:button];
        
        [button setTitle:@"Open Settings" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor colorWithHex:ColorHexToolbarIcon] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor colorWithHex:ColorHexToolbarIcon alpha:0.3f] forState:UIControlStateHighlighted];
        [button setTitleColor:[UIColor colorWithHex:ColorHexToolbarIcon alpha:0.3f] forState:UIControlStateDisabled];
        
        [button addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    }

    UINavigationBar *navigationBar = [Utilities addNavigationBarToView:self.view];
    [self.view addSubview:navigationBar];
    
    [navigationBar setItems:@[self.navigationItem]];
    
    _cameraConfigured = [self setupCamera];
    
    _noCameraView.hidden = _cameraConfigured;
}

- (BOOL)setupCamera {
    
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    if ([videoCaptureDevice lockForConfiguration:&error]) {
        if (videoCaptureDevice.isAutoFocusRangeRestrictionSupported) {
            NSLog(@"AutoRange");
            [videoCaptureDevice setAutoFocusRangeRestriction:AVCaptureAutoFocusRangeRestrictionNear];
        }
//        if ([videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
//            NSLog(@"AutoFocus");
//            [videoCaptureDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
//        }
        if ([videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            NSLog(@"AutoExpose");
            [videoCaptureDevice setExposureMode:AVCaptureExposureModeCustom];
        }
        
        CMTime exposure = videoCaptureDevice.exposureDuration;
        NSLog(@"Foo: %lld %d", exposure.value, exposure.timescale);
        exposure.value = 1;
        exposure.timescale = 80;
//        CMTime maxExposure = videoCaptureDevice.activeFormat.maxExposureDuration;
        
//        exposure.value += 0.(maxExposure.value - exposure.value);
        
        float iso = videoCaptureDevice.activeFormat.minISO + 0.2f * (videoCaptureDevice.activeFormat.maxISO - videoCaptureDevice.activeFormat.minISO);
        [videoCaptureDevice setExposureModeCustomWithDuration:exposure
                                                          ISO:iso
                                            completionHandler:^(CMTime syncTime) { NSLog(@"Done"); }];
        
        [videoCaptureDevice unlockForConfiguration];
    } else {
        NSLog(@"Could not configure video capture device: %@", error);
        return NO;
    }
    
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:&error];
    if(videoInput) {
        _captureSession = [[AVCaptureSession alloc] init];
        [_captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
        
        [_captureSession addInput:videoInput];
    } else {
        NSLog(@"Could not create video input: %@", error);
        return NO;
    }
    
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _previewLayer.frame = self.view.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView.layer insertSublayer:_previewLayer atIndex:0];
    
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:metadataOutput];
    [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [metadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    
    return YES;
}

- (void)showMessage: (NSString*)message timeout:(float)timeout {
    NSLog(@"Show Message: %@", message);
    
    // If we have a pending message to remove, unschedule it; we're removing it now
    [_messageTimer invalidate];
    _messageTimer = nil;
    
    if (_messageLabel) {
        [_messageLabel removeFromSuperview];
        _messageLabel = nil;
    }
    
    // Any old message to remove?
//    UILabel *lastMessageLabel = _lastMessageLabel;
//    _lastMessageLabel = nil;
    
    if (message) {
        CGSize size = self.view.frame.size;
        
        _messageLabel = [[OutlineLabel alloc] initWithFrame:CGRectMake(0.0f, 0.75f * size.height - 22.0f, size.width, 44.0f)];
        _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _messageLabel.alpha = 0.0f;
        _messageLabel.font = [UIFont fontWithName:FONT_BOLD_ITALIC size:17.0f];
        _messageLabel.outlineColor = [UIColor blackColor];
        _messageLabel.outlineWidth = 4.0f;
        _messageLabel.text = message;
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.textColor = [UIColor whiteColor];
        [self.view addSubview:_messageLabel];
    }
    
    void (^animate)() = ^() {
        _messageLabel.alpha = 1.0f;
    };
    
    [UIView animateWithDuration:0.5f animations:animate completion:nil];
    
    if (timeout && message) {
        _messageTimer = [NSTimer scheduledTimerWithTimeInterval:timeout repeats:NO block:^(NSTimer *timer) {
            
            // Should not happen
            if (timer != _messageTimer) { return; }
            _messageTimer = nil;
            
            void (^animate)() = ^(){
                _messageLabel.alpha = 0.0f;
            };
            
            void (^complete)(BOOL) = ^(BOOL complete) {
                [_messageLabel removeFromSuperview];
            };
            
            [UIView animateWithDuration:0.5f animations:animate completion:complete];
        }];
    }
}

#pragma mark - Scanner

- (void)start {
    if (_scanning || !_cameraConfigured)  { return; }
    _scanning = YES;
    
    [_captureSession startRunning];
}

- (void)stop {
    if (!_scanning)  { return; }
    _scanning = NO;

    [_captureSession stopRunning];
}

- (void)startScanningAnimated:(BOOL)animated {
    if (_scanning) { return; }
    
    [self start];
    
    if (!_scanning) { return; }
    
    if (animated) {
        _previewView.alpha = 0.0f;
        [UIView animateWithDuration:0.5f delay:0.0f options:0 animations:^() {
            _previewView.alpha = 1.0f;
        } completion:nil];
        
    } else {
        _previewView.alpha = 1.0f;
    }
}


- (void)tapCancel {
    [self stop];

    if ([_delegate respondsToSelector:@selector(scannerViewController:didFinishWithMessages:)]) {
        [_delegate scannerViewController:self didFinishWithMessages:nil];
    }
}

- (void)sendMessages: (NSArray<NSString*>*)messages {
    [self stop];
    
    _cameraRollButton.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    if ([_delegate respondsToSelector:@selector(scannerViewController:didFinishWithMessages:)]) {
        __weak NSObject<ScannerDelegate> *weakDelegate = _delegate;
        [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer *timer) {
            [weakDelegate scannerViewController:self didFinishWithMessages:messages];
        }];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    int i = 0;
    
    NSMutableArray<NSString*> *messages = [NSMutableArray arrayWithCapacity:1];
    
    for (AVMetadataObject *metadataObject in metadataObjects) {
        i++;
        
        if (![metadataObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            continue;
        }
        
        AVMetadataMachineReadableCodeObject *readableObject = (AVMetadataMachineReadableCodeObject *)[_previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
        
        NSString *message = readableObject.stringValue;
        if (!message) { continue; }

        NSLog(@"Message: %d %@", i, message);
        [messages addObject:message];
        //continue;
        
        
        /*
         NSArray *corners = readableObject.corners;
         if (corners.count != 4) { continue; }

         if (shouldFinish) {
            [self showMessage:nil timeout:0.0f];
            
            CGPoint topLeft = pointFromArray(corners, 0);
            CGPoint bottomLeft = pointFromArray(corners, 1);
            CGPoint bottomRight = pointFromArray(corners, 2);
            CGPoint topRight = pointFromArray(corners, 3);
            NSLog(@"Points: %@ %@ %@ %@", NSStringFromCGPoint(topLeft), NSStringFromCGPoint(topRight), NSStringFromCGPoint(bottomRight), NSStringFromCGPoint(bottomLeft));
            
            break;
        
        } else if (!_messageTimer) {
        }
        */
    }
    
    NSLog(@"Messges: %@", messages);
    
    if ([_delegate respondsToSelector:@selector(scannerViewController:shouldFinishWithMessages:)]) {
        NSLog(@"FOO1");
        if ([_delegate scannerViewController:self shouldFinishWithMessages:messages]) {
            NSLog(@"FOO2");
            [self showMessage:nil timeout:0.0f];
            [self sendMessages:messages];
        
        } else if (messages.count) {
            [self showMessage:@"Unsupported QR code." timeout:1.0f];
        }
    }
}




#pragma mark - Image Picker

- (void)showCameraRoll {
    [self stop];

    _noCameraView.hidden = YES;

    _cameraRollButton.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;

    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:imagePicker animated:YES completion:^() {
        [self showMessage:nil timeout:0.0f];
        for (UIView *view in [_photoPreviewView subviews]) {
            [view removeFromSuperview];
        }
    }];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10.0f, 10.0f), NO, [UIScreen mainScreen].scale);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [UIColor colorWithHex:ColorHexNavigationBar].CGColor);
    UIRectFill(CGRectMake(0.0f, 0.0f, 10.0f, 10.0f));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(2.0f, 2.0f, 2.0f, 2.0f)];
    
    navigationController.navigationBar.titleTextAttributes = @{
                                                               NSForegroundColorAttributeName: [UIColor whiteColor]
                                                               };
    
    navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [navigationController.navigationBar setBackgroundImage:image
                                            forBarPosition:UIBarPositionTop
                                                barMetrics:UIBarMetricsDefault];
}

- (void)showSettings {
    NSLog(@"Show Settings");
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                       options:@{}
                             completionHandler:^(BOOL success) {
                                 NSLog(@"Success");
                             }];
}

- (void)requestPhotoPermissions {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Photo Library"
                                                                             message:@"To search QR codes, please enable access to your Photos."
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Settings"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *alertAction) {
                                                          [self showSettings];
                                                      }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *alertAction) { }]];

    alertController.preferredAction = [alertController.actions firstObject];
    
    [self presentViewController:alertController animated:YES completion:^() { }];
}

- (void)tapCameraRoll {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        [self showCameraRoll];
        
    } else if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        [self requestPhotoPermissions];
        
    } else if (status == PHAuthorizationStatusNotDetermined) {
        __weak ScannerViewController *weakSelf = self;
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                [weakSelf showCameraRoll];

            } else {
                [self requestPhotoPermissions];
            }
        }];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *originalImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    UIImage *displayImage = [UIImage imageWithCGImage:originalImage.CGImage
                                                scale:[UIScreen mainScreen].scale
                                          orientation:originalImage.imageOrientation];
    displayImage = [displayImage imageThatFits:_photoPreviewView.bounds.size scaleIfSmaller:YES];
    
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:displayImage];
    backgroundImageView.frame = _photoPreviewView.bounds;
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    [_photoPreviewView addSubview:backgroundImageView];
    
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    visualEffectView.frame = _photoPreviewView.bounds;
    visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_photoPreviewView addSubview:visualEffectView];
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:displayImage];
    imageView.backgroundColor = [UIColor clearColor];
    imageView.frame = _photoPreviewView.bounds;
    imageView.contentMode = UIViewContentModeCenter;
    [_photoPreviewView addSubview:imageView];
    
    
    // Find the QR Code data
    NSDictionary *qrDetectorOptions = @{ CIDetectorAccuracy:CIDetectorAccuracyHigh };
    CIDetector *qrDetector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:qrDetectorOptions];
    
    UIImage *searchImage = [originalImage imageThatFits:CGSizeMake(1000.0f, 1000.0f) scaleIfSmaller:NO];
    NSArray *features = [qrDetector featuresInImage:[CIImage imageWithCGImage:searchImage.CGImage]];
    
    if ([features count] == 0) {
        _cameraRollButton.enabled = YES;
        self.navigationItem.rightBarButtonItem.enabled = YES;

        [self showMessage:@"No QR code found." timeout:0.0f];
    
    } else {
        NSMutableArray<NSString*> *messages = [NSMutableArray arrayWithCapacity:1];
        for (NSInteger i = 0; i < features.count; i++) {
            [messages addObject:[[features objectAtIndex:i] messageString]];
        }
        
        if ([_delegate respondsToSelector:@selector(scannerViewController:shouldFinishWithMessages:)]) {
            if ([_delegate scannerViewController:self shouldFinishWithMessages:messages]) {
                [self sendMessages:messages];
            } else {
                _cameraRollButton.enabled = YES;
                self.navigationItem.rightBarButtonItem.enabled = YES;
                
                [self showMessage:@"Unsupported QR code." timeout:0.0f];
            }
        }
        
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];

    _noCameraView.hidden = _cameraConfigured;
    [self showMessage:nil timeout:0.0f];;

    _cameraRollButton.enabled = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;

    [self start];
}


@end
