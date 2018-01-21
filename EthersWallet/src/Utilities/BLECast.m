//
//  BLECast.m
//  BLECast
//
//  Created by Richard Moore on 2017-04-11.
//  Copyright © 2017 RicMoo. All rights reserved.
//

#import "BLECast.h"

@import CoreBluetooth;

#import <CommonCrypto/CommonCryptor.h>

const uint8_t Zeros[] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

#define CRC24_INIT      0xb704ce
#define CRC24_POLY      0x1864cfb

// http://sunsite.icm.edu.pl/gnupg/rfc2440-6.html
uint32_t computeCrc(NSData *data) {
    uint8_t *bytes = (uint8_t*)data.bytes;
    uint16_t length = (uint16_t)data.length;
    
    uint32_t crc = CRC24_INIT;
    for (uint8_t i = 0; i < length; i++) {
        crc ^= ((uint32_t)bytes[i]) << 16;
        
        for (uint8_t j = 0; j < 8; j++) {
            crc <<= 1;
            if (crc & 0x1000000)
                crc ^= CRC24_POLY;
        }
    }
    
    return crc & 0xffffff;
}

int8_t applyShirnkwrap(NSData *key, NSMutableData *block) {
    uint8_t *bytes = [block mutableBytes];
    
    // Compute the CRC
    uint32_t crc = computeCrc([block subdataWithRange:NSMakeRange(3, 13)]);
    
    // Insert the CRC
    bytes[0] = (crc >> 16) & 0xff;
    bytes[1] = (crc >> 8) & 0xff;
    bytes[2] = (crc >> 0) & 0xff;

    // Extend and mask the CRC aross the payload (add some noise to prevent ECB revelaing patterns)
    for (uint8_t i = 3; i < 16; i++) {
        bytes[i] ^= (crc >> (i - 3));
    }

    // Encrypt the payload with the key
    size_t dataOutLength;
    CCCryptorStatus result = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionECBMode, key.bytes, 16, Zeros, bytes, 16, bytes, 16, &dataOutLength);
    
    // I don't think this can actually happen, but just in case
    if (result != kCCSuccess || dataOutLength != 16) { return -1; }

    // Flip the order of the bytes
    for (uint8_t i = 0; i < 8; i++) {
        uint8_t tmp = bytes[i];
        bytes[i] = bytes[15 - i];
        bytes[15 - i] = tmp;
    }
    
    return 0;
}


@interface BLECast () <CBPeripheralManagerDelegate>

@end


@implementation BLECast  {
    CBPeripheralManager *_peripheralManager;
    
    uint8_t _payloadIndex;
    NSMutableArray<CBUUID*> *_dataBlocks;
}

- (instancetype)initWithKey: (NSData*)key data:(NSData *)data {
    if (key.length != 16) { return nil; }
    
    self = [super init];
    
    if (self) {
        
        // Add a CRC for the entire messge
        if (data.length > 12) {
            NSMutableData *dataWithChecksum = [NSMutableData dataWithLength:3];
            uint8_t *bytes = [dataWithChecksum mutableBytes];

            uint32_t crc = computeCrc(data);
            bytes[0] = (crc >> 16) & 0xff;
            bytes[1] = (crc >> 8) & 0xff;
            bytes[2] = crc& 0xff;
            
            [dataWithChecksum appendData:data];
            data = [NSData dataWithData:dataWithChecksum];
        }
        
        _key = [NSData dataWithData:key];
        _data = data;
        
        _dataBlocks = [NSMutableArray array];

        NSMutableData *preamble = [NSMutableData dataWithLength:4];
        uint8_t *preambleBytes = (uint8_t*)[preamble mutableBytes];
        preambleBytes[0] = 0x00;
        preambleBytes[1] = 0x00;
        preambleBytes[2] = 0x00;
        preambleBytes[3] = 0x00;
        
        int chunkIndex = 0;
        int offset = 0;
        while (offset < data.length) {
            int payloadLength = MIN(12, (int)data.length - offset);
            
            NSMutableData *payload = [preamble mutableCopy];
            uint8_t *bytes = [payload mutableBytes];
            bytes[3] = chunkIndex++;
            
            // Too long, the chunk index has leaked into the partial flag
            if (bytes[3] & 0x40) { return nil; }
            
            [payload appendData:[data subdataWithRange:NSMakeRange(offset, payloadLength)]];
            
            if (payloadLength < 12) {
                [payload appendBytes:Zeros length:12 - payloadLength];
                bytes = [payload mutableBytes];
                
                bytes[3] |= 0x80 | 0x40;
                bytes[15] = payloadLength;
                
            } else if (offset + 12 >= data.length) {
                bytes = [payload mutableBytes];
                if (offset + 12 == data.length) {
                    bytes[3] |= 0x80;
                }
            }

            offset += 12;
            
            applyShirnkwrap(key, payload);
            
            [_dataBlocks addObject:[CBUUID UUIDWithData:payload]];
        }
    }
    
    return self;
}

+ (instancetype)bleCastWithKey: (NSData*)key data:(NSData *)data {
    return [[BLECast alloc] initWithKey:key data:data];
}

- (void)hopPayload {
    if (_peripheralManager.isAdvertising) { [_peripheralManager stopAdvertising]; }
    
    if (!_broadcasting) { return; }
    
    _payloadIndex = (_payloadIndex + 1) % _dataBlocks.count;
    CBUUID *payload = [_dataBlocks objectAtIndex:_payloadIndex];

    [_peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey:@[payload] }];
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        if ([_delegate respondsToSelector:@selector(bleCast:didHopPayload:index:)]) {
            [_delegate bleCast:self didHopPayload:[payload data] index:_payloadIndex];
        }
    });
    
    [NSTimer scheduledTimerWithTimeInterval:0.25f target:self selector:@selector(hopPayload) userInfo:nil repeats:NO];
}

- (void)start {
    if (_broadcasting) { return; }

    _broadcasting = YES;
    
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                                 queue:dispatch_get_main_queue()
                                                               options:@{}];
}

- (void)stop {
    if (!_broadcasting) { return; }

    _broadcasting = NO;
    
    if (_peripheralManager.isAdvertising) { [_peripheralManager stopAdvertising]; }
    _peripheralManager = nil;
}

#pragma mark - CBPeripheralManagerDelegate


- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    NSLog(@"didUpdateState: peripheral=%@", peripheral);
    
    if (peripheral.state == CBManagerStatePoweredOn) {
        [self hopPayload];
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(nullable NSError *)error {
    //NSLog(@"didStartAdvertising: peripheral=%@ error=%@", peripheral, error);
}

@end
