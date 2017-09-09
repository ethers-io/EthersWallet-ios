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

#import "CachedDataStore.h"

#import <ethers/SecureData.h>


@implementation CachedDataStore {
    NSMutableDictionary *_values;
    BOOL _dirty;
    NSTimer *_syncTimer;
    NSOperationQueue *_writeQueue;
    NSString *_filename;
}

NSMutableDictionary<NSString*, CachedDataStore*> *SharedCachedDataStores;

+ (instancetype)sharedCachedDataStoreWithKey: (NSString*)key {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SharedCachedDataStores = [NSMutableDictionary dictionary];
    });
    
    CachedDataStore *cachedDataStore = [SharedCachedDataStores objectForKey:key];
    if (!cachedDataStore) {
        cachedDataStore = [[CachedDataStore alloc] initWithKey:key];
        [SharedCachedDataStores setObject:cachedDataStore forKey:key];
    }
    
    return cachedDataStore;
}

- (instancetype)initWithKey: (NSString*)key {
    self = [super init];
    if (self) {
        _key = key;
        
        // This makes sure we don't care about weird characters in the key (like @"/")
        key = [[SecureData dataToHexString:[SecureData KECCAK256:[key dataUsingEncoding:NSUTF8StringEncoding]]] substringToIndex:18];
        
        // We want to serialize all writes
        _writeQueue = [[NSOperationQueue alloc] init];
        _writeQueue.maxConcurrentOperationCount = 1;
        _writeQueue.name = [@"WriteQueue-" stringByAppendingString:key];
        
        // Get a filename in the documents directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        _filename = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", key]];
        
        // Load any existing values
        _values = [[NSDictionary dictionaryWithContentsOfFile:_filename] mutableCopy];
        
        // If no existing values, initialize a new
        if (!_values) {
            _values = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

- (void)synchronize {
    @synchronized (_values) {
        if (_syncTimer) {
            [_syncTimer invalidate];
            _syncTimer = nil;
        }
        
        // Nothing new to commit
        if (!_dirty) { return; }
        
        // Create a local copy of the content to save to disk
        NSDictionary *values = [_values copy];

        // Queue up a write operation
        [_writeQueue addOperationWithBlock:^() {
            [values writeToFile:_filename atomically:YES];
        }];
        
        _dirty = NO;
    }

}

- (void)purgeData {
    @synchronized (_values) {
        [_values removeAllObjects];
        _dirty = YES;
        
        [self synchronize];
    }
}

- (void)filterData: (BOOL (^)(CachedDataStore *dataStore, NSString *key))filterCallback {
    @synchronized (self) {
        for (NSString *key in [_values allKeys]) {
            if (!filterCallback(self, key)) {
                [_values removeObjectForKey:key];
            }
        }
    }
}

- (NSArray<NSString*>*)allKeys {
    @synchronized (self) {
        return [_values allKeys];
    }
}

- (NSTimeInterval)timeIntervalForKey: (NSString*)key {
    return [(NSNumber*)[self objectForKey:key ensureType:[NSNumber class]] doubleValue];
}

- (BOOL)setTimeInterval: (NSTimeInterval)value forKey: (NSString*)key {
    return [self setObject:@(value) forKey:key];
}

- (BOOL)boolForKey: (NSString*)key {
    return [(NSNumber*)[self objectForKey:key ensureType:[NSNumber class]] boolValue];
}

- (BOOL)setBool: (BOOL)value forKey: (NSString*)key {
    return [self setObject:@(value) forKey:key];
}


- (NSInteger)integerForKey: (NSString*)key {
    return [(NSNumber*)[self objectForKey:key ensureType:[NSNumber class]] integerValue];
}

- (BOOL)setInteger: (NSInteger)value forKey: (NSString*)key {
    return [self setObject:@(value) forKey:key];
}


- (float)floatForKey: (NSString*)key {
    return [(NSNumber*)[self objectForKey:key ensureType:[NSNumber class]] floatValue];
}

- (BOOL)setFloat: (float)value forKey: (NSString*)key {
    return [self setObject:@(value) forKey:key];
}


- (NSString*)stringForKey: (NSString*)key {
    return (NSString*)[self objectForKey:key ensureType:[NSString class]];
}

- (BOOL)setString: (NSString*)value forKey: (NSString*)key {
    return [self setObject:value forKey:key];
}

- (BOOL)setArray: (NSArray*)value forKey:(NSString *)key {
    return [self setObject:value forKey:key];
}

- (NSArray*)arrayForKey: (NSString*)key {
    return (NSArray*)[self objectForKey:key ensureType:[NSArray class]];
}


- (BOOL)setObject: (NSObject*)value forKey: (NSString*)key {
    if ([[self objectForKey:key] isEqual:value]) {
        return NO;
    }

    @synchronized (_values) {
        if (value) {
            [_values setObject:value forKey:key];
        } else {
            [_values removeObjectForKey:key];
        }
        _dirty = YES;
        
        if (!_syncTimer) {
            _syncTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f
                                                          target:self
                                                        selector:@selector(synchronize)
                                                        userInfo:nil
                                                         repeats:NO];
        }
    }
    
    return YES;
}

- (NSObject*)objectForKey: (NSString*)key {
    @synchronized (_values) {
        return [_values objectForKey:key];
    }
}

- (NSObject*)objectForKey:(NSString *)key ensureType: (Class)class {
    NSObject *object = [self objectForKey:key];
    if (![object isKindOfClass:class]) { return nil; }
    return object;
}

//- (NSString*)description {
//    return [NSString stringWithFormat:@"<CachedDataStore >", _values];
//}

@end
