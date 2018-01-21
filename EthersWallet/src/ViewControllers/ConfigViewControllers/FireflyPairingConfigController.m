//
//  FireflyPairingConfigController.m
//  EthersWallet
//
//  Created by Richard Moore on 2018-01-17.
//  Copyright © 2018 ethers.io. All rights reserved.
//

#import "FireflyPairingConfigController.h"

#import <ethers/SecureData.h>

#import "OutlineLabel.h"
#import "ScannerView.h"
#import "Utilities.h"


@interface FireflyPairingConfigController () <ScannerViewDelegate>

@end


@implementation FireflyPairingConfigController {
    ScannerView *_scannerView;
    UIImpactFeedbackGenerator *_hapticGood, *_hapticBad;
}


+ (instancetype)config {
    return [[FireflyPairingConfigController alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        {
            UILabel *titleLabel = [Utilities navigationBarTitleWithString:ICON_LOGO_FIREFLY];
            titleLabel.font = [UIFont fontWithName:FONT_ETHERS size:32.0f];
            self.navigationItem.titleView = titleLabel;
        }

        _hapticBad = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        _hapticGood = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    _scannerView = [[ScannerView alloc] initWithFrame:self.view.bounds];
    _scannerView.delegate = self;
    [self.view insertSubview:_scannerView atIndex:0];

    [self addFlexibleGap];

    OutlineLabel *details1 = [[OutlineLabel alloc] initWithFrame:CGRectMake(44.0f, 100.0f, self.view.frame.size.width - 88.0f, 60.0f)];
    details1.font = [UIFont fontWithName:FONT_NORMAL size:14.0f];
    details1.outlineColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
    details1.outlineWidth = 5.0f;
    details1.text = @"Press and hold the button on the Firefly while scanning the QR code.";
    details1.numberOfLines = 2;
    details1.textAlignment = NSTextAlignmentCenter;
    details1.textColor = [UIColor whiteColor];
    
    [self addView:details1];
    
    [self addGap:44.0f];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_scannerView startAnimated:animated];
}

- (void)scannerView:(ScannerView *)scannerView didDetectMessages:(NSArray<NSString *> *)messages {

    for (NSString *message in messages) {
        if (message.length != 76) { continue; }
        NSArray<NSString*> *comps = [message componentsSeparatedByString:@"/"];
        if (comps.count != 3) { continue; }
        if (![[comps objectAtIndex:0] isEqualToString:@"V0"]) { continue; }
        Address *address = [Address addressWithString:[comps objectAtIndex:1]];
        NSData *pairKey = [SecureData hexStringToData:[@"0x" stringByAppendingString:[comps objectAtIndex:2]]];
        if (!address || !pairKey || pairKey.length != 16) { continue; }
        
        [scannerView pauseScanningHighlight:@[ message ] animated:YES];
        
        if (_didDetectFirefly) {
            _didDetectFirefly(self, address, pairKey);
            break;
        }
    }
}

@end
