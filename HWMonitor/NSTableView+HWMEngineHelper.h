//
//  NSTableView+HWMEngineHelper.h
//  HWMonitor
//
//  Created by Kozlek on 12.01.14.
//  Copyright (c) 2014 kozlek. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTableView (HWMEngineHelper)

-(BOOL)updateWithObjectValues:(NSArray*)objectValues previousObjectValues:(NSArray*)oldObjectValues updateHeightOfTheRows:(BOOL)updateHeights withRemoveAnimation:(NSTableViewAnimationOptions)removeAnime insertAnimation:(NSTableViewAnimationOptions)insertAnime;
-(BOOL)updateWithObjectValues:(NSArray*)oldObjects previousObjectValues:(NSArray*)newObjects;

@end
