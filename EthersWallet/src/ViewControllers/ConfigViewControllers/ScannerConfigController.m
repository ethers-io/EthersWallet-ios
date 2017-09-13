//
//  ScannerConfigController.m
//  EthersWallet
//
//  Created by Richard Moore on 2017-08-23.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import "ScannerConfigController.h"

#import <AVFoundation/AVFoundation.h>
@import Photos;
@import PhotosUI;

#import <ethers/Payment.h>


#import "BoxView.h"
#import "CrossfadeLabel.h"
#import "RegEx.h"
#import "TransactionConfigController.h"
#import "UIImage+resize.h"
#import "Utilities.h"


#pragma mark - Photo

@interface Photo: NSObject

@property (nonatomic, readonly) PHAsset *asset;
@property (nonatomic, strong) UIImage *image;

@property (nonatomic, strong) UIImage *fullImage;

@property (nonatomic, copy) void (^onLoad)(Photo*);

@end


@implementation Photo

- (instancetype)initWithAsset: (PHAsset*)asset {
    self = [super init];
    if (self) {
        _asset = asset;
        
        __weak Photo *weakSelf = self;
        
        void (^handleImage)(UIImage*, NSDictionary*) = ^(UIImage *result, NSDictionary *info) {
            if (!result) { return; }
            weakSelf.image = result;
            if (weakSelf.onLoad) { weakSelf.onLoad(weakSelf); }
        };

        CGFloat scale = [UIScreen mainScreen].scale;
        CGSize thumbnailSize = CGSizeMake(100.0f * scale, 100.0f * scale);
        
        [[PHCachingImageManager defaultManager] requestImageForAsset:asset
                                                          targetSize:thumbnailSize
                                                         contentMode:PHImageContentModeDefault
                                                             options:nil
                                                       resultHandler:handleImage];
    }
    return self;
}

- (void)getPhoto: (void (^)(UIImage*))callback {

    __weak Photo *weakSelf = self;
    
    if (self.fullImage) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            callback(weakSelf.fullImage);
        });
        return;
    }

    CGSize fullSize = CGSizeMake(320.0f * 2.0f, 480.0f * 2.0f);

    void (^handleImage)(UIImage*, NSDictionary*) = ^(UIImage *image, NSDictionary *info) {
        weakSelf.fullImage = image;
        callback(image);
    };
    
    [[PHCachingImageManager defaultManager] requestImageForAsset:self.asset
                                                      targetSize:fullSize
                                                     contentMode:PHImageContentModeDefault
                                                         options:nil
                                                   resultHandler:handleImage];
    
}

@end


#pragma mark - PhotoView

@interface PhotoView : UIView

@property (nonatomic, readonly) Photo *photo;
@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, readonly) UIView *selectionHalo;

@property (nonatomic, assign) BOOL selected;
- (void)setSelected: (BOOL)selected animated: (BOOL)animated;

@end


@implementation PhotoView

- (void)addHalo: (CGRect)rect {
    UIView *view = [[UIView alloc] initWithFrame:rect];
    view.backgroundColor = [UIColor whiteColor];
    [_selectionHalo addSubview:view];
}

- (instancetype)initWithAsset: (PHAsset*)asset {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 100.0f)];
    if (self) {
        _photo = [[Photo alloc] initWithAsset:asset];
        //self.backgroundColor = [UIColor redColor];
        
        _selectionHalo = [[UIView alloc] initWithFrame:self.bounds];
        _selectionHalo.alpha = 0.0f;
        [self addHalo:CGRectMake(0.0f, 0.0f, 100.0f, 2.0f)];
        [self addHalo:CGRectMake(0.0f, 2.0f, 2.0f, 96.0f)];
        [self addHalo:CGRectMake(98.0f, 2.0f, 2.0f, 96.0f)];
        [self addHalo:CGRectMake(0.0f, 98.0f, 100.0f, 2.0f)];
        [self addSubview:_selectionHalo];
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(5.0f, 5.0f, 90.0f, 90.0f)];
        _imageView.clipsToBounds = YES;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.layer.borderColor = [UIColor colorWithWhite:0.7f alpha:1.0f].CGColor;
        _imageView.layer.borderWidth = 1.0f;
        [self addSubview:_imageView];
        
        __weak PhotoView *weakSelf = self;
        _photo.onLoad = ^(Photo *photo) {
            weakSelf.imageView.image = photo.image;
            weakSelf.imageView.frame = CGRectMake(5.0f, 5.0f, 90.0f, 90.0f);
        };
    }
    return self;
}

- (void)setSelected:(BOOL)selected {
    [self setSelected:selected animated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    _selected = selected;
    
    __weak PhotoView *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.selectionHalo.alpha = (selected ? 1.0f: 0.0f);
        weakSelf.transform = (selected ? CGAffineTransformMakeScale(1.1, 1.1): CGAffineTransformIdentity);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.3f animations:animate];
    } else {
        animate();
    }
}

@end


#pragma mark - Photo Preview View

/**
 *  PhotoPreviewView
 *
 *  Shows an image with padding that compliments the image.
 */

@interface PhotoPreviewView : UIView

@property (nonatomic, strong) UIImage *photo;
@property (nonatomic, assign) CGRect activeFrame;
@property (nonatomic, readonly) UIImageView *imageView;

@end


@implementation PhotoPreviewView {
    UIImageView *_backgroundView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _backgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:_backgroundView];
        
        UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        visualEffectView.frame = self.bounds;
        visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:visualEffectView];
        
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.backgroundColor = [UIColor clearColor];
        [self addSubview:_imageView];
    }
    return self;
}

- (void)setActiveFrame:(CGRect)activeFrame {
    [self setActiveFrame:activeFrame animated:NO];
}

- (void)setActiveFrame:(CGRect)activeFrame animated: (BOOL)animated {
    _activeFrame = activeFrame;
    
    __weak PhotoPreviewView *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.imageView.frame = activeFrame;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
}

- (void)setPhoto:(UIImage *)photo {
    _backgroundView.image = photo;
    _backgroundView.frame = self.bounds;
    _backgroundView.contentMode = UIViewContentModeScaleAspectFill;
    
    _imageView.image = photo;
    _imageView.frame = _activeFrame;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
}

@end


#pragma mark - Helper Functions

NSString *shortAddress(Address *address) {
    NSString *shortAddress = address.checksumAddress;
    return [NSString stringWithFormat:@"%@...%@", [shortAddress substringToIndex:10], [shortAddress substringFromIndex:34]];
}


#pragma mark - Prompt Types

#define PROMPT_SEARCH    0x20
#define PROMPT_PREVIEW   0x10
#define PROMPT_SPINNING  0x08
#define PROMPT_DRAWER    0x04
#define PROMPT_SCANNING  0x02
#define PROMPT_FOUND     0x01

typedef enum PromptType {
    PromptTypeNone             = 0x0,
    PromptTypeScanning         = (1 << 8) | (PROMPT_SCANNING | PROMPT_DRAWER | PROMPT_SEARCH),
    
    PromptTypeSearching        = (2 << 8) | (PROMPT_SPINNING | PROMPT_SEARCH),
    PromptTypeTyping           = (3 << 8) | (PROMPT_SEARCH),
    PromptTypeNameNotFound     = (4 << 8) | (PROMPT_SEARCH),
    
    PromptTypePhotoNotFound    = (5 << 8) | (PROMPT_PREVIEW | PROMPT_DRAWER),
    PromptTypeProcessingPhoto  = (6 << 8) | (PROMPT_PREVIEW | PROMPT_SPINNING | PROMPT_DRAWER),
    
    PromptTypeFoundScanner     = (10 << 8) | (PROMPT_FOUND),
    PromptTypeFoundPhoto       = (11 << 8) | (PROMPT_PREVIEW | PROMPT_FOUND),
    PromptTypeFoundSearch      = (12 << 8) | (PROMPT_FOUND),
    PromptTypeFoundPasteboard  = (13 << 8) | (PROMPT_FOUND),
} PromptType;


/*
 * Idea
 *  - If clipboard, show that instead of photos, with option to dismiss
 *
 *                Found Address in Clipboard
 *
*    III
 *   III        0x12345...000
 *   III
 */


#pragma mark - ScannerConfigController

@interface ScannerConfigController () <AVCaptureMetadataOutputObjectsDelegate, UISearchBarDelegate> {
    AVCaptureSession *_captureSession;
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    CrossfadeLabel *_infoIcon, *_infoText;
    
    UIScrollView *_photosScrollView;
    
    BOOL _scanning;
    BOOL _cameraReady;
    
    NSTimer *_flickerPromptTimer;
    
    NSTimer *_textChangeTimer;
    
    UIImpactFeedbackGenerator *_hapticGood, *_hapticBad;
    
}

@property (nonatomic, assign) PromptType promptType;

@property (nonatomic, copy) NSString *foundName;
@property (nonatomic, strong) Address *foundAddress;
@property (nonatomic, strong) BigNumber *foundAmount;

@property (nonatomic, strong) Payment *clipboardPayment;

@property (nonatomic, readonly) UISearchBar *searchBar;

@property (nonatomic, readonly) UIActivityIndicatorView *spinner;

@property (nonatomic, readonly) UIView *cameraPreview;
@property (nonatomic, readonly) PhotoPreviewView *photoPreview;

@property (nonatomic, readonly) PhotoView *selectedPhoto;

@property (nonatomic, readonly) UIView *photosView;

@property (nonatomic, readonly) UIView *rescanButton;
@property (nonatomic, readonly) UIView *clipboardButton;

@property (nonatomic, readonly) BoxView *boxView;

@property (nonatomic, readonly) NSMutableArray<PhotoView*> *photoViews;

@end



@implementation ScannerConfigController

#pragma mark - Life-Cycle

+ (instancetype)configWithSigner:(Signer *)signer {
    return [[ScannerConfigController alloc] initWithSigner:signer];
}

- (instancetype)initWithSigner: (Signer*)signer {
    self = [super init];
    if (self) {
        _signer = signer;

        _photoViews = [NSMutableArray array];

        __weak ScannerConfigController *weakSelf = self;
        
        self.navigationItem.prompt = @" ";
                
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer *timer) {
            
            // If we died, nuke the timer
            if (!weakSelf) {
                [timer invalidate];
                return;
            }
            
            Payment *payment = nil;
            
            if ([pasteboard hasStrings]) {
                for (NSString *string in [pasteboard strings]) {
                    payment = [Payment paymentWithURI:string];
                }
            }
            
            if (!payment && [pasteboard hasURLs]) {
                for (NSURL *url in [pasteboard URLs]) {
                    payment = [Payment paymentWithURI:[url absoluteString]];
                }
            }
            
            weakSelf.clipboardPayment = payment;
            [weakSelf updateClipboardAnimated:YES];
        }];
        
        _hapticBad = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        _hapticGood = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UI

- (void)updateClipboardAnimated: (BOOL)animated {
    BOOL enabled = (_promptType == PromptTypeScanning && _clipboardPayment);
    
    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.clipboardButton.alpha = (enabled ? 1.0f: 0.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
}

- (void)setSearchShowing: (BOOL)showing animated: (BOOL)animated {
    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.searchBar.alpha = (showing ? 1.0f: 0.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
}

- (void)setPhotoPreviewShowing: (BOOL)showing animated: (BOOL)animated {
    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.photoPreview.alpha = (showing ? 1.0f: 0.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
    
    if (!showing) {
        _selectedPhoto.selected = NO;
        _selectedPhoto = nil;
    }
}

- (void)setDrawerShowing: (BOOL)showing animated: (BOOL)animated {
    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        if (showing) {
            weakSelf.photosView.transform = CGAffineTransformMakeTranslation(0.0f, 0.0f);
        } else {
            CGFloat height = weakSelf.photosView.frame.size.height;
            weakSelf.photosView.transform = CGAffineTransformMakeTranslation(0.0f, height);
        }
        weakSelf.rescanButton.transform = weakSelf.photosView.transform;
        weakSelf.clipboardButton.transform = weakSelf.photosView.transform;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
}

- (void)setSpinningShowing: (BOOL)showing animated: (BOOL)animated {
    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.spinner.alpha = (showing ? 1.0f: 0.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
}

- (void)setRescanButtonEnabled: (BOOL)enabled animated: (BOOL)animated {
    _rescanButton.userInteractionEnabled = enabled;

    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.rescanButton.alpha = (enabled ? 1.0f: 0.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:animate];
    } else {
        animate();
    }
}

- (void)setAddress: (Address*)address name: (NSString*)name amount: (BigNumber*)amount promptType: (PromptType)promptType {
    _foundAddress = address;
    _foundName = [name lowercaseString];
    _foundAmount = amount;

    _promptType = promptType;
    
    BOOL hideText = YES;
    
    if (_promptType & PROMPT_FOUND) {
        if (!self.nextEnabled) {
            [_hapticGood impactOccurred];
        }
        
        if (_promptType == PromptTypeFoundPasteboard) {
            [_infoIcon setText:ICON_NAME_CLIPBOARD animated:YES];
            [_infoText setText:@"Found Clipboard Address" animated:YES];
            hideText = NO;
        
        } else if (_promptType == PromptTypeFoundSearch) {
            [_infoIcon setText:ICON_NAME_ACCOUNT animated:YES];
            [_infoText setText:@"Found Registered Address" animated:YES];
            hideText = NO;
        }
        
        if (name) {
            self.navigationItem.prompt = _foundName;
            
        } else if (address) {
            self.navigationItem.prompt = shortAddress(_foundAddress);
            
            __weak ScannerConfigController *weakSelf = self;
            
            [[_signer.provider lookupAddress:address] onCompletion:^(StringPromise *promise) {
                if (weakSelf.foundName || ![address isEqualToAddress:weakSelf.foundAddress]) {
                    return;
                }
                
                if (promise.value) {
                    [weakSelf setAddress:address name:promise.value amount:weakSelf.foundAmount promptType:weakSelf.promptType];
                }
            }];
        }
    
    } else if (promptType == PromptTypeScanning) {
        if (_cameraReady) {
            self.navigationItem.prompt = @"Scanning for QR code...";
        } else {
            self.navigationItem.prompt = @"Camera disabled";
        }
        _searchBar.text = @"";
        _boxView.points = nil;
        
    } else if (promptType == PromptTypeSearching) {
        self.navigationItem.prompt = @"Searching...";

    } else if (promptType == PromptTypeProcessingPhoto) {
        self.navigationItem.prompt = @"Analysing Photo...";

    } else if (promptType == PromptTypeNameNotFound) {
        self.navigationItem.prompt = @"ENS name not registered.";
        [_hapticBad impactOccurred];

    } else if (promptType == PromptTypePhotoNotFound) {
        self.navigationItem.prompt = @"No QR code found.";
        [_hapticBad impactOccurred];

    } else if (promptType == PromptTypeTyping) {
        self.navigationItem.prompt = @"Enter an ENS name";
    }
    
    self.nextEnabled = (_promptType & PROMPT_FOUND);
    
    [self setSpinningShowing:(_promptType & PROMPT_SPINNING) animated:YES];
    [self pauseScanning:!(_promptType & PROMPT_SCANNING)
                visible:(_promptType == PromptTypeScanning || _promptType == PromptTypeFoundScanner)
               animated:YES];
    [self setPhotoPreviewShowing:(_promptType & PROMPT_PREVIEW) animated:YES];
    [self setDrawerShowing:(_promptType & PROMPT_DRAWER) animated:YES];
    [self setRescanButtonEnabled:!(_promptType & PROMPT_SCANNING) animated:YES];
    [self setSearchShowing:(_promptType & PROMPT_SEARCH) animated:YES];
    
    if (_promptType & PROMPT_DRAWER) {
        CGRect frame = CGRectMake(0.0f, 84.0f, self.view.frame.size.width, self.view.frame.size.height - 84.0f - 160.0f);
        [_photoPreview setActiveFrame:frame animated:YES];
    } else {
        CGRect frame = CGRectMake(0.0f, 84.0f, self.view.frame.size.width, self.view.frame.size.height - 84.0f);
        [_photoPreview setActiveFrame:frame animated:YES];
    }
    
    [self updateClipboardAnimated:YES];
    
    if (hideText) {
        [_infoIcon setText:@"" animated:YES];
        [_infoText setText:@"" animated:YES];
    }
    
    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        if (weakSelf.promptType & PROMPT_FOUND) {
            weakSelf.boxView.alpha = (weakSelf.promptType == PromptTypeFoundScanner) ? 1.0f: 0.0f;
        } else {
            weakSelf.boxView.alpha = 0.0f;
        }
    };
    
    [UIView animateWithDuration:0.5f animations:animate];
}

- (void)dismissFirstResponder {
    if ([_searchBar isFirstResponder]) {
        [_searchBar resignFirstResponder];
    }
}

- (void)didTapPrompt: (UIGestureRecognizer*)gestureRecognizer {
    if (!_foundAddress || !_foundName) { return; }
    
    if ([self.navigationItem.prompt isEqualToString:_foundName]) {
        self.navigationItem.prompt = shortAddress(_foundAddress);
    } else {
        self.navigationItem.prompt = _foundName;
    }
}


#pragma mark - View Life-Cycle

- (UIView*)addButtonTitle: (NSString*)title action: (SEL)action {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 60.0f, 60.0f)];
    view.clipsToBounds = YES;
    view.layer.borderColor = [UIColor colorWithWhite:0.85f alpha:1.0f].CGColor;
    view.layer.borderWidth = 2.0f;
    view.layer.cornerRadius = 30.0f;
    [self.view addSubview:view];
    
    UINavigationBar *background = [[UINavigationBar alloc] initWithFrame:view.bounds];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.barStyle = UIBarStyleBlack;
    background.transform = CGAffineTransformMakeRotation(M_PI);
    [view addSubview:background];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = view.bounds;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont fontWithName:FONT_ETHERS size:30.0f];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button setTitleColor:[UIColor colorWithWhite:0.8f alpha:1.0f] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithWhite:0.8f alpha:0.4f] forState:UIControlStateHighlighted];
    [view addSubview:button];

    return view;
}

- (void)loadView {
    [super loadView];
    
    UIView *searchAccessoryView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
    {
        searchAccessoryView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        searchAccessoryView.backgroundColor = [UIColor colorWithWhite:0.95f alpha:1.0f];
        
        UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 0.5f)];
        topBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        topBorder.backgroundColor = [UIColor darkGrayColor];
        [searchAccessoryView addSubview:topBorder];
        
        UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0.0f, searchAccessoryView.frame.size.height - 0.5f, 320.0f, 0.5f)];
        bottomBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        bottomBorder.backgroundColor = [UIColor darkGrayColor];
        [searchAccessoryView addSubview:bottomBorder];
        
        UIButton *doneButton = [Utilities ethersButton:@"X" fontSize:17.0f color:0x5555ff];
        doneButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        doneButton.titleLabel.font = [UIFont fontWithName:FONT_MEDIUM size:17.0f];
        doneButton.frame = CGRectMake(searchAccessoryView.frame.size.width - 70.0f, 0.0f, 70.0f, 50.0f);
        [doneButton setTitle:@"Done" forState:UIControlStateNormal];
        [doneButton addTarget:self action:@selector(dismissFirstResponder) forControlEvents:UIControlEventTouchUpInside];
        [searchAccessoryView addSubview:doneButton];
    }

    self.nextEnabled = NO;
    self.nextTitle = @"Next";

    {
        UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 180.0f, 44.0f + 20.0f + 20.0f)];
        [titleView addSubview:_spinner];
        
        UIView *tapDetector = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 180.0f, 44.0f + 20.0f)];
        [tapDetector addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapPrompt:)]];
        [titleView addSubview:tapDetector];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _spinner.alpha = 0.0f;
        _spinner.frame = CGRectMake(0.0f, 0.0f, 34.0f, 34.0f);
        _spinner.center = CGPointMake(titleView.frame.size.width / 2.0f, titleView.frame.size.height / 2.0f);
        [titleView addSubview:_spinner];
        [_spinner startAnimating];

        self.navigationItem.titleView = titleView;
    }

    
    CGSize size = self.view.frame.size;
    
    _infoIcon = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(0.0f, size.height / 2.0f - 70.0f, size.width, 70.0f)];
    _infoIcon.duration = 0.5f;
    _infoIcon.font = [UIFont fontWithName:FONT_ETHERS size:60.0f];
    _infoIcon.textAlignment = NSTextAlignmentCenter;
    _infoIcon.textColor = [UIColor whiteColor];
    [self.view addSubview:_infoIcon];

    _infoText = [[CrossfadeLabel alloc] initWithFrame:CGRectMake(40.0f, size.height / 2.0f + 20.0f, size.width - 80.0f, 20.0f)];
    _infoText.duration = 0.5f;
    _infoText.font = [UIFont fontWithName:FONT_NORMAL size:17.0f];
    _infoText.textAlignment = NSTextAlignmentCenter;
    _infoText.textColor = [UIColor whiteColor];
    [self.view addSubview:_infoText];

    UIView *previewBackground = [[UIView alloc] initWithFrame:self.view.bounds];
    previewBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:previewBackground];
    
    [previewBackground addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(dismissFirstResponder)]];
    
    _cameraPreview = [[UIView alloc] initWithFrame:previewBackground.bounds];
    _cameraPreview.alpha = 0.0f;
    _cameraPreview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [previewBackground addSubview:_cameraPreview];

    _photoPreview = [[PhotoPreviewView alloc] initWithFrame:previewBackground.bounds];
    _photoPreview.alpha = 0.0f;
    [previewBackground addSubview:_photoPreview];
    
    _boxView = [[BoxView alloc] initWithFrame:previewBackground.bounds];
    _boxView.alpha = 0.0f;
    
    [previewBackground addSubview:_boxView];
    
    _cameraReady = [self setupCamera];
    
    // Notify the user if their camera is disabled
    if (!_cameraReady) {
        UILabel *enableCamera = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 0.0f, 320.0f - 80.0f, 100.0f)];
        enableCamera.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        enableCamera.center = CGPointMake(_cameraPreview.frame.size.width / 2.0f, _cameraPreview.frame.size.height / 2.0f);
        enableCamera.font = [UIFont fontWithName:FONT_BOLD size:16.0f];
        enableCamera.numberOfLines = 3;
        enableCamera.text = @"Please enable the camera in your settings to scan QR codes.";
        enableCamera.textAlignment = NSTextAlignmentCenter;
        enableCamera.textColor = [UIColor whiteColor];
        [_cameraPreview addSubview:enableCamera];
    }

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(25.0f, 106.0f, size.width - 50.0f, 44.0f)];
    _searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _searchBar.barStyle = UIBarStyleBlack;
    _searchBar.delegate = self;
    _searchBar.keyboardType = UIKeyboardTypeEmailAddress;
    _searchBar.placeholder = @"Lookup ENS name";
    _searchBar.returnKeyType = UIReturnKeySearch;
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.tintColor = [UIColor whiteColor];

    [self.view addSubview:_searchBar];

    _photosView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, size.height - 160.0f, size.width, 160.0f)];
    _photosView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_photosView];

    // Use a navigation bar for the same blur effect (flip it for a top shadow)
    {
        UINavigationBar *background = [[UINavigationBar alloc] initWithFrame:_photosView.bounds];
        background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        background.barStyle = UIBarStyleBlack;
        background.transform = CGAffineTransformMakeRotation(M_PI);
        [_photosView addSubview:background];
    }
    
    _rescanButton = [self addButtonTitle:ICON_NAME_CAMERA action:@selector(didTapRestart:)];
    _rescanButton.alpha = 0.0f;
    _rescanButton.center = CGPointMake(size.width - 30.0f - 15.0f, size.height - 160.0f - 30.0f - 15.0f);

    _clipboardButton = [self addButtonTitle:ICON_NAME_CLIPBOARD action:@selector(didTapClipboard:)];
    _clipboardButton.alpha = 0.0f;
    _clipboardButton.center = CGPointMake(30.0f + 15.0f, size.height - 160.0f - 30.0f - 15.0f);

    _photosScrollView = [[UIScrollView alloc] initWithFrame:_photosView.bounds];
    _photosScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _photosScrollView.contentSize = CGSizeMake(size.width, 500.0f);
    [_photosView addSubview:_photosScrollView];
    
    [self updatePhotos];
}

/*
 PHAuthorizationStatusNotDetermined = 0, // User has not yet made a choice with regards to this application
 PHAuthorizationStatusRestricted,        // This application is not authorized to access photo data.
 // The user cannot change this application’s status, possibly due to active restrictions
 //   such as parental controls being in place.
 PHAuthorizationStatusDenied,            // User has explicitly denied this application access to photos data.
 PHAuthorizationStatusAuthorized         // User has authorized this application to access photos data.
 */
- (void)updatePhotos {
    PHAuthorizationStatus status = PHPhotoLibrary.authorizationStatus;

    if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        
        UILabel *enablePhotos = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 0.0f, 320.0f - 80.0f, 100.0f)];
        enablePhotos.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        enablePhotos.center = CGPointMake(_photosView.frame.size.width / 2.0f, _photosView.frame.size.height / 2.0f);
        enablePhotos.font = [UIFont fontWithName:FONT_BOLD size:16.0f];
        enablePhotos.numberOfLines = 3;
        enablePhotos.text = @"Please enable photos in your settings to scan QR codes from your camera roll.";
        enablePhotos.textAlignment = NSTextAlignmentCenter;
        enablePhotos.textColor = [UIColor whiteColor];
        [_photosView addSubview:enablePhotos];
    
    } else if (status == PHAuthorizationStatusNotDetermined) {
        __weak ScannerConfigController *weakSelf = self;
        
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusNotDetermined) {
                // This should never happen, but if it does, prevent infinite-loop
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^() {
                [weakSelf updatePhotos];
            });
        }];

    } else {
        __weak ScannerConfigController *weakSelf = self;

        // Most recent 100 photos
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.fetchLimit = 36;
        options.sortDescriptors = @[
                                    [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO],
                                    ];
        
        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
        for (PHAsset *asset in fetchResult) {
            [weakSelf.photoViews addObject:[[PhotoView alloc] initWithAsset:asset]];
        }

        int columns = 2;
        if (self.view.frame.size.width > 320.0f) { columns = 3; }
        
        CGFloat padding = 14.0f;
        CGFloat dx = (self.view.frame.size.width - 2.0f * padding) / columns;
        
        NSInteger index = -1;
        for (PhotoView *photoView in _photoViews) {
            index++;
            photoView.center = CGPointMake(padding + dx / 2.0f + (index % columns) * dx, padding + dx / 2.0f + (index / columns) * dx);
            [_photosScrollView addSubview:photoView];
            [photoView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapPhoto:)]];
        }
        
        CGFloat height = padding * 2.0f + ceilf(_photoViews.count / columns) * dx;
        _photosScrollView.contentSize = CGSizeMake(_photosScrollView.frame.size.width, height);
    }
}

- (void)didTapClipboard: (UIButton*)button {
    if (_clipboardPayment) {
        [self setAddress:_clipboardPayment.address name:nil amount:_clipboardPayment.amount promptType:PromptTypeFoundPasteboard];
    }
}

- (void)didTapRestart: (UIButton*)button {
    [self setAddress:nil name:nil amount:nil promptType:PromptTypeScanning];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    /*
    Payment *payment = [self checkPasteboard];
    if (payment) {
        NSLog(@"Payment: %@", payment);
    }
     */
}


#pragma mark - Photos

NSString *flipYAndScale(CGPoint point, UIImage *baseImage, UIImage *targetImage) {
    CGFloat baseHeight = baseImage.size.height * baseImage.scale;
    point.y = baseHeight - point.y;
    
    CGFloat deltaSize = targetImage.size.height / baseHeight;
    
    point.x *= deltaSize;
    point.y *= deltaSize;
    
    return NSStringFromCGPoint(point);
}

- (void)didTapPhoto: (UITapGestureRecognizer*)tapGestureRecognizer {
    PhotoView *photoView = (PhotoView*)tapGestureRecognizer.view;
    if (![photoView isKindOfClass:[PhotoView class]]) { return; }
    
    if (_selectedPhoto) {
        [_selectedPhoto setSelected:NO animated:YES];
    }
    
    if (_selectedPhoto == photoView) {
        _selectedPhoto = nil;
        [self setAddress:nil name:nil amount:nil promptType:PromptTypeScanning];
        return;
    }
    
    _selectedPhoto = photoView;
    [_selectedPhoto setSelected:YES animated:YES];
    [self setAddress:nil name:nil amount:nil promptType:PromptTypeProcessingPhoto];

    __weak ScannerConfigController *weakSelf = self;
    _photoPreview.photo = _selectedPhoto.photo.image;
    
    [_selectedPhoto.photo getPhoto:^(UIImage *photo) {
        // Expired
        if (weakSelf.selectedPhoto != photoView) { return; }
        
        // Find the QR Code data
        NSDictionary *qrDetectorOptions = @{ CIDetectorAccuracy:CIDetectorAccuracyHigh };
        CIDetector *qrDetector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:qrDetectorOptions];
        
        // Create a smaller image to search (the CIDetector fails for large images)
        // Note: For iPhone 5S if this is 1000x1000 or more the @selector(featuresInImage:) fails
        UIImage *searchImage = [photo imageThatFits:CGSizeMake(999.0f, 999.0f) scaleIfSmaller:NO];
        
        NSArray *features = nil;
        if (searchImage.size.width > 320.0f && searchImage.size.height >= 320.0f) {
            features = [qrDetector featuresInImage:[CIImage imageWithCGImage:searchImage.CGImage]];
        }
        
        
        // These get filled in if we find a valid Ethereum payment
        UIImage *displayImage = nil;
        Payment *payment = nil;
        NSArray *corners = nil;

        for (CIQRCodeFeature *feature in features) {
            payment = [Payment paymentWithURI:feature.messageString];
            if (!payment) { continue; }
            
            // Build a full-sized image to show
            CGSize displaySize = self.view.frame.size;
            displaySize.height *= [UIScreen mainScreen].scale;
            displaySize.width *= [UIScreen mainScreen].scale;

            displayImage = [photo imageThatFits:displaySize scaleIfSmaller:YES];
            displayImage = [UIImage imageWithCGImage:displayImage.CGImage
                                               scale:[UIScreen mainScreen].scale
                                         orientation:displayImage.imageOrientation];
            
            // The points come back in a flipped-Y coordinate space (Quartz)
            corners = @[
                        flipYAndScale(feature.topLeft, searchImage, displayImage),
                        flipYAndScale(feature.topRight, searchImage, displayImage),
                        flipYAndScale(feature.bottomRight, searchImage, displayImage),
                        flipYAndScale(feature.bottomLeft, searchImage, displayImage),
                        ];
            // Done!
            break;
        }
        
        if (payment) {
            [weakSelf setAddress:payment.address name:nil amount:payment.amount promptType:PromptTypeFoundPhoto];
            
            // The image we will display
            UIImageView *imageView = [[UIImageView alloc] initWithImage:displayImage];
            
            // Overlay the transformed points as a BoxView on the image
            BoxView *boxView = [[BoxView alloc] initWithFrame:imageView.bounds];
            boxView.points = corners;
            [imageView addSubview:boxView];

            // Render the temporary view as an image and set it in the photo preview
            UIGraphicsBeginImageContextWithOptions(imageView.frame.size, YES, imageView.image.scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [imageView.layer renderInContext:context];
            weakSelf.photoPreview.photo = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
        } else {
            [weakSelf setAddress:nil name:nil amount:nil promptType:PromptTypePhotoNotFound];
            weakSelf.photoPreview.photo = photo;
        }
        
    }];

}

#pragma mark - Camera Scanner

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
    _previewLayer.frame = _cameraPreview.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_cameraPreview.layer insertSublayer:_previewLayer atIndex:0];
    
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:metadataOutput];
    [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [metadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    
    return YES;
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

- (void)startScanningAnimated:(BOOL)animated {
    [self setAddress:nil name:nil amount:nil promptType:PromptTypeScanning];
}

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
    
    __weak ScannerConfigController *weakSelf = self;
    void (^animate)() = ^() {
        weakSelf.cameraPreview.alpha = (visible ? 1.0f: 0.0f);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.5f delay:0.0f options:0 animations:animate completion:nil];
        
    } else {
        animate();
    }
}

- (BOOL)sendMessage: (NSString*)message {
    Payment *payment = [Payment paymentWithURI:message];
    if (payment) {
        [self setAddress:payment.address name:nil amount:payment.amount promptType:PromptTypeFoundScanner];
        return YES;
    }
    return NO;
}

NSString *getPointString(NSArray *points, NSInteger index) {
    CGPoint point;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)[points objectAtIndex:index], &point);
    return NSStringFromCGPoint(point);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    int i = 0;
    
    for (AVMetadataObject *metadataObject in metadataObjects) {
        i++;
        
        if (![metadataObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            continue;
        }
        
        AVMetadataMachineReadableCodeObject *readableObject = (AVMetadataMachineReadableCodeObject *)[_previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
        
        NSString *message = readableObject.stringValue;
        if (!message) { continue; }
        
        BOOL valid = [self sendMessage:message];
        if (valid && readableObject.corners.count == 4) {
            NSArray *corners = readableObject.corners;
            _boxView.points = @[
                                getPointString(corners, 0),
                                getPointString(corners, 1),
                                getPointString(corners, 2),
                                getPointString(corners, 3),
                                ];
        }
    }
}


#pragma mark - UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    // Continue searching if we gave up before
    if (!_foundAddress) {
        [self searchBar:searchBar textDidChange:searchBar.text];
    }
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [self clearTextChangeTimer];
    if (_foundAddress) {
        [self setAddress:_foundAddress name:_foundName amount:nil promptType:PromptTypeFoundSearch];
    } else {
        // Nothing found; resume scanning
        [self setAddress:_foundAddress name:_foundName amount:nil promptType:PromptTypeScanning];
    }
}

- (void)clearTextChangeTimer {
    if (!_textChangeTimer) { return; }

    [_textChangeTimer invalidate];
    _textChangeTimer = nil;
}

- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    static NSRegularExpression *validEnsPrefix = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        validEnsPrefix = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9.-]*$" options:0 error:&error];
        if (error) {
            NSLog(@"ScannerConfigController: Error creating regular expression - %@", error);
        }
    });
    
    NSString *newText = [searchBar.text stringByReplacingCharactersInRange:range withString:text];
    
    NSRange match = [validEnsPrefix rangeOfFirstMatchInString:newText options:0 range:NSMakeRange(0, newText.length)];
    return (match.location == 0 && match.length == newText.length);
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self clearTextChangeTimer];
    
    BOOL maybeValid = [searchText hasSuffix:@".eth"];
    /*
     @TODO: Support .test on Ropsten?
    if (_signer.provider.testnet && [searchText hasSuffix:@".test"]) {
        maybeValid = YES;
    }
     */
    
    if (maybeValid) {
        [self setAddress:nil name:nil amount:nil promptType:PromptTypeSearching];
    } else {
        [self setAddress:nil name:nil amount:nil promptType:PromptTypeTyping];
        return;
    }
    
    __weak ScannerConfigController *weakSelf = self;
    
    _textChangeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer *timer) {
        
        // Search expired (something new came along)
        if (![weakSelf.searchBar.text isEqualToString:searchText]) { return; }

        // Lookup the name
        [[weakSelf.signer.provider lookupName:searchText] onCompletion:^(AddressPromise *promise) {

            // Search expired (something new came along)
            if (![weakSelf.searchBar.text isEqualToString:searchText]) { return; }

            // Got an address!
            if (promise.value) {
                [weakSelf setAddress:promise.value name:searchText amount:nil promptType:PromptTypeFoundSearch];
                if ([searchBar isFirstResponder]) {
                    [searchBar resignFirstResponder];
                }
            
            } else {
                // Notify the user the name was no good
                if (weakSelf.promptType == PromptTypeSearching) {
                    [weakSelf setAddress:nil name:nil amount:nil promptType:PromptTypeNameNotFound];
                }
            }
        }];
    }];
}

@end
