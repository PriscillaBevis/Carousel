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

-(NSUInteger) numberOfItemsAvailableInCarouselViewController:(CarouselViewController*)carouselViewController;
-(UIView*) view

@optional

-(void) CarouselViewController:(CarouselViewController*)carouselViewController didSelectItemAtIndex:(int)index;

@end


@interface CarouselViewController : UIViewController

@property (nonatomic, assign) id <CarouselViewControllerDelegate> delegate;

@property (nonatomic, assign) BOOL blurSides;
@property (nonatomic, assign) NSUInteger numberOfItemsPerSide;


@end
