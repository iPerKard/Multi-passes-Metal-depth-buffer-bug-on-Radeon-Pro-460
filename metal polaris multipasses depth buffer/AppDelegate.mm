//
//  AppDelegate.m
//  metal polaris multipasses depth buffer
//
//  Created by Cyril Kardassevitch on 29/12/2016.
//  Copyright © 2016 Cyril Kardassevitch. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  ///////////////////
  // device selection
  
  [_metalView setNeedsDisplay:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
  // Insert code here to tear down your application
}


@end
