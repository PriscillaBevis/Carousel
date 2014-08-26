//
//  CarouselViewController.m
//  CarouselDemo
//
//  Created by Priscilla Kim on 14/08/2014.
//  Copyright (c) 2014 PriscillaBevis. All rights reserved.
//

#import "CarouselViewController.h"


@interface CarouselViewController () <UIGestureRecognizerDelegate> {
    
    //this stuff is really just to 'cache' values so we don't have to keep recalculating commonly used values
    CGSize smallestSize;
    CGSize largestSize;
    CGSize segmentDiff; //difference in width/height for each segment
    CGFloat segmentCenterDiff; //difference in between each the centres of each segment
    
    CGFloat leftMostCentre;
    CGFloat rightMostCentre;
    CGFloat leftMostX;
    CGFloat rightMostX;
    CGFloat centreX;
    
    int maxVisibleItems;
    
    CGRect selfFrame;
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

-(id) initWithFrame:(CGRect)frame andDatasource:(id <CarouselViewControllerDatasource>)datasource {
    self = [super init];
    if (self) {
        _topBotMargin = 20;
        _leftRightMargin = 10;
        self.datasource = datasource;
        selfFrame = frame;
    }
    return self;
}

-(void) viewDidLoad {
    
    self.view.frame = selfFrame;
    self.view.backgroundColor = [UIColor grayColor];
    
    [self printRect:self.view.frame];
    
    if (!_datasource) {
        [self log:@"Cannot load without a datasource."];
        return;
    }

    if (_allowScrolling) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
        pan.delegate = self;
        [self.view addGestureRecognizer:pan];
    }

    [self createInitialViews];
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
        
        imageView.alpha = 0.9;
        
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

    
    //determine what the size increments should be.
    CGFloat widthDiff = largestSize.width - smallestSize.width;
    widthDiff = widthDiff/_numberOfItemsPerSide;
    CGFloat heightDiff = largestSize.height - smallestSize.height;
    heightDiff = heightDiff/_numberOfItemsPerSide;
    segmentDiff = CGSizeMake(widthDiff, heightDiff);
    
    //determine other commonly used values
    leftMostX = _leftRightMargin;
    rightMostX = self.view.frame.size.width - _leftRightMargin;
    leftMostCentre = _leftRightMargin + smallestSize.width/2;
    rightMostCentre = rightMostX - smallestSize.width/2;
    centreX = self.view.frame.size.width/2;
    
    segmentCenterDiff = (centreX - leftMostCentre)/_numberOfItemsPerSide;
    
    
    NSLog(@"smallest: %f %f", smallestSize.width, smallestSize.height);
    NSLog(@"largest: %f %f", largestSize.width, largestSize.height);
    
    NSLog(@"segment diff: %f %f", segmentDiff.width, segmentDiff.height);
}



#pragma mark - Gesture Delegates

-(void) didPan:(UIPanGestureRecognizer*)pan {
    
    CGPoint currPoint = [pan locationInView:self.view];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        _prevPoint = currPoint;
        
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        
        CGFloat diff = currPoint.x - _prevPoint.x;
        
        //determine if we need to add another view
//        if (!_spareView) {
//            UIView *prevView;
//            int position = 0;
//            int indexToAdd = (int)_currentIndex - (int)_numberOfItemsPerSide - 1;
//            
//            if (diff > 0) { //going to the right
//                if (indexToAdd < 0) {
//                    indexToAdd = (int)_numItems - 1;
//                }
//                prevView = _visibleViews[0];
//                
//            } else {
//                indexToAdd = (int)_currentIndex + 1;
//                position = (int)_numItems-1;
//                if (indexToAdd >= _numItems) {
//                    indexToAdd = indexToAdd - (int)_numItems;
//                }
//                prevView = _visibleViews.lastObject;
//                
//            }
//            
//            UIView *view = [self viewForItemAtIndex:indexToAdd];
//            CGRect frame = [self frameForViewAtPosition:position];
//            view.frame = frame;
//            view.alpha = 0;
//            _spareView = view;
//            
//            [self.view insertSubview:view belowSubview:prevView];
//        }

        //adjust existing views
        float percent = [self progressUntilNextSnapWithDiff:diff];
        
        for (int i = 0; i < _visibleViews.count; i++) {
            [self adjustFrameForView:_visibleViews[i] withDiff:diff progress:percent andIndex:i];
        }
        
        //determine if we need to pop off a view
        
        
        _prevPoint = currPoint;
        
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        [self snap];
        
    }
}

//given the new diff, calculate how far any view is from 'ticking' over to the next position
-(float) progressUntilNextSnapWithDiff:(CGFloat) diff {

    //grab the middle item
    UIView *centerItem = _visibleViews[_numberOfItemsPerSide];
    
    //adjust the center with the diff given
    CGFloat adjustedCenter = centerItem.center.x + diff;
    
    //determine it's percentage
    adjustedCenter = adjustedCenter - leftMostCentre;
    float xratio = fmodf(adjustedCenter, (float)segmentCenterDiff);

    float percent = xratio/segmentCenterDiff;
    
    //NSLog(@"%f %f = %f", adjustedCenter, segmentCenterDiff, xratio);
    
    return percent;
}

/**
 ** Used to adjust item frames while panning
 **/
-(void) adjustFrameForView:(UIView *)view withDiff:(CGFloat)diff progress:(float)percent andIndex:(int)index {
    
    CGRect frame = view.frame;
    CGPoint center = view.center;
    CGFloat width = frame.size.width;
    CGFloat height = frame.size.height;
    
    CGFloat adjustedX = center.x + diff;
    
    NSLog(@"\n\n\nINDEX: %d - %f %f", index, percent, diff);
    
    //adjust percentage for width/height useage.
    if (center.x + diff > centreX) {
        percent = 1 - percent;
        NSLog(@"adjusted percent: %f", percent);
    }
    
    //adjust width & height
    BOOL shouldFadeOut = (frame.origin.x < leftMostX || frame.origin.x > rightMostX) ? YES : NO;
    if (_shrinkSideItems) {
        
        int segment = (index > _numberOfItemsPerSide) ? _numberOfItemsPerSide - (index - _numberOfItemsPerSide) -1 : index;
        segment = (segment >= _numberOfItemsPerSide) ? segment-1 : segment;
        
        NSLog(@"segment: %d", segment);
        
        CGFloat adjustedWidth = (smallestSize.width + segmentDiff.width*segment) + segmentDiff.width*percent;
        CGFloat adjustedHeight = (smallestSize.height + segmentDiff.height*segment) + segmentDiff.height*percent;
        
        NSLog(@"%f %f %d %f %f", smallestSize.width, segmentDiff.width, segment, segmentDiff.width, percent);
        NSLog(@"adjusted: %f %f", adjustedWidth, adjustedHeight);
        
        if (shouldFadeOut) {
            //width and height rules differ. half the difference
            width = width + (adjustedWidth - width)/2;
            height = height + (adjustedHeight - height)/2;
            
            NSLog(@"should fade: %f %f", width, height);
            
        } else {
            width = adjustedWidth;
            height = adjustedHeight;
            
            NSLog(@"%f %f", adjustedWidth, adjustedHeight);
            NSLog(@"w h: %f %f", width, height);
        }
    }
    
    //adjust view origin
    CGFloat x = adjustedX - width/2;
    CGFloat y = center.y - height/2;
    
    NSLog(@"x y: %f %f", x, y);
    
    //adjust view alpha
//    if (shouldFadeOut) {
//        view.alpha = percent;
//    } else {
//        view.alpha = 0;
//    }
//    
//    //adjust z. i.e. which view is in front.
//    if ((view.frame.origin.x > centreX && x < centreX) ||
//        (view.frame.origin.x+view.frame.size.width < centreX && x+width > centreX)) {
//        [self.view bringSubviewToFront:view];
//    }
    
    //make the change!
    view.frame = CGRectMake(x, y, width, height);
}


//the left most position is 0.
-(CGRect) frameForViewAtPosition:(int)position {
    
    if (_shrinkSideItems) {
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
        
        
    } else {
        CGFloat leftMost = _leftRightMargin + smallestSize.width/2 + largestSize.width/2;
        CGFloat center = self.view.frame.size.width/2;
        CGFloat factorWidths = (center - leftMost)/_numberOfItemsPerSide;
        
        int x = leftMost + (position * factorWidths) - largestSize.width/2;
        int y = (self.view.frame.size.height - largestSize.height)/2;
        
        return CGRectMake(x, y, largestSize.width, largestSize.height);
    }
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
