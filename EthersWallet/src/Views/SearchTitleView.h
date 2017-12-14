//
//  SearchTitleView.h
//  EthersWallet
//
//  Created by Richard Moore on 2017-11-25.
//  Copyright © 2017 ethers.io. All rights reserved.
//

#import <UIKit/UIKit.h>

#define SEARCH_TITLE_HIDDEN_WIDTH       (140.0f)

@class SearchTitleView;


@protocol SearchTitleViewDelegate

@optional

- (void)searchTitleView: (SearchTitleView*)searchTitleView didChangeText: (NSString*)text;
- (void)searchTitleViewDidConfirm: (SearchTitleView*)searchTitleView;
- (void)searchTitleViewDidCancel: (SearchTitleView*)searchTitleView;

@end


@interface SearchTitleView : UIView

@property (nonatomic, weak) NSObject<SearchTitleViewDelegate> *delegate;

@property (nonatomic, readonly) NSString *searchText;

@property (nonatomic, assign) BOOL width;
- (void)setWidth: (CGFloat)width animated: (BOOL)animated;

@end
