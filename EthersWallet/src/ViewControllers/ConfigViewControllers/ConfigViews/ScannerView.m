//
//  ScannerView.m
//  EthersWallet
//
//  Created by Richard Moore on 2018-01-11.
//  Copyright © 2018 ethers.io. All rights reserved.
//

#import "ScannerView.h"

#import <AVFoundation/AVFoundation.h>

#import "BoxView.h"


static NSString *getPointString(NSArray *points, NSInteger index) {
    CGPoint point;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)[points objectAtIndex:index], &point);
    return NSStringFromCGPoint(point);
}

#pragma mark - Simple Wrapper for Detected Objects

@interface DetectedCode: NSObject

@property (nonatomic, readonly) NSString *message;
@property (nonatomic, readonly) NSArray *points;

@end

@implementation DetectedCode

- (instancetype)initWithReadableCodeObject: (AVMetadataMachineReadableCodeObject*)readableCodeObject {
    self = [super init];
    if (self) {
        _message = readableCodeObject.stringValue;
        if (!_message) { return nil; }
        
        if (readableCodeObject.corners.count == 4) {
            NSArray *corners = readableCodeObject.corners;
            _points = @[
                            getPointString(corners, 0),
                            getPointString(corners, 1),
                            getPointString(corners, 2),
                            getPointString(corners, 3),
                            ];
        }
        
    }
    return self;
}

@end


#pragma mark - Scanner View

@interface ScannerView () <AVCaptureMetadataOutputObjectsDelegate>  {
    AVCaptureSession *_captureSession;
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    NSArray *_detectedCodes;
}

@property (nonatomic, readonly) BoxView *boxView;
@property (nonatomic, readonly) UIView *previewView;

@end

@implementation ScannerView


#pragma mark - Life-Cycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {

        _previewView = [[UIView alloc] initWithFrame:self.bounds];
        _previewView.alpha = 0.0f;
        _previewView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_previewView];

        _boxView = [[BoxView alloc] initWithFrame:_previewView.bounds];
        _boxView.alpha = 0.0f;
        
        [self addSubview:_boxView];
        
        _cameraReady = [self setupCamera];
    }
    return self;
}

- (BOOL)setupCamera {
    
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    if ([videoCaptureDevice lockForConfiguration:&error]) {
        if (videoCaptureDevice.isAutoFocusRangeRestrictionSupported) {
            [videoCaptureDevice setAutoFocusRangeRestriction:AVCaptureAutoFocusRangeRestrictionNear];
        }
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
    _previewLayer.frame = _previewView.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView.layer insertSublayer:_previewLayer atIndex:0];
    
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:metadataOutput];
    [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [metadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    
    return YES;
}

#pragma mark - Scanning

- (void)startAnimated: (BOOL)animated {
    _detectedCodes = nil;
    
    __weak ScannerView *weakSelf = self;
    
    void (^animate)() = ^() {
        weakSelf.boxView.alpha = 0.0f;
        weakSelf.previewView.alpha = 1.0f;
    };
    
    [self start];
    
    if (animated) {
        [UIView animateWithDuration:0.3f animations:animate];
    } else {
        animate();
    }
}

- (void)pauseScanningHighlight: (NSArray<NSString*>*)messages animated: (BOOL)animated {
    if (!_cameraReady) { return; }

    if (_scanning) {
        [self stop];
    }
    
    NSMutableArray <DetectedCode*> *matchingCodes = [NSMutableArray arrayWithCapacity:messages.count];
    
    NSMutableSet *remainingMessages = [NSMutableSet setWithArray:messages];
    for (NSString *message in messages) {
        // Duplicate message
        if (![remainingMessages containsObject:message]) { continue; }
        [remainingMessages removeObject:message];
        
        for (DetectedCode *detectedCode in _detectedCodes) {
            if ([detectedCode.message isEqualToString:message]) {
                [matchingCodes addObject:detectedCode];
                break;
            }
        }
    }
    
    switch (matchingCodes.count) {
        case 0:
            break;
        case 1:
            _boxView.points = [matchingCodes firstObject].points;
            break;
        case 2: {
            // @TODO: Allow more general organizations; since this is really only for
            // firefly, we know this will be an R and S QR code, side-by-side
            NSArray *r = [matchingCodes firstObject].points;
            NSArray *s = [matchingCodes lastObject].points;
            _boxView.points = @[
                                [r objectAtIndex:0],
                                [r objectAtIndex:1],
                                [s objectAtIndex:2],
                                [s objectAtIndex:3],
                                ];
            break;
        }
        default:
            // @TODO: We don't use this functionality; for now just highlight the first one
            _boxView.points = [matchingCodes firstObject].points;
            break;
    }
    
    __weak ScannerView *weakSelf = self;

    void (^animate)() = ^() {
        weakSelf.boxView.alpha = 1.0f;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
}

- (void)start {
    if (_scanning || !_cameraReady)  { return; }
    _scanning = YES;
    
    [_captureSession startRunning];
}

- (void)stop {
    if (!_scanning)  { return; }
    _scanning = NO;
    
    [_captureSession stopRunning];
}

/*
- (void)pauseScanning: (BOOL)pause visible: (BOOL)visible animated: (BOOL)animated {
    if (_cameraReady) {
        if (_scanning != pause) { return; }
        
        if (pause) {
            [self stop];
        } else {
            [self start];
        }
        
        if (_scanning == pause) { return; }
    }
    
    __weak FireflyScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.cameraPreview.alpha = (visible ? 1.0f: 0.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f delay:0.0f options:0 animations:animate completion:nil];
        
    } else {
        animate();
    }
}
*/

- (BOOL)sendMessage: (NSString*)message {
    NSLog(@"Message: %@", message);
    return NO;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    NSMutableArray *detectedCodes = [NSMutableArray arrayWithCapacity:metadataObjects.count];

    for (AVMetadataObject *metadataObject in metadataObjects) {
        if (![metadataObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            continue;
        }
        
        AVMetadataMachineReadableCodeObject *readableCodeObject = (AVMetadataMachineReadableCodeObject *)[_previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
        
        DetectedCode *detectedCode = [[DetectedCode alloc] initWithReadableCodeObject:readableCodeObject];
        if (!detectedCode) { continue; }

        [detectedCodes addObject:detectedCode];
    }
    
    [detectedCodes sortUsingComparator:^NSComparisonResult(DetectedCode *a, DetectedCode *b) {
        return [a.message compare:b.message];
    }];
    
    NSMutableArray *detectedMessages = [NSMutableArray arrayWithCapacity:detectedCodes.count];
    for (DetectedCode *detectedCode in detectedCodes) {
        [detectedMessages addObject:detectedCode.message];
    }
    
    if (![detectedMessages isEqual:_detectedMessages] && [_delegate respondsToSelector:@selector(scannerView:didDetectMessages:)]) {
        _detectedCodes = detectedCodes;
        _detectedMessages = detectedMessages;
        [_delegate scannerView:self didDetectMessages:detectedMessages];
    }
}
@end
