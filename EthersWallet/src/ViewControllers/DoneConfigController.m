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

#import "DoneConfigController.h"

#import <ethers/Account.h>

#import "IconView.h"
#import "Utilities.h"


@interface DoneConfigController ()

@property (nonatomic, strong) NSString *json;

@end


@implementation DoneConfigController

+ (instancetype)doneWithAccount: (Account*)account password: (NSString*)password {
    return [[DoneConfigController alloc] initWithAccount:account password:password];
}

- (instancetype)initWithAccount:(Account *)account password: (NSString*)password {
    self = [super init];
    if (self) {
        _account = account;
        _password = password;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    self.navigationItem.hidesBackButton = YES;

    [self addFlexibleGap];
    UITextView *headerEncrypting = [self addHeadingText:@"Encrypting..."];
    
    [self addGap:20.0f];
    
    UITextView *message = [self addMarkdown:@"One moment please." fontSize:15.0f];
    
    [self addFlexibleGap];
    
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityView.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 44.0f);
    [activityView startAnimating];
    [self addView:activityView];
    
    [self addFlexibleGap];
    
    CGFloat top = [self addMarkdown:@"When protecting important data, such as your //backup phrase//, consider:"
                           fontSize:15.0f].frame.origin.y;
    [self addGap:15.0f];
    [self addIcons:@[
                     [IconView iconViewWithIcon:ICON_NAME_FIRES topTitle:@"" bottomTitle:@"FIRES"],
                     [IconView iconViewWithIcon:ICON_NAME_FLOODS topTitle:@"" bottomTitle:@"FLOODS"],
                     [IconView iconViewWithIcon:ICON_NAME_DAMAGE topTitle:@"" bottomTitle:@"DAMAGE"],
                     ]];
    [self addGap:15.0f];
    [self addIcons:@[
                     [IconView iconViewWithIcon:ICON_NAME_LOSS topTitle:@"" bottomTitle:@"LOSS"],
                     [IconView iconViewWithIcon:ICON_NAME_THEFT topTitle:@"" bottomTitle:@"THEFT"],
                     [IconView iconViewWithIcon:ICON_NAME_FAILURE topTitle:@"" bottomTitle:@"FAILURE"],
                     ]];
    
    [self addFlexibleGap];
    
    // HACK! This allows us to slide in a replacement header
    UILabel *headerDone = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 44.0f, self.view.frame.size.width, top - 44.0f)];
    headerDone.alpha = 0.0f;
    headerDone.backgroundColor = headerEncrypting.backgroundColor;
    headerDone.font = headerEncrypting.font;
    headerDone.tag = headerEncrypting.tag;
    headerDone.text = @"Account Ready!";
    headerDone.textAlignment = headerEncrypting.textAlignment;
    headerDone.textColor = headerEncrypting.textColor;
    headerDone.transform = CGAffineTransformMakeTranslation(200.0f, 0.0f);
    [headerEncrypting.superview addSubview:headerDone];
    
    self.nextEnabled = NO;
    self.nextTitle = @"Done";
    
    __weak DoneConfigController *weakSelf = self;
    
    [_account encryptSecretStorageJSON:_password callback:^(NSString *json) {
        weakSelf.json = json;
        
        if (weakSelf.didEncrypt) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                weakSelf.didEncrypt(self);
            });
        }
        
        void (^animate)() = ^ () {
            headerEncrypting.alpha = 0.0f;
            headerEncrypting.transform = CGAffineTransformMakeTranslation(-200.0f, 0.0f);
            
            headerDone.alpha = 1.0f;
            headerDone.transform = CGAffineTransformIdentity;
            
            message.alpha = 0.0f;
            message.transform = CGAffineTransformMakeTranslation(-200.0f, 0.0f);
            
            activityView.alpha = 0.0f;
            activityView.transform = CGAffineTransformMakeTranslation(-200.0f, 0.0f);
        };
        
        void (^complete)(BOOL) = ^(BOOL complete) {
            weakSelf.nextEnabled = YES;
        };
        
        [UIView animateWithDuration:0.5f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:animate
                         completion:complete];
    }];

}

@end
