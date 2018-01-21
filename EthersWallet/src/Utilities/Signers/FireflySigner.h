/**
 *  MIT License
 *
 *  Copyright (c) 2018 Richard Moore <me@ricmoo.com>
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


#import "CloudKeychainSigner.h"

@interface FireflySigner : CloudKeychainSigner

+ (instancetype)writeToKeychain: (NSString*)keychainKey
                       nickname: (NSString*)nickname
                        address: (Address*)address
                      secretKey: (NSData*)secretKey
                       provider: (Provider*)provider;

/**
 *  The version of the Firefly Hardware Firmware
 *
 *  Firmware Version 0
 *    - No password
 *    - Private Key is burned in at compile time (no pairing)
 *    - Only supports v0 transactions
 *  Version 1 (tentative) - Password encrypted private key on Firefly; provided by Ethers Wallet at pair-time via ECDH
 *  Version 2 (tentative) - Password encrypted private key on Firefly; generated on Firefly (multisig-mode only)
 *
 *  Transaction Version: v0
 *    - Maximum length of 758 bytes
 *    - Maximum nonce is 0xffffffff (4 bytes)
 *    - Maximum gasLimit is 0xffffffff (4 bytes)
 *    - Maximum Gas Price is 0xffffffffff (5 bytes)
 *    - ChainId must be 0 or has an EIP155 v that fits into 1 byte
 */

@property (nonatomic, readonly) uint8_t version;

@end
