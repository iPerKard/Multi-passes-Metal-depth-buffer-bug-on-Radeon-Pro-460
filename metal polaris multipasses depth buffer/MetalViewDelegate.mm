//
//  MetalViewDelegate.m
//  metal polaris multipasses depth buffer
//
//  Created by Cyril Kardassevitch on 30/12/2016.
//  Copyright © 2016 Cyril Kardassevitch. All rights reserved.
//

#import "MetalViewDelegate.h"
#import "AAPLTransforms.h"
#import "AAPLSharedTypes.h"


using namespace AAPL;
using namespace simd;


static const NSUInteger kNumberOfBoxes = 2;
static const float4 kBoxAmbientColors[2] = {
  {0.18, 0.24, 0.8, 1.0},
  {0.8, 0.24, 0.1, 1.0}
};

static const float4 kBoxDiffuseColors[2] = {
  {0.4, 0.4, 1.0, 1.0},
  {0.8, 0.4, 0.4, 1.0}
};

static const float kFOVY    = 50.0f;
static const float3 kEye    = {0.0f, 0.0f, 0.0f};
static const float3 kCenter = {0.0f, 0.0f, 1.0f};
static const float3 kUp     = {0.0f, 1.0f, 0.0f};

static const float kWidth  = 0.75f;
static const float kHeight = 0.75f;
static const float kDepth  = 0.75f;

static const float kCubeVertexData[] =
{
  kWidth, -kHeight, kDepth,   0.0, -1.0,  0.0,
  -kWidth, -kHeight, kDepth,   0.0, -1.0, 0.0,
  -kWidth, -kHeight, -kDepth,   0.0, -1.0,  0.0,
  kWidth, -kHeight, -kDepth,  0.0, -1.0,  0.0,
  kWidth, -kHeight, kDepth,   0.0, -1.0,  0.0,
  -kWidth, -kHeight, -kDepth,   0.0, -1.0,  0.0,
  
  kWidth, kHeight, kDepth,    1.0, 0.0,  0.0,
  kWidth, -kHeight, kDepth,   1.0,  0.0,  0.0,
  kWidth, -kHeight, -kDepth,  1.0,  0.0,  0.0,
  kWidth, kHeight, -kDepth,   1.0, 0.0,  0.0,
  kWidth, kHeight, kDepth,    1.0, 0.0,  0.0,
  kWidth, -kHeight, -kDepth,  1.0,  0.0,  0.0,
  
  -kWidth, kHeight, kDepth,    0.0, 1.0,  0.0,
  kWidth, kHeight, kDepth,    0.0, 1.0,  0.0,
  kWidth, kHeight, -kDepth,   0.0, 1.0,  0.0,
  -kWidth, kHeight, -kDepth,   0.0, 1.0,  0.0,
  -kWidth, kHeight, kDepth,    0.0, 1.0,  0.0,
  kWidth, kHeight, -kDepth,   0.0, 1.0,  0.0,
  
  -kWidth, -kHeight, kDepth,  -1.0,  0.0, 0.0,
  -kWidth, kHeight, kDepth,   -1.0, 0.0,  0.0,
  -kWidth, kHeight, -kDepth,  -1.0, 0.0,  0.0,
  -kWidth, -kHeight, -kDepth,  -1.0,  0.0,  0.0,
  -kWidth, -kHeight, kDepth,  -1.0,  0.0, 0.0,
  -kWidth, kHeight, -kDepth,  -1.0, 0.0,  0.0,
  
  kWidth, kHeight,  kDepth,  0.0, 0.0,  1.0,
  -kWidth, kHeight,  kDepth,  0.0, 0.0,  1.0,
  -kWidth, -kHeight, kDepth,   0.0,  0.0, 1.0,
  -kWidth, -kHeight, kDepth,   0.0,  0.0, 1.0,
  kWidth, -kHeight, kDepth,   0.0,  0.0,  1.0,
  kWidth, kHeight,  kDepth,  0.0, 0.0,  1.0,
  
  kWidth, -kHeight, -kDepth,  0.0,  0.0, -1.0,
  -kWidth, -kHeight, -kDepth,   0.0,  0.0, -1.0,
  -kWidth, kHeight, -kDepth,  0.0, 0.0, -1.0,
  kWidth, kHeight, -kDepth,  0.0, 0.0, -1.0,
  kWidth, -kHeight, -kDepth,  0.0,  0.0, -1.0,
  -kWidth, kHeight, -kDepth,  0.0, 0.0, -1.0
};


@implementation MetalViewDelegate
{
  MTKView *_view;
  NSInteger _sizeOfConstantT;
  NSInteger _maxBufferBytesPerFrame;
  
  // renderer
  id <MTLCommandQueue> _commandQueue;
  id <MTLLibrary> _defaultLibrary;
  id <MTLRenderPipelineState> _pipelineState;
  id <MTLDepthStencilState> _depthState;
  id <MTLBuffer> _vertexBuffer;
  id <MTLBuffer> _constantBuffer;

  // globals used in update calculation
  float4x4 _projectionMatrix;
  float4x4 _viewMatrix;
  float _rotation;
}

- (id)initWithCoder:(NSCoder *)coder
{
  self =  [super initWithCoder:coder];
  
  if (self)
  {
    _sizeOfConstantT = sizeof(constants_t);
    _maxBufferBytesPerFrame = _sizeOfConstantT * kNumberOfBoxes;
    _rotation = 25.0;
    
    [self setupMetal];
  }
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self setupView];
}

- (void)setupMetal
{
  // Set the view to use the default device.
  _device = MTLCreateSystemDefaultDevice();
  
  // Create a new command queue.
  _commandQueue = [_device newCommandQueue];
  
  // Load all the shader files with a metal file extension in the project.
  _defaultLibrary = [_device newDefaultLibrary];
  if(!_defaultLibrary) {
    NSLog(@">> ERROR: Couldnt create a default shader library");
    // assert here becuase if the shader libary isn't loading, nothing good will happen
    assert(0);
  }
}

- (BOOL)preparePipelineState:(MTKView *)view
{
  // get the fragment function from the library
  id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"lighting_fragment"];
  if(!fragmentProgram)
    NSLog(@">> ERROR: Couldn't load fragment function from default library");
  
  // get the vertex function from the library
  id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"lighting_vertex"];
  if(!vertexProgram)
    NSLog(@">> ERROR: Couldn't load vertex function from default library");
  
  // setup the vertex buffers
  _vertexBuffer = [_device newBufferWithBytes:kCubeVertexData length:sizeof(kCubeVertexData) options:MTLResourceOptionCPUCacheModeDefault];
  _vertexBuffer.label = @"Vertices";
  
  // create a pipeline state descriptor which can be used to create a compiled pipeline state object
  MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
  
  pipelineStateDescriptor.label                           = @"MyPipeline";
  pipelineStateDescriptor.sampleCount                     = view.sampleCount;
  pipelineStateDescriptor.vertexFunction                  = vertexProgram;
  pipelineStateDescriptor.fragmentFunction                = fragmentProgram;
  pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
  pipelineStateDescriptor.depthAttachmentPixelFormat      = view.depthStencilPixelFormat;
  pipelineStateDescriptor.stencilAttachmentPixelFormat    = view.depthStencilPixelFormat;
  
  // create a compiled pipeline state object. Shader functions (from the render pipeline descriptor)
  // are compiled when this is created unlessed they are obtained from the device's cache
  NSError *error = nil;
  _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
  if(!_pipelineState) {
    NSLog(@">> ERROR: Failed Aquiring pipeline state: %@", error);
    return NO;
  }
  
  return YES;
}

- (void)setupView
{
  _view = (MTKView*)(self.view);
  
  _view.delegate = self;
  _view.device = _device;
  
  _view.sampleCount = 1;
  _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
  _view.clearColor = {1.0, 1.0, 1.0, 1.0};

  _view.paused = YES;
  _view.enableSetNeedsDisplay = YES;

  
  // prepare the pipeline states
  if (![self preparePipelineState:_view])
  {
    NSLog(@">> ERROR: Couldnt create a valid pipeline state");
    
    // cannot render anything without a valid compiled pipeline state object.
    assert(0);
  }

  _constantBuffer = [_device newBufferWithLength:_maxBufferBytesPerFrame options:0];
  _constantBuffer.label = @"ConstantBuffer";
  
  constants_t *constant_buffer = (constants_t *)[_constantBuffer contents];
  for (int j = 0; j < kNumberOfBoxes; j++)
  {
    if (j%2==0)
    {
      constant_buffer[j].multiplier = 1;
      constant_buffer[j].ambient_color = kBoxAmbientColors[0];
      constant_buffer[j].diffuse_color = kBoxDiffuseColors[0];
    }
    else
    {
      constant_buffer[j].multiplier = -1;
      constant_buffer[j].ambient_color = kBoxAmbientColors[1];
      constant_buffer[j].diffuse_color = kBoxDiffuseColors[1];
    }
  }

  MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
  depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
  depthStateDesc.depthWriteEnabled = YES;
  _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

  [self reshape:_view];
}

- (void)passWithDescriptor:(MTLRenderPassDescriptor*)renderPassDescriptor size:(NSSize)size andRenderingBlock:(void (^)(id<MTLRenderCommandEncoder> renderEncoder))block
{
  if (renderPassDescriptor != nil)
  {
    _renderEncoder = [self.commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    _renderEncoder.label = @"Pass Encoder";
    
    // Set context state.
    [_renderEncoder setViewport:{0, 0, size.width, size.height, 0, 1}];
    
    block(_renderEncoder);
    
    [_renderEncoder endEncoding];
    _renderEncoder = nil;
  }
}

- (MTLRenderPassDescriptor*)standardRenderPassDescriptorForView:(MTKView*)view
{
  return view.currentRenderPassDescriptor;
}

- (MTLRenderPassDescriptor*)firstRenderPassDescriptorForView:(MTKView*)view
{
  MTLRenderPassDescriptor *renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
  
  MTLRenderPassColorAttachmentDescriptor *colorAttachment = renderPassDescriptor.colorAttachments[0];
  colorAttachment.texture = view.currentRenderPassDescriptor.colorAttachments[0].texture;
  colorAttachment.loadAction = view.currentRenderPassDescriptor.colorAttachments[0].loadAction;
  colorAttachment.storeAction = MTLStoreActionStore;
  colorAttachment.clearColor = view.currentRenderPassDescriptor.colorAttachments[0].clearColor;
  
  MTLRenderPassDepthAttachmentDescriptor *depthAttachment = renderPassDescriptor.depthAttachment;
  depthAttachment.texture = view.currentRenderPassDescriptor.depthAttachment.texture;
  depthAttachment.loadAction = view.currentRenderPassDescriptor.depthAttachment.loadAction;
  depthAttachment.storeAction = MTLStoreActionStore;
  depthAttachment.clearDepth = view.currentRenderPassDescriptor.depthAttachment.clearDepth;
  
  MTLRenderPassStencilAttachmentDescriptor *stencilAttachment = renderPassDescriptor.stencilAttachment;
  stencilAttachment.texture = view.currentRenderPassDescriptor.stencilAttachment.texture;
  stencilAttachment.loadAction = view.currentRenderPassDescriptor.stencilAttachment.loadAction;
  stencilAttachment.storeAction = MTLStoreActionStore;
  stencilAttachment.clearStencil = view.currentRenderPassDescriptor.stencilAttachment.clearStencil;
  
  return renderPassDescriptor;
}

- (MTLRenderPassDescriptor*)secondRenderPassDescriptorForView:(MTKView*)view
{
  MTLRenderPassDescriptor *renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
  
  MTLRenderPassColorAttachmentDescriptor *colorAttachment = renderPassDescriptor.colorAttachments[0];
  colorAttachment.texture = view.currentRenderPassDescriptor.colorAttachments[0].texture;
  colorAttachment.loadAction = MTLLoadActionLoad;
  colorAttachment.storeAction = view.currentRenderPassDescriptor.colorAttachments[0].storeAction;
  colorAttachment.clearColor = view.currentRenderPassDescriptor.colorAttachments[0].clearColor;
  
  MTLRenderPassDepthAttachmentDescriptor *depthAttachment = renderPassDescriptor.depthAttachment;
  depthAttachment.texture = view.currentRenderPassDescriptor.depthAttachment.texture;
  depthAttachment.loadAction = MTLLoadActionLoad;
  depthAttachment.storeAction = view.currentRenderPassDescriptor.depthAttachment.storeAction;
  depthAttachment.clearDepth = view.currentRenderPassDescriptor.depthAttachment.clearDepth;
  
  MTLRenderPassStencilAttachmentDescriptor *stencilAttachment = renderPassDescriptor.stencilAttachment;
  stencilAttachment.texture = view.currentRenderPassDescriptor.stencilAttachment.texture;
  stencilAttachment.loadAction = MTLLoadActionLoad;
  stencilAttachment.storeAction = view.currentRenderPassDescriptor.stencilAttachment.storeAction;
  stencilAttachment.clearStencil = view.currentRenderPassDescriptor.stencilAttachment.clearStencil;
  
  return renderPassDescriptor;
}

- (void)reshape:(MTKView *)view
{
  // when reshape is called, update the view and projection matricies since this means the view orientation or size changed
  float aspect = fabs(view.bounds.size.width / view.bounds.size.height);
  _projectionMatrix = perspective_fov(kFOVY, aspect, 0.1f, 100.0f);
  _viewMatrix = lookAt(kEye, kCenter, kUp);
}

#pragma mark - MTKViewDelegate delegate -

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
  [self reshape:view];
}


- (void)drawInMTKView:(nonnull MTKView *)mtlView
{
  
  @autoreleasepool
  {
    _commandBuffer = [_commandQueue commandBuffer];
    _commandBuffer.label = @"Main Command Buffer";

    
    [self updateConstantBuffer];
    
    
    /////////////////////////
    // FIRST PASS - BLUE CUBE
    //
    // the depth and stencil buffer is stored
    [self passWithDescriptor:[self firstRenderPassDescriptorForView:mtlView] size:mtlView.drawableSize andRenderingBlock:^(id<MTLRenderCommandEncoder> renderEncoder) {
      
      [renderEncoder pushDebugGroup:@"Boxes"];
      [renderEncoder setDepthStencilState:_depthState];
      [renderEncoder setRenderPipelineState:_pipelineState];
      [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0 ];
      
      for (int i = 0; i < 1; i++)
      {
        //  set constant buffer for each box
        [renderEncoder setVertexBuffer:_constantBuffer offset:i*_sizeOfConstantT atIndex:1 ];
        
        // tell the render context we want to draw our primitives
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
      }
      
      [renderEncoder popDebugGroup];
      
    }];

    
    /////////////////////////
    // SECOND PASS - RED CUBE
    //
    // the depth and stencil buffer is load from the first pass
    [self passWithDescriptor:[self secondRenderPassDescriptorForView:mtlView] size:mtlView.drawableSize andRenderingBlock:^(id<MTLRenderCommandEncoder> renderEncoder) {

      [renderEncoder pushDebugGroup:@"Boxes"];
      [renderEncoder setDepthStencilState:_depthState];
      [renderEncoder setRenderPipelineState:_pipelineState];
      [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0 ];
      
      for (int i = 1; i < kNumberOfBoxes; i++)
      {
        //  set constant buffer for each box
        [renderEncoder setVertexBuffer:_constantBuffer offset:i*_sizeOfConstantT atIndex:1 ];
        
        // tell the render context we want to draw our primitives
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
      }
      
      [renderEncoder popDebugGroup];
      
    }];
    
    
    [_commandBuffer presentDrawable:_view.currentDrawable];
    [_commandBuffer commit];
    
    //TEMPPP
    //  [commandBuffer waitUntilCompleted];
    
    _commandBuffer = nil;
  }
  
}

#pragma mark Update

// called every frame
- (void)updateConstantBuffer
{
  float4x4 baseModelViewMatrix = translate(0.0f, 0.0f, 5.0f) * rotate(_rotation, 1.0f, 1.0f, 1.0f);
  baseModelViewMatrix = _viewMatrix * baseModelViewMatrix;
  
  constants_t *constant_buffer = (constants_t *)[_constantBuffer contents];
  for (int i = 0; i < kNumberOfBoxes; i++)
  {
    // calculate the Model view projection matrix of each box
    // for each box, if its odd, create a negative multiplier to offset boxes in space
    int multiplier = ((i % 2 == 0)?1:-1);
    simd::float4x4 modelViewMatrix = AAPL::translate(0.0f, 0.0f, multiplier*1.5f) * AAPL::rotate(_rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = baseModelViewMatrix * modelViewMatrix;
    
    constant_buffer[i].normal_matrix = inverse(transpose(modelViewMatrix));
    constant_buffer[i].modelview_projection_matrix = _projectionMatrix * modelViewMatrix;
    
//    // change the color each frame
//    // reverse direction if we've reached a boundary
//    if (constant_buffer[i].ambient_color.y >= 0.8) {
//      constant_buffer[i].multiplier = -1;
//      constant_buffer[i].ambient_color.y = 0.79;
//    } else if (constant_buffer[i].ambient_color.y <= 0.2) {
//      constant_buffer[i].multiplier = 1;
//      constant_buffer[i].ambient_color.y = 0.21;
//    } else
//      constant_buffer[i].ambient_color.y += constant_buffer[i].multiplier * 0.01*i;
  }
}

@end
