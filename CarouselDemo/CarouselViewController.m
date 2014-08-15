//
//  CarouselViewController.m
//  CarouselDemo
//
//  Created by Priscilla Kim on 14/08/2014.
//  Copyright (c) 2014 PriscillaBevis. All rights reserved.
//

#import "CarouselViewController.h"


@interface CarouselViewController () <UIGestureRecognizerDelegate> {
    
    CGSize smallestSize;
    CGSize largestSize;
    
    int maxVisibleItems;
}

@property (nonatomic, assign) NSUInteger numItems;
@property (nonatomic, assign) NSUInteger currentIndex;

//data
@property (nonatomic, retain) NSMutableArray *originalViews; //original views
@property (nonatomic, retain) NSMutableArray *cachedViews; //rasterized views
@property (nonatomic, retain) NSMutableArray *blurredViews; //only needed if we are actually blurring views.

//views
@property (nonatomic, retain) UIView *spareView;
@property (nonatomic, retain) NSMutableArray *visibleViews;

//used for panning state
@property (nonatomic, assign) CGPoint prevPoint;

@end



@implementation CarouselViewController

#pragma mark - Native Initialisation

-(id) init {
    self = [super init];
    if (self) {
        _topBotMargin = 20;
        _leftRightMargin = 10;
    }
    return self;
}

-(void) viewDidLoad {
    
    if (!_datasource) {
        [self log:@"Cannot load without a datasource."];
        return;
    }

    if (_allowScrolling) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
        pan.delegate = self;
        [self.view addGestureRecognizer:pan];
    }
}

-(void) viewWillAppear:(BOOL)animated {
    [self createInitialViews];
}

-(void) viewWillDisappear:(BOOL)animated {
    
}


#pragma mark - Carousel Initialisation

-(void) clearViews {
    
}

-(void) createInitialViews {
    
    _numItems = [_datasource numberOfItemsAvailableInCarouselViewController:self];
    
    //cannot have a looping carousel that doesn't have enough items to fill number of items desired on screen at one time.
    if (_loopInfinitely && ((_numberOfItemsPerSide*2 + 1) > _numItems)) {
        [self logErrorWithText:@"Number of items available does not correlate to number of items desired on screen at one time. Set 'loopInfinitely' to false, add some more items, or reduce 'numberOfItemsPerSide'." andError:nil];
        return;
    }
    
    _originalViews = [[NSMutableArray alloc] initWithCapacity:_numItems];
    _cachedViews = [[NSMutableArray alloc] initWithCapacity:_numItems];
    if (_blurSideItems) {
        _blurredViews = [[NSMutableArray alloc] initWithCapacity:_numItems];
    }
    
    //determine largest/smallest sizes
    UIView *firstView = [_datasource carouselViewController:self viewForItemAtIndex:0];
    [_originalViews addObject:firstView];
    [self determineBaseSizes];
    
    //grab the first x items.
    int numItemsNeeded = _numberOfItemsPerSide*2 + 1;
    for (int i = 1; i < numItemsNeeded; i++) {
        UIView * view = [_datasource carouselViewController:self viewForItemAtIndex:i];
        [_originalViews addObject:view];
    }
    
    //turn them all into flat images
    [self rasterizeAndCacheViews];
    
    //display them on screen
    int i = 0;
    _visibleViews = [[NSMutableArray alloc] init];
    UIView *prevView = nil;
    for (UIView *view in _cachedViews) {
        
        CGRect frame = [self frameForViewAtPosition:i];
        view.frame = frame;
        view.tag = i;
        
        //add tap gesture
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(itemWasTapped:)];
        tap.delegate = self;
        [view addGestureRecognizer:tap];
        
        [_visibleViews addObject:view];
        if (i > _numberOfItemsPerSide) {
            [self.view insertSubview:view belowSubview:prevView];
        } else {
            [self.view addSubview:view];
        }
        
        prevView = view;
        i++;
    }
    
    _currentIndex = _numberOfItemsPerSide;
    maxVisibleItems = _numberOfItemsPerSide * 2 + 2;
}

//returns the rasterized view to size
-(UIView*) viewForItemAtIndex:(int)index {
    
    UIView *rawView = _originalViews[index];
    if (!rawView) {
        rawView = [_datasource carouselViewController:self viewForItemAtIndex:index];
        [_originalViews insertObject:rawView atIndex:index];
    }
    

    UIImageView *imageView = _cachedViews[index];
    if (!imageView) {
        imageView = [self imageViewForView:rawView];
        imageView.tag = index;
        [_cachedViews insertObject:imageView atIndex:index];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(itemWasTapped:)];
        tap.delegate = self;
        [imageView addGestureRecognizer:tap];
    }
    
    return imageView;
}

-(void) rasterizeAndCacheViews {
    
    for (UIView *view in _originalViews) {
        
        //convert to a flat image
        UIImage *image = [self viewAsImage:view];
        
        //save as the largest size needed.
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, largestSize.width, largestSize.height)];
        imageView.image = image;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        imageView.alpha = 0.8;
        
        [_cachedViews addObject:imageView];
    }
}

-(void) determineBaseSizes {
    
    UIView *view = _originalViews[0];
    
    CGFloat smallLargeRatio = 0.6;
    
    //this is the bases for the first ratio.
    CGFloat maxHeight = self.view.frame.size.height - (_topBotMargin * 2);
    CGFloat minHeight = (int) (maxHeight * 0.6);
    
    if (view.frame.size.height > maxHeight) {
        CGFloat ratio = maxHeight/view.frame.size.height;
        largestSize = CGSizeMake( (int)(view.frame.size.width * ratio), maxHeight);
        smallestSize = CGSizeMake((int)(view.frame.size.width * ratio * smallLargeRatio), minHeight);
        
    } else {
        largestSize = CGSizeMake(view.frame.size.width, view.frame.size.height);
        smallestSize = CGSizeMake((int)(view.frame.size.width * smallLargeRatio), (int)(view.frame.size.height * smallLargeRatio));
    }
    
    //throw up some placeholders so we can see.
    UIView *placeholder = [[UIView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - largestSize.width)/2,
                                                                   (self.view.frame.size.height - largestSize.height)/2,
                                                                   largestSize.width, largestSize.height)];
    placeholder.backgroundColor = [UIColor orangeColor];
    placeholder.alpha = 0.5;
    [self.view addSubview:placeholder];
    
    
    UIView *placeholder2 = [[UIView alloc] initWithFrame:CGRectMake(_leftRightMargin,
                                                                    (self.view.frame.size.height - smallestSize.height)/2,
                                                                    smallestSize.width, smallestSize.height)];
    placeholder2.backgroundColor = [UIColor orangeColor];
    placeholder2.alpha = 0.5;
    [self.view addSubview:placeholder2];

}



#pragma mark - Gesture Delegates

-(void) didPan:(UIPanGestureRecognizer*)pan {
    
    CGPoint currPoint = [pan locationInView:self.view];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        _prevPoint = currPoint;
        
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        
        CGFloat diff = currPoint.x - _prevPoint.x;
        NSLog(@"%f", diff);
        
        
        //determine if we need to add another view
        if (!_spareView) {
            UIView *prevView;
            int position = 0;
            int indexToAdd = (int)_currentIndex - (int)_numberOfItemsPerSide - 1;
            
            if (diff > 0) { //going to the right
                if (indexToAdd < 0) {
                    indexToAdd = (int)_numItems - 1;
                }
                prevView = _visibleViews[0];
                
            } else {
                indexToAdd = (int)_currentIndex + 1;
                position = (int)_numItems-1;
                if (indexToAdd >= _numItems) {
                    indexToAdd = indexToAdd - (int)_numItems;
                }
                prevView = _visibleViews.lastObject;
                
            }
            
            UIView *view = [self viewForItemAtIndex:indexToAdd];
            CGRect frame = [self frameForViewAtPosition:position];
            view.frame = frame;
            view.alpha = 0;
            _spareView = view;
            
            [self.view insertSubview:view belowSubview:prevView];
        }
        
        
        //determine how far along before we tick over.
        UIView *firstView = _visibleViews[0];
        CGFloat center = self.view.frame.size.width/2;
        CGFloat leftmost = _leftRightMargin + smallestSize.width/2;
        CGFloat factorWidths = (center - leftmost)/_numberOfItemsPerSide;
        CGPoint viewCenter = firstView.center;
        
        float ratio = (viewCenter.x - leftmost)/factorWidths;
        _spareView.alpha = ratio;
        
        //adjust existing views
        for (UIView *view in _visibleViews) {
            //shuffle each of the views over.
            [self adjustFrameForView:view withDiff:diff];
        }
        
        
        //determine if we need to pop off a view
        
        
        
        _prevPoint = currPoint;
        
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        [self snap];
        
    }
}


-(void) adjustFrameForView:(UIView *)view withDiff:(CGFloat)diff {
    
    CGPoint center = view.center;
    CGFloat leftmost = _leftRightMargin + smallestSize.width/2;
    
    
    
    
    
    
    
    CGRect frame = view.frame;
    
    //shuffle center across.
    CGPoint adjustedCenter = CGPointMake(center.x += diff, center.y += diff);
    
    //figure out how much to shrink by.
    CGFloat width = frame.size.width;
    CGFloat height = frame.size.height;
    
    if (_shrinkSideItems) {
        //leftMostCenter point
        CGFloat leftMost = _leftRightMargin + smallestSize.width/2;
        CGFloat center = self.view.frame.size.width/2;
        
        CGFloat scale;
        if (adjustedCenter.x > center) {
            CGFloat rightMost = self.view.frame.size.width - leftMost;
            scale = (rightMost - adjustedCenter.x) / (center - leftMost);
        } else {
            scale = adjustedCenter.x / (center - leftMost);
        }
    }

    //adjust for if last item
    
    
    //adjust for going off screen
    

}

//the left most position is 0.
-(CGRect) frameForViewAtPosition:(int)position {
    
    CGFloat widthDiff = largestSize.width - smallestSize.width;
    CGFloat heightDiff = largestSize.height - smallestSize.height;
    
    //determine where this view is in relation to the middle.
    NSUInteger middlePos = _numberOfItemsPerSide;
    NSUInteger lastIndex = _numberOfItemsPerSide*2;
    float endToMiddleRatio = (float)position / (float)middlePos;
    if (position > middlePos) {
        endToMiddleRatio = (float)(lastIndex - position) / (float)middlePos;
    }
    
    CGFloat width = smallestSize.width + (widthDiff * endToMiddleRatio);
    CGFloat height = smallestSize.height + (heightDiff * endToMiddleRatio);
    
    
    //left and top point using center anchors
    CGFloat leftMost = _leftRightMargin + smallestSize.width/2;
    CGFloat center = self.view.frame.size.width/2;
    
    CGFloat factorWidths = (center - leftMost)/_numberOfItemsPerSide;
    int x = (leftMost + position * factorWidths) - width/2;
    int y = (self.view.frame.size.height/2 - height/2);
    
    return CGRectMake(x, y, width, height);
}


-(void) snap {
    
}


-(void) itemWasTapped:(UITapGestureRecognizer*)tap {
    
    UIView *view =  tap.view;
    
    NSLog(@"did tap item: %d", view.tag);
    
    //check if this is the hero image.
    if (_currentIndex == view.tag) {
        if (_delegate && [_delegate respondsToSelector:@selector(carouselViewController:didSelectItemAtIndex:)]) {
            [_delegate carouselViewController:self didSelectItemAtIndex:view.tag];
        }
        
    } else { //select it instead
        [self jumpToItemAtIndex:view.tag animated:YES];
    }
}


#pragma mark - Item creation




#pragma mark - Controls

-(void) jumpToItemAtIndex:(int)index animated:(BOOL)animated {
    
}

-(void) scrollToNextItemAnimated:(BOOL)animated {
    
}

-(void) scrollToPreviousItemAnimated:(BOOL)animated {
    
}


#pragma mark - View Management

-(CGSize) recommendedLargestViewSize {
    return largestSize;
}

-(void) reloadViews {
    
}

-(void) refreshViewAtIndex:(int)index {
    
}


#pragma mark - Auto scrolling 

-(void) beginAutoScrolling:(NSTimeInterval)interval {
    
}

-(void) stopAutoScrolling {
    
}


#pragma mark - Image & View Manipulation

-(UIImage*) viewAsImage:(UIView*)view {
    
    UIGraphicsBeginImageContext(view.frame.size);
    [view.layer renderInContext: UIGraphicsGetCurrentContext()];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

-(UIImageView*) imageViewForView:(UIView*)view {
    
    UIImage *image = [self viewAsImage:view];

    //save as the largest size needed.
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, largestSize.width, largestSize.height)];
    imageView.image = image;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    imageView.alpha = 0.8;
    
    return imageView;
}

#pragma mark - Helpers

-(void) logErrorWithText:(NSString*)text andError:(NSError*)error {
    NSLog(@"PBCarousel::: Fatal Error: %@ %@", text, error);
}

-(void) log:(NSString*)text {
    NSLog(@"PBCarousel::: %@", text);
}

-(void) printRect:(CGRect) rect {
    NSLog(@"%f %f %f %f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

@end
