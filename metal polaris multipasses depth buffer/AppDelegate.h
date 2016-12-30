//
//  AppDelegate.h
//  metal polaris multipasses depth buffer
//
//  Created by Cyril Kardassevitch on 29/12/2016.
//  Copyright © 2016 Cyril Kardassevitch. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import "MetalViewDelegate.h"


@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readwrite, nonatomic, strong) IBOutlet MTKView *metalView;
@property (readwrite, nonatomic, strong) IBOutlet MetalViewDelegate *metalViewDelegate;

@end

