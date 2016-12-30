//
//  MetalViewDelegate.h
//  metal polaris multipasses depth buffer
//
//  Created by Cyril Kardassevitch on 30/12/2016.
//  Copyright © 2016 Cyril Kardassevitch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>


@interface MetalViewDelegate : NSViewController <MTKViewDelegate>

@property (readonly, strong, nonatomic) id<MTLDevice> device;
@property (readwrite, nonatomic, strong) id<MTLCommandBuffer> commandBuffer;
@property (readwrite, strong, nonatomic) id<MTLRenderCommandEncoder> renderEncoder;

@end
