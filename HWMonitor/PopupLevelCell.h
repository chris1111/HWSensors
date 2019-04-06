//
//  PopupLevelCell.h
//  HWMonitor
//
//  Created by Kozlek on 02/03/14.
//  Copyright (c) 2014 kozlek. All rights reserved.
//

/*
 *  Copyright (c) 2013 Natan Zalkin <natan.zalkin@me.com>. All rights reserved.
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 *  02111-1307, USA.
 *
 */

@class HWMSmcFanControlLevel;

@interface PopupLevelCell : NSTableCellView

@property (assign) IBOutlet NSSlider *inputSlider;
@property (assign) IBOutlet NSTextField *inputTextField;
@property (assign) IBOutlet NSSlider *outputSlider;
@property (assign) IBOutlet NSTextField *outputTextField;

@property (readonly) HWMSmcFanControlLevel * level;

-(IBAction)insertLevel:(id)sender;
-(IBAction)removeLevel:(id)sender;

@end
