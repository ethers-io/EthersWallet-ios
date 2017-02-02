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

#import "IndexPathArray.h"

@interface IndexPathArray () {
    NSMutableDictionary<NSString*, NSMutableArray*> *_sections;
//    NSMutableDictionary *_indices;
}

@end


@implementation IndexPathArray

- (instancetype)init {
    self = [super init];
    if (self) {
        _sections = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSMutableArray<NSObject*>*)rowsForSection: (NSInteger)section {
    NSString *sectionKey = [[NSNumber numberWithInteger:section] description];
    NSMutableArray * rows = [_sections objectForKey:sectionKey];
    if (!rows) {
        rows = [NSMutableArray array];
        [_sections setObject:rows forKey:sectionKey];
    }
    return rows;
}

- (void)moveObjectAtIndexPath: (NSIndexPath*)fromIndexPath toIndexPath: (NSIndexPath*)toIndexPath {
    NSMutableArray *oldRows = [self rowsForSection:fromIndexPath.section];
    NSMutableArray *newRows = [self rowsForSection:toIndexPath.section];
    
    NSObject<NSCopying> *object = [oldRows objectAtIndex:fromIndexPath.row];
    [oldRows removeObjectAtIndex:fromIndexPath.row];
    
    [newRows insertObject:object atIndex:toIndexPath.row];
}

- (void)deleteObjectAtIndexPath:(NSIndexPath*)indexPath {
    NSMutableArray *rows = [self rowsForSection:indexPath.section];
    //NSObject *object = [rows objectAtIndex:indexPath.row];
    [rows removeObjectAtIndex:indexPath.row];
//    [_indices removeObjectForKey:object];
}

- (void)insert: (NSObject*)object atIndexPath:(NSIndexPath*)indexPath {
    [[self rowsForSection:indexPath.section] insertObject:object atIndex:indexPath.row];
}

- (NSIndexPath*)indexPathOfObject: (NSObject*)object {
    for (NSString *sectionKey in _sections) {
        NSInteger row = [[_sections objectForKey:sectionKey] indexOfObject:object];
        if (row != NSNotFound) {
            return [NSIndexPath indexPathForRow:row inSection:[sectionKey integerValue]];
        }
    }
    return nil;
}

- (NSObject*)objectAtIndexPath: (NSIndexPath*)indexPath {
    return [[self rowsForSection:indexPath.section] objectAtIndex:indexPath.row];
}

@end
