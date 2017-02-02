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

#import "SharedDefaults.h"

NSString* UserDefaultsAddress = @"USER_SHARED_DEFAULTS_ADDRESS";
NSString* UserDefaultsBalamce = @"USER_SHARED_DEFAULTS_BALANCE";

@interface SharedDefaults () {
    NSUserDefaults *_userDefaults;
}

@end

@implementation SharedDefaults

+ (instancetype)sharedDefaults {
    static SharedDefaults *sharedDefaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDefaults = [[SharedDefaults alloc] init];
    });
    return sharedDefaults;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.io.ethers.app"];
    }
    return self;
}

- (BigNumber*)balance {
    NSString *balanceHex = [_userDefaults objectForKey:UserDefaultsBalamce];
    if (!balanceHex) { return [BigNumber constantZero]; }
    return [BigNumber bigNumberWithHexString:balanceHex];
}

- (void)setBalance:(BigNumber *)balance {
    [_userDefaults setObject:[balance hexString] forKey:UserDefaultsBalamce];
}

- (Address*)address {
    NSString *address = [_userDefaults objectForKey:UserDefaultsAddress];
    if (!address) { return nil; }
    return [Address addressWithString:address];
}

- (void)setAddress:(Address *)address {
    if (address) {
        [_userDefaults setObject:[address checksumAddress] forKey:UserDefaultsAddress];
    } else {
        [_userDefaults removeObjectForKey:UserDefaultsAddress];
    }
}


@end
