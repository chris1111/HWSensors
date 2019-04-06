//
//  SensorsTableViewController.h
//  HWMonitor
//
//  Created by Kozlek on 23/07/14.
//  Copyright (c) 2014 kozlek. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SensorsViewController, HWMColorTheme;

@protocol SensorsViewControllerDelegate <NSObject>

@optional

-(void)sensorsViewControllerDidReloadData:(SensorsViewController*)controller;
@end

@interface SensorsViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>

@property (assign) IBOutlet id <SensorsViewControllerDelegate> delegate;
@property (assign) IBOutlet id <NSPopoverDelegate> popoverDelegate;

@property (readonly) NSArray *sensorsAndGroupsCollectionSnapshot;

@property (atomic, assign) NSDragOperation currentItemDragOperation;
@property (readonly) BOOL hasDraggedFavoriteItem;

@property (assign) IBOutlet NSScrollView *scrollView;
@property (assign) IBOutlet NSTableView *tableView;

@property (readonly) CGFloat contentHeight;

-(void)reloadData;

@end
