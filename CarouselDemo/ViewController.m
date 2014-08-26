//
//  ViewController.m
//  CarouselDemo
//
//  Created by Priscilla Kim on 14/08/2014.
//  Copyright (c) 2014 PriscillaBevis. All rights reserved.
//

#import "ViewController.h"

#import "CarouselViewController.h"

@interface ViewController () <CarouselViewControllerDatasource>

@property (nonatomic, retain) CarouselViewController *carouselVC;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
}

-(void) viewWillAppear:(BOOL)animated {

    _carouselVC = [[CarouselViewController alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, 300) andDatasource:self];
    
    _carouselVC.numberOfItemsPerSide = 2;
    _carouselVC.loopInfinitely = YES;
    _carouselVC.blurSideItems = YES;
    _carouselVC.shrinkSideItems = YES;
    _carouselVC.allowScrolling = YES;
    _carouselVC.leftRightMargin = 50;
    
    [self addChildViewController:_carouselVC];
    [self.view addSubview:_carouselVC.view];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Carousel datasource

-(NSUInteger) numberOfItemsAvailableInCarouselViewController:(CarouselViewController*)carouselViewController {
    return 20;
}

-(UIView*) carouselViewController:(CarouselViewController*)carouselViewController viewForItemAtIndex:(NSUInteger)index {
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
    view.backgroundColor = [UIColor yellowColor];
    
    //stick a number in the middle
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, view.frame.size.width, 100)];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:30];
    label.text = [NSString stringWithFormat:@"PanelPanel %d", index];
    [view addSubview:label];
    
    return view;
}

@end
