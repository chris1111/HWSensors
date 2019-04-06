//
//  HWMIcon.m
//  HWMonitor
//
//  Created by Kozlek on 16/11/13.
//  Copyright (c) 2013 kozlek. All rights reserved.
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

#import "HWMIcon.h"
#import "HWMConfiguration.h"
#import "HWMColorTheme.h"
#import "HWMEngine.h"

@implementation HWMIcon

@dynamic alternate;
@dynamic regular;

-(NSImage *)image
{
    return self.engine.configuration.colorTheme.useBrightIcons.boolValue ? self.alternate : self.regular;
}

-(void)prepareForDeletion
{
    if (self.engine) {
        //[self removeObserver:self.engine forKeyPath:@"engine.configuration.colorTheme"];
    }
}

-(void)setEngine:(HWMEngine *)engine
{
    if (self.engine) {
        [self removeObserver:self.engine forKeyPath:@keypath(self, engine.configuration.colorTheme)];
    }

    [super setEngine:engine];

    if (self.engine) {
        [self addObserver:self forKeyPath:@keypath(self, engine.configuration.colorTheme) options:0 context:nil];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:@keypath(self, engine.configuration.colorTheme)]) {
        [self willChangeValueForKey:@keypath(self, image)];
        [self didChangeValueForKey:@keypath(self, image)];
    }
}

@end
