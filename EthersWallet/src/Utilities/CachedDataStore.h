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

#import <Foundation/Foundation.h>

/**
 *  CachedDataStore
 *
 *  Store and retreive values associated to keys, persistened on disk.
 *  All values are cached in memory and flushed to disk (on write) after
 *  100ms.
 *
 *  This class is thread-safe.
 */

@interface CachedDataStore : NSObject

+ (instancetype)sharedCachedDataStoreWithKey: (NSString*)key;

@property (nonatomic, readonly) NSString *key;

- (void)purgeData;
- (void)filterData: (BOOL (^)(CachedDataStore *dataStore, NSString *key))filterCallback;

- (NSArray<NSString*>*)allKeys;

- (NSTimeInterval)timeIntervalForKey: (NSString*)key;
- (BOOL)setTimeInterval: (NSTimeInterval)value forKey: (NSString*)key;

- (BOOL)boolForKey: (NSString*)key;
- (BOOL)setBool: (BOOL)value forKey: (NSString*)key;

- (NSInteger)integerForKey: (NSString*)key;
- (BOOL)setInteger: (NSInteger)value forKey: (NSString*)key;

- (float)floatForKey: (NSString*)key;
- (BOOL)setFloat: (float)value forKey: (NSString*)key;

- (NSString*)stringForKey: (NSString*)key;
- (BOOL)setString: (NSString*)value forKey: (NSString*)key;

- (BOOL)setArray: (NSArray*)value forKey:(NSString *)key;
- (NSArray*)arrayForKey: (NSString*)key;

- (BOOL)setObject: (NSObject*)value forKey: (NSString*)key;
- (NSObject*)objectForKey: (NSString*)key;

@end
