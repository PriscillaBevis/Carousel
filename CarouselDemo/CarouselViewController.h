//
//  CarouselViewController.h
//  CarouselDemo
//
//  Created by Priscilla Kim on 14/08/2014.
//  Copyright (c) 2014 PriscillaBevis. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CarouselViewController;


@protocol CarouselViewControllerDelegate <NSObject>

@optional
-(void) carouselViewController:(CarouselViewController*)carouselViewController didSelectItemAtIndex:(int)index;
-(void) carouselViewControllerDidBeginScrolling:(CarouselViewController *)carouselViewController;
-(void) carouselViewControllerDidEndScrolling:(CarouselViewController *)carouselViewController;
@end


@protocol CarouselViewControllerDatasource <NSObject>
-(NSUInteger) numberOfItemsAvailableInCarouselViewController:(CarouselViewController*)carouselViewController;
-(UIView*) carouselViewController:(CarouselViewController*)carouselViewController viewForItemAtIndex:(NSUInteger)index;
@end



/**
 ** Carousel View Controller
 ** 
 ** Assumptions - the views given are the same size! Cannot guarantee what will happen if views of different sizes are returned.
 **/


@interface CarouselViewController : UIViewController

@property (nonatomic, assign) id <CarouselViewControllerDelegate> delegate;
@property (nonatomic, assign) id <CarouselViewControllerDatasource> datasource;

//visual configurations
@property (nonatomic, assign) BOOL blurSideItems;
@property (nonatomic, assign) BOOL shrinkSideItems;
@property (nonatomic, assign) BOOL allowScrolling;
@property (nonatomic, assign) BOOL loopInfinitely;

@property (nonatomic, assign) NSUInteger numberOfItemsPerSide;
@property (nonatomic, assign) CGFloat topBotMargin;
@property (nonatomic, assign) CGFloat leftRightMargin;


-(id) initWithFrame:(CGRect)frame andDatasource:(id <CarouselViewControllerDatasource>)datasource;

//controls
-(void) jumpToItemAtIndex:(int)index animated:(BOOL)animated;
-(void) scrollToNextItemAnimated:(BOOL)animated;
-(void) scrollToPreviousItemAnimated:(BOOL)animated;

//view management
-(CGSize) recommendedLargestViewSize;
-(void) reloadViews;
-(void) refreshViewAtIndex:(int)index;

//auto scroll
-(void) beginAutoScrolling:(NSTimeInterval)interval;
-(void) stopAutoScrolling;

@end
