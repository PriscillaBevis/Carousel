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
    
    CGSize smallestPossibleSize; //smaller than the smallestSize. Used to
    CGFloat smallestPossibleCenter;
    CGFloat largestPossibleCenter;
    
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
@property (nonatomic, assign) NSUInteger totalVisible;
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
    
    
    
    //can't see what's going on so place some markers up.
    CGRect square = CGRectMake(smallestPossibleCenter - 2, 0, 4, 8);
    
    UIView *marker = [[UIView alloc] initWithFrame:square];
    marker.backgroundColor = [UIColor redColor];
    [self.view addSubview:marker];
    
    square.origin.x = leftMostCentre -2;
    UIView *marker2 = [[UIView alloc] initWithFrame:square];
    marker2.backgroundColor = [UIColor redColor];
    [self.view addSubview:marker2];
    
    for (int i = 0; i < _totalVisible; i++) {
        
        square.origin.x += segmentCenterDiff;
        UIView *mark = [[UIView alloc] initWithFrame:square];
        mark.backgroundColor = [UIColor redColor];
        [self.view addSubview:mark];
    }
    
    square.origin.x = largestPossibleCenter -2;
    UIView *marker3 = [[UIView alloc] initWithFrame:square];
    marker3.backgroundColor = [UIColor redColor];
    [self.view addSubview:marker3];
    
    
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
    
    _originalViews = [self newPaddedArray];
    _cachedViews = [self newPaddedArray];
    if (_blurSideItems) {
        _blurredViews = [self newPaddedArray];
    }
    
    //determine largest/smallest sizes
    UIView *firstView = [_datasource carouselViewController:self viewForItemAtIndex:0];
    [_originalViews replaceObjectAtIndex:0 withObject:firstView];
    [self determineBaseSizes];
    
    //grab the first x items.
    int numItemsNeeded = _numberOfItemsPerSide*2 + 1;
    for (int i = 1; i < numItemsNeeded; i++) {
        UIView * view = [_datasource carouselViewController:self viewForItemAtIndex:i];
        [_originalViews replaceObjectAtIndex:i withObject:view];
    }
    
    //turn them all into flat images
    [self rasterizeAndCacheViews];
    
    //display them on screen
    _visibleViews = [[NSMutableArray alloc] init];
    UIView *prevView = nil;
    for (int i = 0; i < numItemsNeeded; i++) {
        UIView *view = _cachedViews[i];
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
    }
    
    _currentIndex = _numberOfItemsPerSide;
    maxVisibleItems = _numberOfItemsPerSide * 2 + 2;
}

-(NSMutableArray*) newPaddedArray {
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:_numItems];
    for (int i = 0; i < _numItems; i++) {
        [array addObject:[NSNull null]];
    }
    return array;
}

//returns the rasterized view to size
-(UIView*) viewForItemAtIndex:(int)index {
    
    UIView *rawView = [_originalViews objectAtIndex:index];
    if ([rawView isEqual:[NSNull null]]) {
        rawView = [_datasource carouselViewController:self viewForItemAtIndex:index];
        [_originalViews insertObject:rawView atIndex:index];
    }

    UIImageView *imageView = imageView = _cachedViews[index];
    if ([imageView isEqual:[NSNull null]]) {
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
    
    int i = 0;
    for (UIView *view in _originalViews) {
        if ([view isEqual:[NSNull null]]) {
            continue;
        }
        
        //convert to a flat image
        UIImage *image = [self viewAsImage:view];
        
        //save as the largest size needed.
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, largestSize.width, largestSize.height)];
        imageView.image = image;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.alpha = 0.9;
        
        [_cachedViews insertObject:imageView atIndex:i];
        i++;
    }
}

-(void) determineBaseSizes {
    
    UIView *view = _originalViews[0];
    
    _totalVisible = _numberOfItemsPerSide*2 +1;
    
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
    smallestPossibleSize = CGSizeMake(smallestSize.width * 2./3., smallestSize.height * 2./3.);
    
    smallestPossibleCenter = leftMostCentre - _leftRightMargin;
    largestPossibleCenter = rightMostCentre + _leftRightMargin;
}



#pragma mark - Gesture Delegates

-(void) didPan:(UIPanGestureRecognizer*)pan {
    
    CGPoint currPoint = [pan locationInView:self.view];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        _prevPoint = currPoint;
        
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        
        CGFloat diff = currPoint.x - _prevPoint.x;
        
        //determine if we need to add another view. There should always be at least one spare room.
        if (_visibleViews.count < (_totalVisible + 1)) {
            UIView *firstView = _visibleViews[0];
            int indexNeeded = firstView.tag;
            CGRect frame = CGRectMake(0, (self.view.frame.size.height - smallestPossibleSize.height)/2, smallestPossibleSize.width, smallestPossibleSize.height);
            
            if (diff > 0) { //going to the right
                indexNeeded --;
                if (indexNeeded < 0) {
                    indexNeeded = _numItems-1;
                }
                frame.origin.x = smallestPossibleCenter - smallestPossibleSize.width/2;
                
            } else { //going to the left
                UIView *lastView = _visibleViews.lastObject;
                indexNeeded = lastView.tag + 1;
                if (indexNeeded >= _numItems) {
                    indexNeeded = 0;
                }
                frame.origin.x = largestPossibleCenter - smallestPossibleSize.width/2;
            }
            
            UIView *newView = [self viewForItemAtIndex:indexNeeded];
            newView.frame = frame;
            newView = newView;
            newView.alpha = 0;
            [self.view insertSubview:newView atIndex:0];
            
            if (diff > 0) {
                [_visibleViews insertObject:newView atIndex:0];
            } else {
                [_visibleViews addObject:newView];
            }
            NSLog(@"Popping on %d", newView.tag);
        }

        //adjust existing views
        float percent = [self progressUntilNextSnapWithDiff:diff];
        
        for (int i = 0; i < _visibleViews.count; i++) {
            [self adjustFrameForView:_visibleViews[i] withDiff:diff progress:percent andIndex:i];
        }

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
    
    return percent;
}

/**
 ** Used to adjust item frames while panning
 **/
-(void) adjustFrameForView:(UIView *)view withDiff:(CGFloat)diff progress:(float)percent andIndex:(int)index {

    
    /*
     
     Three things to consider here
     
     1. The position ( of center)
        Find the centre and adjust by the diff.
        If the centre is < leftmost or > rightmost. Then diff it by some delta so that it doesn't go < smallestPOssibleLeft or > largest possible right
     
     
     2. The Size
        The size should be determined by the percentage the panel is from the centre point
        panelCenter - leftmost / actualCentre - leftmost = the percentage of the size
     
        If the panel center is past the middle point, the reverse needs to occur
        half size difference - (panelCenter - centrepoint) = the percentage of the size
     
        If the panel is < the leftmost or > rightmost, it needs to shrink even more
        If we want this to shrink at a lesser rate then we can do the same thing but on a smaller scale.
        panelCenter - smallestPossibleLeft / leftmost - smallestPOssibleLeft = the percentage of the size
        if > rightmost then just adjust
        size diff - (panelCenter - rightmost) / size diff = percentage of the size

     
     3. The alpha
        Assuming we want the alpha to = 1 unless it is fading out.
        if panelCenter < leftmost or > rightmost
        based on same percentages above adjust alpha = 0-1
     
        If alpha hits 0 - should remove from view
     
     */

    
    //1. The Position
    CGFloat sideGapWidth = leftMostCentre - smallestPossibleCenter;
    double sideRatio = sideGapWidth/segmentCenterDiff; //need to reduce it by the ratio that the side gap is smaller by the regular gap
    
    if ((view.center.x < leftMostCentre) || (view.center.x > rightMostCentre)) {
        diff = diff * sideRatio;
    }

    CGFloat panelCenter = view.center.x + diff;
    
    
    
    //2. The Size
    /*
     The size should be determined by the percentage the panel is from the centre point
     panelCenter - leftmost / actualCentre - leftmost = the percentage of the size
     
     If the panel center is past the middle point, the reverse needs to occur
     half size difference - (panelCenter - centrepoint) = the percentage of the size
     
     If the panel is < the leftmost or > rightmost, it needs to shrink even more
     If we want this to shrink at a lesser rate then we can do the same thing but on a smaller scale.
     panelCenter - smallestPossibleLeft / leftmost - smallestPOssibleLeft = the percentage of the size
     if > rightmost then just adjust
     size diff - (panelCenter - rightmost) / size diff = percentage of the size
     */
    //edge cases
    CGFloat width = 0;
    CGFloat height = 0;
    if (panelCenter < leftMostCentre || panelCenter > rightMostCentre) {
      
        CGFloat sizediff = leftMostCentre - smallestPossibleCenter;
        double ratio = 0;
        
        if (panelCenter < leftMostCentre) {
            ratio = (panelCenter - smallestPossibleCenter) / sizediff;
            
        } else {
            ratio = (sizediff - (panelCenter - rightMostCentre)) / sizediff;
        }
        
        CGFloat widthDiff = smallestSize.width - smallestPossibleSize.width;
        CGFloat heightDiff = smallestSize.height - smallestPossibleSize.height;
        
        width = smallestPossibleSize.width + widthDiff*ratio;
        height = smallestPossibleSize.height + heightDiff*ratio;
        
        
        //3. Alpha
        /*
         Assuming we want the alpha to = 1 unless it is fading out.
         if panelCenter < leftmost or > rightmost
         based on same percentages above adjust alpha = 0-1
         
         If alpha hits 0 - should remove from view
         */
        view.alpha = ratio;
        
    } else {
        
        double ratio = 0;
        CGFloat halfSize = centreX - leftMostCentre;
        CGFloat widthDiff = largestSize.width - smallestSize.width;
        CGFloat heightDiff = largestSize.height - smallestSize.height;
        
        if (panelCenter < centreX) {
            ratio = (panelCenter - leftMostCentre) / halfSize;
        } else {
            ratio = (halfSize - (panelCenter - centreX)) / halfSize;
        }
        
        width = smallestSize.width + widthDiff*ratio;
        height = smallestSize.height + heightDiff*ratio;
        
        view.alpha = 1;
    }
    
    CGRect adjustedFrame = view.frame;
    adjustedFrame.origin.x = panelCenter - width/2;
    adjustedFrame.origin.y = self.view.frame.size.height/2 - height/2;
    adjustedFrame.size.width = width;
    adjustedFrame.size.height = height;
    
    
    //determine if we need to adjust z index
    CGFloat left = view.frame.origin.x;
    CGFloat right = view.frame.origin.x + view.frame.size.width;
    
    CGFloat newLeft = adjustedFrame.origin.x;
    CGFloat newRight = adjustedFrame.origin.x + adjustedFrame.size.width;
    
    if (((left > centreX) && (newLeft < centreX)) ||
        ((right < centreX) && (newRight > centreX))) {
        [self.view bringSubviewToFront:view];
    }
    
    view.frame = adjustedFrame;
    
    
    //remove the view if we've hit 0
    if (view.alpha <= 0) {
        [view removeFromSuperview];
        [_visibleViews removeObject:view];
        
        NSLog(@"Popping off %d", view.tag);
    }

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
