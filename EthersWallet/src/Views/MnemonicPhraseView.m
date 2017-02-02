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

#import "MnemonicPhraseView.h"

#import <ethers/Account.h>

#import "Utilities.h"

static NSDictionary<NSString*, NSArray<NSString*>*> *PrefixLookup = nil;

@interface MnemonicPhraseView () <UITextFieldDelegate> {
    NSArray<NSString*> *_words;
    
    NSMutableArray <UITextField*> *_textFields;
    
//    UITextField *_firstResponder;
    
    NSMutableArray <UIButton*> *_accessoryOptions;
    
    UIView *_accessoryView;
    
    NSString *_initialMnemonicPhrase;
}

@end

@implementation MnemonicPhraseView

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"spellcheck" withExtension:@"json"]];
        PrefixLookup = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            NSLog(@"WARNING: Failed to load Mnemonic Lookup Table (%@)", error);
        }
        
    });
}

+ (NSArray<NSString*>*)mnemonicWordsForPrefix:(NSString *)prefix {
    if (!prefix) { return @[]; }
    NSArray<NSString*> *result = [PrefixLookup objectForKey:[prefix lowercaseString]];
    if (!result) { result = @[]; }
    return result;
}

- (instancetype)initWithFrame:(CGRect)frame withPhrase: (NSString*)phrase {
    frame.size.height = 6.0f * 40.0f;
    if (phrase && ![Account isValidMnemonicPhrase:phrase]) { return nil; }

    self = [super initWithFrame:frame];
    if (self) {
        _accessoryOptions = [NSMutableArray arrayWithCapacity:3];
        _textFields = [NSMutableArray arrayWithCapacity:12];
        
        if (phrase) {
            _initialMnemonicPhrase = phrase;
            
            _words = [phrase componentsSeparatedByString:@" "];
            if ([_words count] != 12) { return nil; }
        }

        CGSize size = frame.size;
        
        _accessoryView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, 44.0f)];
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:_accessoryView.bounds];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        toolbar.userInteractionEnabled = NO;
        [_accessoryView addSubview:toolbar];
        
        for (int i = 0; i < 3; i++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(i * size.width / 3.0f, 0.0f, size.width / 3.0f, 44.0f);
            [button setTitleColor:[UIColor colorWithWhite:0.4f alpha:1.0f] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor colorWithWhite:0.4f alpha:0.3f] forState:UIControlStateHighlighted];
            [button addTarget:self action:@selector(tapOption:) forControlEvents:UIControlEventTouchUpInside];
            [_accessoryView addSubview:button];
            [_accessoryOptions addObject:button];
        }

        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 43.5f, _accessoryView.frame.size.width, 0.5f)];
        separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        separator.backgroundColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
        [_accessoryView addSubview:separator];

        
        NSDictionary *placeholderAttributes = @{
                                                NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:16],
                                                NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0f alpha:0.2],
                                                };
        
        float padding = 30.0f;
        if (size.width == 320.0f) { padding = 16.0f; }
        
        float width = ((size.width - 3 * padding) / 2.0f), height = 30.0f;
        for (int i = 0; i < 12; i++) {
            float x = padding;
            if (i / 6) { x += width + padding; }
            float y = (float)(i % 6) * 40.0f;

            NSString *placeholder = [NSString stringWithFormat:@"word #%d", i + 1];
            placeholder = @"___________";
            NSMutableAttributedString *attributedPlaceholder = [[NSMutableAttributedString alloc] initWithString:placeholder
                                                                                                      attributes:placeholderAttributes];

            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(x, y, 30.0f, height)];
            label.font = [UIFont fontWithName:FONT_NORMAL size:16.0f];
            label.text = [NSString stringWithFormat:@"%d.", i + 1];
            label.textAlignment = NSTextAlignmentRight;
            label.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
            [self addSubview:label];
            
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(x + 36.0f, y, width - 36.0f, height)];
            textField.attributedPlaceholder = attributedPlaceholder;
            textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
            textField.delegate = self;
            textField.font = [UIFont fontWithName:FONT_BOLD size:16.0f];
            textField.inputAccessoryView = _accessoryView;
            textField.tag = i;
            textField.text = @"";
            textField.textColor = [UIColor whiteColor];
            textField.tintColor = [UIColor colorWithWhite:1.0f alpha:0.8f];
            [self addSubview:textField];
            
            [textField addTarget:self action:@selector(updateTextField:) forControlEvents:UIControlEventEditingChanged];
            
            if (_words) {
                textField.text = [_words objectAtIndex:i];
            }
            
            // This must be set after the font is set (otherwise the font overrides our placeholder font)
            textField.attributedPlaceholder = attributedPlaceholder;

            [_textFields addObject:textField];
        }
        
        [self updateAccessoryViewPrefix:nil];
    }
    return self;
}

- (void)setMnemonicPhrase:(NSString *)mnemonicPhrase {
    NSArray<NSString*> *words = [mnemonicPhrase componentsSeparatedByString:@" "];
    if (![Account isValidMnemonicPhrase:mnemonicPhrase] || [words count] != 12) { return; }
    for (int i = 0; i < 12; i++) {
        [_textFields objectAtIndex:i].text = [words objectAtIndex:i];
    }
}

- (NSString*)mnemonicPhrase {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[_textFields count]];
    for (UITextField *textField in _textFields) {
        [result addObject:textField.text];
    }
    return [result componentsJoinedByString:@" "];
}

- (UITextField*)_firstResponder {
    for (UITextField *textField in _textFields ) {
        if ([textField isFirstResponder]) {
            return textField;
        }
    }
    return nil;
}

- (BOOL)becomeFirstResponder {
    return [[_textFields firstObject] becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    UITextField *firstResponder = [self _firstResponder];
    if (firstResponder) {
        return [firstResponder resignFirstResponder];
    }
    return NO;
}

- (BOOL)isFirstResponder {
    return ([self _firstResponder] != nil);
}

- (void)updateAccessoryViewPrefix: (NSString*)prefix {
    
    NSArray<NSString*> *words = @[];
    if (prefix.length) {
        words = [MnemonicPhraseView mnemonicWordsForPrefix:prefix];
        
    } else {
        prefix = @"-";
    }
    
    // If we only have on word, recommend it
    BOOL recommendFirstWord = ([words count] == 1);
    
    // If every word is a result of a typo and the first word looks good, recommend the first word
    if (!recommendFirstWord && [words count] && [[words firstObject] hasPrefix:prefix]) {
        BOOL hasPrefix = NO;
        for (int i = 1; i < [words count]; i++) {
            if ([[words objectAtIndex:i] hasPrefix:prefix]) {
                hasPrefix = YES;
                break;
            }
        }
        if (!hasPrefix) { recommendFirstWord = YES; }
    }
    
    for (int i = 0; i < 3; i++) {
        UIButton *button = [_accessoryOptions objectAtIndex:i];
        NSString *word = @"";
        if (i < [words count]) {
            word = [words objectAtIndex:i];
        }
        
        // If the word matches exactly, recommend it
        if ([word isEqualToString:prefix]) {
            recommendFirstWord = YES;
        }
        
        NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:word];
        
        NSRange range = [word rangeOfString:prefix];
        if (range.location == 0 && range.length) {
            [attributedTitle setAttributes:@{
                                             NSFontAttributeName: [UIFont fontWithName:FONT_BOLD size:15.0f],
                                             }
                                     range:range];
            if (range.length < word.length) {
                [attributedTitle setAttributes:@{
                                                 NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:15.0f],
                                                 }
                                         range:NSMakeRange(range.length, word.length - range.length)];
            }
        } else {
            [attributedTitle setAttributes:@{
                                             NSFontAttributeName: [UIFont fontWithName:FONT_NORMAL size:15.0f],
                                             }
                                     range:NSMakeRange(0, [word length])];
            
        }
        
        [button setAttributedTitle:attributedTitle forState:UIControlStateNormal];
    }
    
    if (recommendFirstWord) {
        UIButton *button = [_accessoryOptions firstObject];
        [button.layer removeAllAnimations];
        
        CABasicAnimation *animate = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
        animate.duration = 1.0;
        animate.fromValue = (__bridge id _Nullable)([UIColor whiteColor].CGColor);
        animate.toValue = (__bridge id _Nullable)([UIColor clearColor].CGColor);
        [button.layer addAnimation:animate forKey:@"recommend"];
    }
    
}

#pragma mark - UIButton

- (BOOL)tapOption: (UIButton*)sender {
    if (sender.currentAttributedTitle.string.length == 0) { return NO; }
    
    UITextField *textField = [self _firstResponder];
    textField.text = [sender currentAttributedTitle].string;
    
    if (textField.tag == 11) {
        [textField resignFirstResponder];

    } else {
        UITextField *nextTextfield = [_textFields objectAtIndex:(textField.tag + 1) % 12];
        [nextTextfield becomeFirstResponder];
    }

    [self updateTextField:textField];

    return YES;
}


#pragma mark - UITextFieldDelegate

- (void)updateTextField: (UITextField*)textField {
    [self updateAccessoryViewPrefix:textField.text];

    if ([_delegate respondsToSelector:@selector(mnemonicPhraseViewDidChange:)]) {
        [_delegate mnemonicPhraseViewDidChange:self];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSArray<NSString*> *words = [MnemonicPhraseView mnemonicWordsForPrefix:textField.text];
    if ([words count]) {
        [self tapOption:[_accessoryOptions firstObject]];
        [self updateTextField:textField];
    }
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self updateAccessoryViewPrefix:textField.text];
    textField.textColor = [UIColor whiteColor];
    
    if (textField.text.length) {
        [textField selectAll:nil];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.text.length && ![Account isValidMnemonicWord:textField.text]) {
        textField.textColor = [UIColor redColor];
    } else {
        textField.textColor = [UIColor whiteColor];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *text = [[textField.text stringByReplacingCharactersInRange:range withString:string] lowercaseString];
    
    // Pressed space
    if ([text isEqualToString:[textField.text stringByAppendingString:@" "]]) {
        NSArray<NSString*> *words = [MnemonicPhraseView mnemonicWordsForPrefix:textField.text];
        if ([words count]) {
            [self tapOption:[_accessoryOptions firstObject]];
        }
        
        return NO;
    }
/*
    [self updateAccessoryViewPrefix:text];
    [self updateTextField:textField];

    [self updateTextField:textField];
  */
    return YES;
}

@end
