//
//  BLECast.h
//  BLECast
//
//  Created by Richard Moore on 2017-04-11.
//  Copyright © 2017 RicMoo. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLECast;


@protocol BLECastDelegate <NSObject>

@optional

- (void)bleCastDidBegin: (BLECast*)bleCast;
- (void)bleCast: (BLECast*)bleCast didHopPayload: (NSData*)payload index: (uint8_t)index;

@end


@interface BLECast : NSObject

- (instancetype)initWithKey:(NSData*)key data:(NSData*)data;

+ (instancetype)bleCastWithKey:(NSData*)key data:(NSData*)data;


@property (nonatomic, readonly) NSData *key;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) BOOL broadcasting;

@property (nonatomic, weak) NSObject<BLECastDelegate> *delegate;

- (void)start;
- (void)stop;

@end
