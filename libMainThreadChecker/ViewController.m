//
//  ViewController.m
//  libMainThreadChecker
//
//  Created by z on 2017/9/25.
//  Copyright © 2017年 SatanWoo. All rights reserved.
//

#import "ViewController.h"
#import "libMainThreadChecker.h"

@interface ViewController ()

@end

@implementation ViewController

+ (void)load
{
    library_initializer();
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor redColor];

    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            });
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
