//
//  ItemCell.h
//  HWMonitor
//
//  Created by kozlek on 25.03.13.
//  Copyright (c) 2013 kozlek. All rights reserved.
//

@interface PrefsCell : NSTableCellView

@property (assign) IBOutlet NSTextField *valueField;
@property (assign) IBOutlet NSButton *checkBox;
@property (assign) IBOutlet NSButton *forcedCheckBox;
@property (assign) IBOutlet NSColorWell *colorWeel;

@end
