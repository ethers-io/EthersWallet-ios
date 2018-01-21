//
//  ScannerView.h
//  EthersWallet
//
//  Created by Richard Moore on 2018-01-11.
//  Copyright © 2018 ethers.io. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ScannerView;


@protocol ScannerViewDelegate

- (void)scannerView: (ScannerView*)scannerView didDetectMessages: (NSArray<NSString*>*)messages;

@end


@interface ScannerView : UIView

- (void)startAnimated: (BOOL)animated;
- (void)pauseScanningHighlight: (NSArray<NSString*>*)messages animated: (BOOL)animated;

@property (nonatomic, weak) NSObject<ScannerViewDelegate> *delegate;

@property (nonatomic, readonly) BOOL cameraReady;
@property (nonatomic, readonly) BOOL scanning;

@property (nonatomic, readonly) NSArray<NSString*> *detectedMessages;


@end
