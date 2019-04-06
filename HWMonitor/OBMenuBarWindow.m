//
//  OBMenuBarWindow.m
//
//  Copyright (c) 2012, Oliver Bolton (http://oliverbolton.com/)
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//      * Neither the name of the <organization> nor the
//        names of its contributors may be used to endorse or promote products
//        derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL OLIVER BOLTON BE LIABLE FOR ANY DIRECT,
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "OBMenuBarWindow.h"
#import "OBMenuBarWindowFrameView.h"
#import "HWMColorTheme.h"

NSString * const OBMenuBarWindowDidAttachToMenuBar = @"OBMenuBarWindowDidAttachToMenuBar";
NSString * const OBMenuBarWindowDidDetachFromMenuBar = @"OBMenuBarWindowDidDetachFromMenuBar";
NSString * const OBMenuBarWindowDidBecomeKey = @"OBMenuBarWindowDidBecomeKey";
NSString * const OBMenuBarWindowDidResignKey = @"OBMenuBarWindowDidResignKey";

// You can alter these constants to change the appearance of the window
//CGFloat OBMenuBarWindowTitleBarHeight = 35;
const CGFloat OBMenuBarWindowArrowHeight = 11.0f;
const CGFloat OBMenuBarWindowArrowWidth = 22.0f;
const CGFloat OBMenuBarWindowArrowOffset = 2.0f;
const CGFloat OBMenuBarWindowArrowPinRadius = 2.5f;
const CGFloat OBMenuBarWindowArrowBaseRadius = 11.0f;
const CGFloat OBMenuBarWindowCornerRadius = 5.5f;
const CGFloat OBMenuBarWindowSnapOffset = 30.0f;

@interface OBMenuBarWindow ()

- (void)initialSetup;
- (NSRect)titleBarRect;
- (NSRect)toolbarRect;
- (NSPoint)originForAttachedState;
- (void)applicationDidChangeActiveStatus:(NSNotification *)aNotification;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignKey:(NSNotification *)aNotification;
- (void)windowDidResize:(NSNotification *)aNotification;
- (void)windowWillStartLiveResize:(NSNotification *)aNotification;
- (void)windowDidMove:(NSNotification *)aNotification;
- (void)statusItemViewDidMove:(NSNotification *)aNotification;
- (NSWindow *)window;

@property (readonly) NSImage *noiseImage;
@property (readonly) NSImage *activeImage;
@property (readonly) NSImage *inactiveImage;
@property (atomic, assign) NSUInteger scheduledRefreshCount;
@property (atomic, assign) CGFloat cachedContentScale;
@property (nonatomic, strong) NSView * customContentView;

@end

@implementation OBMenuBarWindow

@synthesize attachedToMenuBar;
@synthesize hideWindowControls;
@synthesize snapDistance;
@synthesize statusItem;
@synthesize statusItemView;
@synthesize toolbarView;
@synthesize colorTheme;
@synthesize noiseImage;
@synthesize activeImage = _activeImage;
@synthesize inactiveImage = _inactiveImage;

-(CGFloat)toolbarHeight
{
    return [self titleBarRect].size.height;
}

-(void)setStatusItemView:(NSView *)newStatusItemView
{
    if (statusItemView == newStatusItemView) {
        return;
    }
    
    if (newStatusItemView && statusItemView != newStatusItemView)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusItemViewDidMove:) name:NSWindowDidMoveNotification object:newStatusItemView.window];
    }
    else if (statusItemView)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidMoveNotification object:statusItemView];
    }

    statusItemView = newStatusItemView;
}

-(NSView *)statusItemView
{
    return statusItemView;
}

- (void)setStatusItem:(NSStatusItem *)newStatusItem
{
    statusItem = newStatusItem;

    if (!statusItem) {
        self.attachedToMenuBar = NO;
    }
}

- (NSStatusItem *)statusItem
{
    return statusItem;
}

-(void)setToolbarView:(NSView *)newToolbarView
{
    if (toolbarView) {
        [toolbarView removeFromSuperview];
    }

    toolbarView = newToolbarView;

    if (toolbarView) {
        //OBMenuBarWindowTitleBarHeight = toolbarView.frame.size.height;
        [[self.contentView superview] addSubview:toolbarView];
        [self layoutContent];
    }
}

-(NSView *)toolbarView
{
    return toolbarView;
}

- (void)setContentView:(NSView *)aView
{
    if ([self.customContentView isEqualTo:aView])
    {
        return;
    }

    NSRect bounds = [self frame];
    bounds.origin = NSZeroPoint;

    OBMenuBarWindowFrameView *frameView = [super contentView];
    if (!frameView)
    {
        frameView = [[OBMenuBarWindowFrameView alloc] initWithFrame:bounds];
        [super setContentView:frameView];
    }

    if (self.customContentView)
    {
        [self.customContentView removeFromSuperview];
    }

    self.customContentView = aView;
    [self.customContentView setFrame:[self contentRectForFrameRect:bounds]];
//    [self.customContentView setTranslatesAutoresizingMaskIntoConstraints:YES];
//    [self.customContentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [frameView addSubview:self.customContentView];
}

- (NSView *)contentView
{
    return self.customContentView;
}

-(void)setColorTheme:(HWMColorTheme*)newColorTheme
{
    if (colorTheme != newColorTheme) {
        [self resetContentImagesScheduleRefresh:YES];
        colorTheme = newColorTheme;
        // Redraw the theme frame
        [[self.contentView superview] setNeedsDisplayInRect:[self.contentView superview].frame];
    }
}

-(HWMColorTheme *)colorTheme
{
    return colorTheme;
}

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect
                            styleMask:NSBorderlessWindowMask//
                              backing:bufferingType
                                defer:flag];
    if (self)
    {
        snapDistance = 30.0;
        hideWindowControls = OBMenuBarWindowHideControlsThenAttached;
        [self initialSetup];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)initialSetup
{



//    if (![[[self contentView] superview] respondsToSelector:@selector(drawRectOriginal:)]) {
//        [[self class] swizzleDrawRectForClass:[[[self contentView] superview] class]];
//        [[[self contentView] superview] setWantsLayer:NO];
//    }
    // Get window's frame view class
    /*id class = NSClassFromString(@"NSNextStepFrame");//[[[self contentView] superview] class];

    // Add the new drawRect: to the frame class
    Method m0 = class_getInstanceMethod([self class], @selector(drawRect:));
    class_addMethod(class, @selector(drawRectOriginal:), method_getImplementation(m0), method_getTypeEncoding(m0));

    // Exchange methods
    Method m1 = class_getInstanceMethod(class, @selector(drawRect:));
    Method m2 = class_getInstanceMethod(class, @selector(drawRectOriginal:));
    method_exchangeImplementations(m1, m2);*/

    // Set up the window drawing
    [self setOpaque:NO];
    [self setBackgroundColor:[NSColor clearColor]];

    [self setMovable:NO];

    // Observe window and application state notifications
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(windowDidMove:)
                   name:NSWindowDidMoveNotification
                 object:self];
    [center addObserver:self
               selector:@selector(windowDidResize:)
                   name:NSWindowDidResizeNotification
                 object:self];
    [center addObserver:self
               selector:@selector(windowWillStartLiveResize:)
                   name:NSWindowWillStartLiveResizeNotification
                 object:self];
    [center addObserver:self
               selector:@selector(windowWillBeginSheet:)
                   name:NSWindowWillBeginSheetNotification
                 object:self];
    [center addObserver:self
               selector:@selector(windowDidEndSheet:)
                   name:NSWindowDidEndSheetNotification
                 object:self];
    [center addObserver:self
               selector:@selector(windowDidBecomeKey:)
                   name:NSWindowDidBecomeKeyNotification
                 object:self];
    [center addObserver:self
               selector:@selector(windowDidResignKey:)
                   name:NSWindowDidResignKeyNotification
                 object:self];
    [center addObserver:self
               selector:@selector(applicationDidChangeActiveStatus:)
                   name:NSApplicationDidBecomeActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDidChangeActiveStatus:)
                   name:NSApplicationDidResignActiveNotification
                 object:nil];

    // Create the toolbar view
    NSRect toolbarRect = [self toolbarRect];
    NSView *themeFrame = [self.contentView superview];
    self.toolbarView = [[NSView alloc] initWithFrame:toolbarRect];
    [toolbarView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];

    // Create the title text field
    NSRect titleRect = NSMakeRect(70,
                                  (toolbarRect.size.height - 17) / 2,
                                  toolbarRect.size.width - 140,
                                  17);
    titleTextField = [[NSTextField alloc] initWithFrame:titleRect];
    [titleTextField setEditable:NO];
    [titleTextField setBezeled:NO];
    [titleTextField setDrawsBackground:NO];
    [titleTextField setAlignment:NSCenterTextAlignment];
    [titleTextField setFont:[NSFont titleBarFontOfSize:13.0]];
    [[titleTextField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [[titleTextField cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [titleTextField setAutoresizingMask:NSViewWidthSizable];
    [toolbarView addSubview:titleTextField];

    // Lay out the content
    [themeFrame addSubview:toolbarView];
    [self layoutContent];
}

#pragma mark - Positioning controls

- (void)layoutContent
{
    // Position the close/minimise/zoom buttons
    NSButton *closeButton = [self standardWindowButton:NSWindowCloseButton];
    NSButton *minimiseButton = [self standardWindowButton:NSWindowMiniaturizeButton];
    NSButton *zoomButton = [self standardWindowButton:NSWindowZoomButton];
    CGFloat buttonWidth = closeButton.frame.size.width;
    CGFloat buttonHeight = closeButton.frame.size.height;
    NSRect toolbarRect = [self toolbarRect];
    CGFloat buttonOriginY = floor(toolbarRect.origin.y + (toolbarRect.size.height - buttonHeight) / 2.0);
    [closeButton setFrame:NSMakeRect(7, buttonOriginY, buttonWidth, buttonHeight)];
    [minimiseButton setFrame:NSMakeRect(27, buttonOriginY, buttonWidth, buttonHeight)];
    [zoomButton setFrame:NSMakeRect(47, buttonOriginY, buttonWidth, buttonHeight)];

    [[self.contentView superview] viewWillStartLiveResize];
    [[self.contentView superview] viewDidEndLiveResize];

    // Position the toolbar view
    [toolbarView setFrame:[self toolbarRect]];

    // Position the content view
    NSRect contentViewFrame = [self.contentView frame];
    CGFloat currentTopMargin = NSHeight(self.frame) - NSHeight(contentViewFrame);
    CGFloat titleBarHeight = toolbarView.frame.size.height + (self.attachedToMenuBar ? OBMenuBarWindowArrowHeight : 0) + 1;
    CGFloat delta = titleBarHeight - currentTopMargin;
    contentViewFrame.size.height -= delta;
    [self.contentView setFrame:contentViewFrame];

    // Redraw the theme frame
    [[self.contentView superview] setNeedsDisplayInRect:[self titleBarRect]];
}

#pragma mark - Menu bar icon

- (void)attachToMenuBar:(id)sender
{
    if ([self.window isVisible]) {
        self.attachedToMenuBar = YES;
    }
}

- (void)detachFromMenuBar:(id)sender
{
    if ([self.window isVisible]) {
        self.attachedToMenuBar = NO;
    }
}

- (void)setAttachedToMenuBar:(BOOL)isAttached
{
    if (isAttached != attachedToMenuBar)
    {
        attachedToMenuBar = isAttached;

        if (isAttached)
        {
            NSRect newFrame = self.frame;
            newFrame.size.height += OBMenuBarWindowArrowHeight;
            newFrame.origin.y -= OBMenuBarWindowArrowHeight;
            [self setFrame:newFrame display:YES];
        }
        else
        {
            NSRect newFrame = self.frame;
            newFrame.size.height -= OBMenuBarWindowArrowHeight;
            newFrame.origin.y += OBMenuBarWindowArrowHeight;
            [self setFrame:newFrame display:YES];
        }

        // Set whether the window is opaque (this affects the shadow)
        //[self setOpaque:!isAttached];
        //[self setOpaque:NO];

        // Reposition the content
        [self layoutContent];

        // Animate the window controls
        NSButton *closeButton = [self standardWindowButton:NSWindowCloseButton];
        NSButton *minimiseButton = [self standardWindowButton:NSWindowMiniaturizeButton];
        NSButton *zoomButton = [self standardWindowButton:NSWindowZoomButton];
        if (isAttached)
        {
            if (self.hideWindowControls == OBMenuBarWindowHideControlsThenAttached)
            {
                hideControls = YES;
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    [context setDuration:0.15];
                    [[closeButton animator] setAlphaValue:0.0];
                    [[minimiseButton animator] setAlphaValue:0.0];
                    [[zoomButton animator] setAlphaValue:0.0];
                } completionHandler:^{
                    if (hideControls)
                    {
                        [closeButton setHidden:YES];
                        [minimiseButton setHidden:YES];
                        [zoomButton setHidden:YES];
                        [closeButton setAlphaValue:1.0];
                        [minimiseButton setAlphaValue:1.0];
                        [zoomButton setAlphaValue:1.0];
                        hideControls = NO;
                    }
                }];
            }
            if (!isDragging)
            {
                [self setFrameOrigin:[self originForAttachedState]];
            }
        }
        else
        {
            if (self.hideWindowControls == OBMenuBarWindowHideControlsThenAttached)
            {
                hideControls = NO;
                [closeButton setAlphaValue:0.0];
                [minimiseButton setAlphaValue:0.0];
                [zoomButton setAlphaValue:0.0];
                [closeButton setHidden:NO];
                [minimiseButton setHidden:NO];
                [zoomButton setHidden:NO];
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    [context setDuration:0.15];
                    [[closeButton animator] setAlphaValue:1.0];
                    [[minimiseButton animator] setAlphaValue:1.0];
                    [[zoomButton animator] setAlphaValue:1.0];
                } completionHandler:nil];
            }
            if (!isDragging)
            {
                [self setFrameOrigin:NSMakePoint(self.frame.origin.x,
                                                 self.frame.origin.y - self.snapDistance - 10)];
            }
        }

        [self setLevel:(isAttached ? NSFloatingWindowLevel : NSNormalWindowLevel)];

        if (isAttached)
        {
            if (self.delegate != nil && [self.delegate respondsToSelector:@selector(windowDidAttachToStatusBar:)]) {
                [self.delegate performSelector:@selector(windowDidAttachToStatusBar:)
                                withObject:self];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:OBMenuBarWindowDidAttachToMenuBar
                                                                object:self];
        }
        else
        {
            if (self.delegate != nil && [self.delegate respondsToSelector:@selector(windowDidDetachFromStatusBar:)]) {
                [self.delegate performSelector:@selector(windowDidDetachFromStatusBar:)
                                withObject:self];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:OBMenuBarWindowDidDetachFromMenuBar
                                                                object:self];
        }
        
        //[self layoutContent];
        //[[self.contentView superview] setNeedsDisplayInRect:[self titleBarRect]];
        [[self.contentView superview] setNeedsDisplay:YES];
        
        //[self setHasShadow:NO];
        [self invalidateShadow];
    }
}

- (void)setHideWindowControls:(NSUInteger)flag
{
    if (flag != self.hideWindowControls)
    {
        hideWindowControls = flag;

        NSButton *closeButton = [self standardWindowButton:NSWindowCloseButton];
        NSButton *minimiseButton = [self standardWindowButton:NSWindowMiniaturizeButton];
        NSButton *zoomButton = [self standardWindowButton:NSWindowZoomButton];

        switch (hideWindowControls) {
                case OBMenuBarWindowHideControlsThenAttached:
                if (self.attachedToMenuBar) {
                    [closeButton setAlphaValue:1.0];
                    [minimiseButton setAlphaValue:1.0];
                    [zoomButton setAlphaValue:1.0];
                    [closeButton setHidden:YES];
                    [minimiseButton setHidden:YES];
                    [zoomButton setHidden:YES];
                }
                break;

                case YES:
                [closeButton setAlphaValue:1.0];
                [minimiseButton setAlphaValue:1.0];
                [zoomButton setAlphaValue:1.0];
                [closeButton setHidden:YES];
                [minimiseButton setHidden:YES];
                [zoomButton setHidden:YES];
                break;

            default:
                [closeButton setAlphaValue:1.0];
                [minimiseButton setAlphaValue:1.0];
                [zoomButton setAlphaValue:1.0];
                [closeButton setHidden:NO];
                [minimiseButton setHidden:NO];
                [zoomButton setHidden:NO];
                break;
        }
    }
}

#pragma mark - Rects

//- (void)setContentSize:(NSSize)newSize
//{
//    NSSize sizeDelta = newSize;
//    NSSize childBoundsSize = [self.customContentView bounds].size;
//    sizeDelta.width -= childBoundsSize.width;
//    sizeDelta.height -= childBoundsSize.height;
//
//    OBMenuBarWindowFrameView *frameView = [super contentView];
//    NSSize newFrameSize = [frameView bounds].size;
//    newFrameSize.width += sizeDelta.width;
//    newFrameSize.height += sizeDelta.height;
//
//    [super setContentSize:newFrameSize];
//}

- (NSRect)titleBarRect
{
    CGFloat titlebarHeight = toolbarView.frame.size.height;
    return NSMakeRect(0, self.frame.size.height - titlebarHeight, self.frame.size.width, titlebarHeight);
}

- (NSRect)toolbarRect
{
    if (self.attachedToMenuBar)
    {
        CGFloat titlebarHeight = toolbarView.frame.size.height;

        return NSMakeRect(0,
                          self.frame.size.height - titlebarHeight - OBMenuBarWindowArrowHeight,
                          self.frame.size.width,
                          titlebarHeight);
    }
    else
    {
        return [self titleBarRect];
    }
}

#pragma mark - Active/key events

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)applicationDidChangeActiveStatus:(NSNotification *)aNotification
{
    [[self.contentView superview] setNeedsDisplayInRect:[self titleBarRect]];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    [[self.contentView superview] setNeedsDisplay:YES];
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(windowDidBecomeKey:)]) {
        [self.delegate performSelector:@selector(windowDidBecomeKey:)
                            withObject:self];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:OBMenuBarWindowDidBecomeKey
                                                        object:self];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
    if (self.attachedToMenuBar)
    {
        [self orderOut:self];
    }
    [[self.contentView superview] setNeedsDisplayInRect:[self titleBarRect]];
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(windowDidResignKey:)]) {
        [self.delegate performSelector:@selector(windowDidResignKey:)
                            withObject:self];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:OBMenuBarWindowDidResignKey
                                                        object:self];
}

#pragma mark - Showing the window

- (NSPoint)originForAttachedState
{
    if (statusItemView) {
        NSRect statusItemFrame = statusItemView.window.frame;

        NSPoint midPoint = NSMakePoint(NSMidX(statusItemFrame),
                                       NSMinY(statusItemFrame));

        return NSMakePoint(midPoint.x - (self.frame.size.width / 2),
                           midPoint.y - self.frame.size.height - OBMenuBarWindowArrowOffset);
    }

    return NSZeroPoint;
}

- (void)makeKeyAndOrderFront:(id)sender
{
    if (self.attachedToMenuBar)
    {
        NSPoint origin = [self originForAttachedState];
        [self setFrameOrigin:origin];
    }
    [super makeKeyAndOrderFront:sender];
}

- (void)orderOut:(id)sender
{
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:0.1];
        [self.animator setAlphaValue:0];
    } completionHandler:^{
        [super orderOut:self];
        [self setAlphaValue:1.0];
    }];
}

#pragma mark - Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
    dragStartLocation = [NSEvent mouseLocation];
    dragStartFrame = self.frame;
    NSPoint mouseLocationInWindow = [theEvent locationInWindow];
    isDragging = NSPointInRect(mouseLocationInWindow, [self toolbarRect]);
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if ([theEvent clickCount] == 2 && isDragging){
        if (self.attachedToMenuBar) {
            [self performSelector:@selector(detachFromMenuBar:) withObject:NULL afterDelay:0.0];
        }
        else {
            [self performSelector:@selector(attachToMenuBar:) withObject:NULL afterDelay:0.0];
        }
    }
    else if (isDragging)
    {
        NSRect visibleRect = [[self screen] visibleFrame];
        CGFloat minY = NSMinY(visibleRect);
        if (NSMaxY(self.frame) - OBMenuBarWindowArrowHeight - OBMenuBarWindowSnapOffset < minY)
        {
            [self setFrameOrigin:NSMakePoint(self.frame.origin.x, minY - self.frame.size.height + OBMenuBarWindowArrowHeight + OBMenuBarWindowSnapOffset)];
        }
    }
    isDragging = NO;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    if ([theEvent type] == NSLeftMouseDragged)
    {
        NSPoint newLocation = [NSEvent mouseLocation];
        if (isDragging)
        {
            CGFloat originX = dragStartFrame.origin.x + newLocation.x - dragStartLocation.x;
            CGFloat originY = dragStartFrame.origin.y + newLocation.y - dragStartLocation.y;
            [self setFrameOrigin:NSMakePoint(originX, originY)];
        }
    }
}

#pragma mark - Resizing events

- (void)windowDidResize:(NSNotification *)aNotification
{
    [self layoutContent];
}

- (void)windowWillStartLiveResize:(NSNotification *)aNotification
{
    resizeStartFrame = self.frame;
    NSPoint point = [self mouseLocationOutsideOfEventStream];
    resizeStartLocation = [self convertRectToScreen:NSMakeRect(point.x, point.y, 1, 1)].origin;
     //resizeStartLocation = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
    resizeRight = ([self mouseLocationOutsideOfEventStream].x > self.frame.size.width / 2.0);
}

#pragma mark - Positioning events

- (void)windowDidMove:(NSNotification *)aNotification
{
    if (![self inLiveResize] && self.statusItem)
    {
        NSRect frame = [self frame];
        NSPoint arrowPoint = NSMakePoint(NSMidX(frame), NSMaxY(frame));
        NSRect statusItemFrame = [[statusItemView window] frame];
        NSPoint statusItemPoint = NSMakePoint(NSMidX(statusItemFrame), NSMinY(statusItemFrame));
        double distance = sqrt(pow(arrowPoint.x - statusItemPoint.x, 2) + pow(arrowPoint.y - statusItemPoint.y, 2));
        if (distance <= self.snapDistance)
        {
            [self setFrameOrigin:[self originForAttachedState]];
            self.attachedToMenuBar = YES;
        }
        else
        {
            self.attachedToMenuBar = NO;
        }
    }

    [self layoutContent];
}

- (void)statusItemViewDidMove:(NSNotification *)aNotification
{
    if (self.attachedToMenuBar)
    {
        [self setFrameOrigin:[self originForAttachedState]];
    }
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag
{
    if ([self inLiveResize]) {
        if (self.attachedToMenuBar)
        {
            //NSPoint mouseLocation = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
            NSPoint point = [self mouseLocationOutsideOfEventStream];
            NSPoint mouseLocation = [self convertRectToScreen:NSMakeRect(point.x, point.y, 1, 1)].origin;

            NSRect newFrame = resizeStartFrame;
            if (frameRect.size.width != resizeStartFrame.size.width)
            {
                CGFloat deltaWidth = (resizeRight ? mouseLocation.x - resizeStartLocation.x : resizeStartLocation.x - mouseLocation.x);
                newFrame.origin.x -= deltaWidth;
                newFrame.size.width += deltaWidth * 2;
                if (newFrame.size.width < self.minSize.width)
                {
                    newFrame.size.width = self.minSize.width;
                    newFrame.origin.x = NSMidX(resizeStartFrame) - (self.minSize.width) / 2.0;
                }
                if (newFrame.size.width > self.maxSize.width)
                {
                    newFrame.size.width = self.maxSize.width;
                    newFrame.origin.x = NSMidX(resizeStartFrame) - (self.maxSize.width) / 2.0;
                }
            }

            // Don't allow resizing upwards when attached to menu bar
            if (frameRect.origin.y != resizeStartFrame.origin.y)
            {
                newFrame.origin.y = frameRect.origin.y;
                newFrame.size.height = frameRect.size.height;
            }

            [self resetContentImagesScheduleRefresh:NO];
            [super setFrame:newFrame display:YES];
        }
        else {
            [self resetContentImagesScheduleRefresh:NO];
            [super setFrame:frameRect display:flag];
        }
    }
    else {
        [self resetContentImagesScheduleRefresh:YES];
        [super setFrame:frameRect display:flag];
    }
}

#pragma mark - Drawing

- (NSWindow *)window
{
    return self;
}

- (NSImage *)noiseImage
{
    if (noiseImage == nil)
    {
        size_t dimension = 100;
        size_t bytes = dimension * dimension * 4;

        //CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);

        // Fix rainbow noise when selected device-independent monitor profile
        // Values got from: http://stackoverflow.com/questions/501199/disabling-color-correction-in-quartz-2d
        const CGFloat whitePoint[] = {0.95047, 1.0, 1.08883};
        const CGFloat blackPoint[] = {0, 0, 0};
        const CGFloat gamma[] = {1, 1, 1};
        const CGFloat matrix[] = {0.449695, 0.244634, 0.0251829, 0.316251, 0.672034, 0.141184, 0.18452, 0.0833318, 0.922602 };
        CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateCalibratedRGB(whitePoint, blackPoint, gamma, matrix);

        unsigned char *data = malloc(bytes);
        unsigned char grey;
        for (NSUInteger i = 0; i < bytes; i += 4)
        {
            grey = rand() % 256;
            data[i] = grey;
            data[i + 1] = grey;
            data[i + 2] = grey;
            data[i + 3] = 6;
        }
        CGContextRef contextRef = CGBitmapContextCreate(data, dimension, dimension, 8, dimension * 4, colorSpaceRef,(CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
        noiseImage = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(dimension, dimension)];
        CGImageRelease(imageRef);
        CGContextRelease(contextRef);
        free(data);
        CGColorSpaceRelease(colorSpaceRef);
    }
    return noiseImage;
}

- (void)renderContentForKeyWindow:(BOOL)isKey
{
    OBMenuBarWindow *window = (OBMenuBarWindow *)[self window];

    if (!window.toolbarView) {
        return;
    }
    
    self.cachedContentScale = window.screen.backingScaleFactor;

    NSRect bounds = [window.contentView superview].bounds;
    CGFloat originX = bounds.origin.x;
    CGFloat originY = bounds.origin.y;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat arrowHeight = OBMenuBarWindowArrowHeight;
    CGFloat arrowWidth = OBMenuBarWindowArrowWidth;
    CGFloat cornerRadius = OBMenuBarWindowCornerRadius;
    CGFloat hairlineWidth = 1 / self.cachedContentScale;
    CGFloat strokeWidth = self.cachedContentScale == 1 ? 0.5 : hairlineWidth;
    CGFloat arrowPinRadius = self.cachedContentScale == 1 ? 4 : OBMenuBarWindowArrowPinRadius;
    BOOL isAttached = window.attachedToMenuBar;

    // Create the window shape
    NSPoint arrowPointLeft = NSMakePoint(originX + (width - arrowWidth) / 2.0 /*- (isAttached ? hairlineWidth / 2 : 0)*/,
                                         originY + height - (isAttached ? arrowHeight : 0));
    NSPoint arrowPointMiddle = NSMakePoint(originX + width / 2.0,
                                           originY + height /*+ (isAttached ? hairlineWidth / 2 : 0)*/);
    NSPoint arrowPointRight = NSMakePoint(originX + (width + arrowWidth) / 2.0 /*+ (isAttached ? hairlineWidth / 2 : 0)*/,
                                          originY + height - (isAttached ? arrowHeight : 0));
    NSPoint topLeft = NSMakePoint(originX,
                                  originY + height - (isAttached ? arrowHeight : 0));
    NSPoint topRight = NSMakePoint(originX + width,
                                   originY + height - (isAttached ? arrowHeight : 0));
    NSPoint bottomLeft = NSMakePoint(originX,
                                     originY + height - (isAttached ? arrowHeight : 0) - window.toolbarView.frame.size.height);
    NSPoint bottomRight = NSMakePoint(originX + width,
                                      originY + height - (isAttached ? arrowHeight : 0) - window.toolbarView.frame.size.height);

    // Erase the window content
    NSRectFillUsingOperation(NSMakeRect(originX, originY, width, height), NSCompositeClear);

    // Draw the window background

    NSPoint listBottomRight = NSMakePoint(originX + width, originY);
    NSPoint listBottomLeft = NSMakePoint(originX, originY);

    NSBezierPath *listPath = [NSBezierPath bezierPath];

    [listPath moveToPoint:bottomRight];
    [listPath lineToPoint:NSMakePoint(listBottomRight.x, listBottomRight.y + cornerRadius)];

    [listPath appendBezierPathWithArcFromPoint:listBottomRight
                                       toPoint:NSMakePoint(listBottomLeft.x + cornerRadius, listBottomRight.y)
                                        radius:cornerRadius];

    [listPath appendBezierPathWithArcFromPoint:listBottomLeft
                                       toPoint:bottomLeft
                                        radius:cornerRadius];
    [listPath lineToPoint:bottomLeft];



    [NSGraphicsContext saveGraphicsState];

    [listPath setLineWidth:hairlineWidth];
    [listPath addClip];

    [window.colorTheme.listBackgroundColor setFill];
    [listPath fill];

    if (window.colorTheme.listStrokeColor) {
        [window.colorTheme.listStrokeColor setStroke];
        [listPath setLineWidth:strokeWidth];
        [listPath stroke];
    }
    
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *toolbarPath = [NSBezierPath bezierPath];

    BOOL drawRoundedArrow = YES;

    // Arrow Pin
    if (drawRoundedArrow) {

        [toolbarPath moveToPoint:bottomLeft];

        [toolbarPath appendBezierPathWithArcFromPoint:bottomLeft
                                              toPoint:topLeft
                                               radius:cornerRadius];
        [toolbarPath appendBezierPathWithArcFromPoint:topLeft
                                              toPoint:arrowPointLeft
                                               radius:cornerRadius];

        [toolbarPath appendBezierPathWithArcFromPoint:arrowPointLeft
                                              toPoint:arrowPointMiddle
                                               radius:OBMenuBarWindowArrowBaseRadius];
        [toolbarPath appendBezierPathWithArcFromPoint:arrowPointMiddle
                                              toPoint:arrowPointRight
                                               radius:arrowPinRadius];

        [toolbarPath appendBezierPathWithArcFromPoint:arrowPointRight
                                              toPoint:topRight
                                               radius:OBMenuBarWindowArrowBaseRadius];
        [toolbarPath appendBezierPathWithArcFromPoint:topRight
                                              toPoint:bottomRight
                                               radius:cornerRadius];
        [toolbarPath lineToPoint:bottomRight];
    }
    else {
        [toolbarPath moveToPoint:arrowPointLeft];
        [toolbarPath lineToPoint:arrowPointMiddle];
        [toolbarPath lineToPoint:arrowPointRight];

        [toolbarPath appendBezierPathWithArcFromPoint:arrowPointRight
                                             toPoint:topRight
                                              radius:cornerRadius];
        [toolbarPath appendBezierPathWithArcFromPoint:topRight
                                             toPoint:bottomRight
                                              radius:cornerRadius];
        [toolbarPath lineToPoint:bottomRight];
        [toolbarPath lineToPoint:bottomLeft];
        [toolbarPath appendBezierPathWithArcFromPoint:topLeft
                                             toPoint:arrowPointLeft
                                              radius:cornerRadius];
    }

    [toolbarPath closePath];

    // Draw the title bar
    [NSGraphicsContext saveGraphicsState];

    [toolbarPath addClip];

    CGFloat titleBarHeight = window.toolbarView.frame.size.height + (isAttached ? OBMenuBarWindowArrowHeight : 0);
    
    NSRect headingRect = NSMakeRect(originX,
                                    originY + height - titleBarHeight,
                                    width,
                                    window.toolbarView.frame.size.height);
    NSRect titleBarRect = NSMakeRect(originX,
                                     originY + height - titleBarHeight,
                                     width,
                                     window.toolbarView.frame.size.height + OBMenuBarWindowArrowHeight);

    // Colors
    NSColor *bottomColor, *topColor, *topColorTransparent;

    if (window.colorTheme) {
        if (isKey || window.attachedToMenuBar)
        {
            bottomColor = window.colorTheme.toolbarEndColor;
            topColor = window.colorTheme.toolbarStartColor;
            topColorTransparent = [NSColor colorWithCalibratedRed:topColor.redComponent green:topColor.greenComponent blue:topColor.blueComponent alpha:0.0];
        }
        else
        {
            bottomColor = [window.colorTheme.toolbarEndColor highlightWithLevel:0.2];
            topColor = [window.colorTheme.toolbarStartColor highlightWithLevel:0.2];
            topColorTransparent = [[NSColor colorWithCalibratedRed:topColor.redComponent green:topColor.greenComponent blue:topColor.blueComponent alpha:0.0] highlightWithLevel:0.15];
        }
    }
    else {
        if (isKey || window.attachedToMenuBar)
        {
            bottomColor = [NSColor colorWithCalibratedWhite:0.690 alpha:1.0];
            topColor = [NSColor colorWithCalibratedWhite:0.910 alpha:1.0];
            topColorTransparent = [NSColor colorWithCalibratedWhite:0.910 alpha:0.0];
        }
        else
        {
            bottomColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
            topColor = [NSColor colorWithCalibratedWhite:0.93 alpha:1.0];
            topColorTransparent = [NSColor colorWithCalibratedWhite:0.93 alpha:0.0];
        }
    }

    [bottomColor set];
    //NSRectFill(window.attachedToMenuBar ? titleBarRect : headingRect);
    [toolbarPath fill];

    // Draw some subtle noise to the titlebar if the window is the key window
    if (isKey || attachedToMenuBar)
    {
        [[NSColor colorWithPatternImage:[window noiseImage]] set];
        NSRectFillUsingOperation(window.attachedToMenuBar ? titleBarRect : headingRect, NSCompositeSourceOver);
    }

    // Draw the highlight
    NSGradient *headingGradient = [[NSGradient alloc] initWithStartingColor:topColorTransparent
                                                                endingColor:topColor];
    [headingGradient drawInRect:headingRect angle:90.0];

    // Highlight the pin, too
    if (isAttached)
    {
        NSColor *tipColor = [topColor highlightWithLevel:0.15];
        NSGradient *tipGradient = [[NSGradient alloc] initWithStartingColor:topColor
                                                                endingColor:tipColor];
        NSRect tipRect = NSMakeRect(arrowPointLeft.x - OBMenuBarWindowArrowWidth / 2,
                                    arrowPointLeft.y,
                                    OBMenuBarWindowArrowWidth * 2,
                                    OBMenuBarWindowArrowHeight);
        [tipGradient drawInRect:tipRect angle:90.0];
    }

    // Draw the title bar highlight
    /*NSBezierPath *highlightPath = [NSBezierPath bezierPath];
    [highlightPath moveToPoint:NSMakePoint(arrowPointMiddle.x,arrowPointMiddle.y - 0.5)];
    [highlightPath lineToPoint:NSMakePoint(arrowPointLeft.x, arrowPointLeft.y - 0.5)];
    [highlightPath appendBezierPathWithArcFromPoint:NSMakePoint(topLeft.x + 0.5, topLeft.y - 0.5)
                                            toPoint:NSMakePoint(bottomLeft.x - 0.5, topLeft.y - cornerRadius)
                                             radius:cornerRadius];

    [highlightPath moveToPoint:NSMakePoint(arrowPointMiddle.x,arrowPointMiddle.y - 0.5)];
    [highlightPath lineToPoint:NSMakePoint(arrowPointRight.x, arrowPointRight.y - 0.5)];
    [highlightPath appendBezierPathWithArcFromPoint:NSMakePoint(topRight.x - 0.5, topRight.y - 0.5)
                                            toPoint:NSMakePoint(bottomRight.x + 0.5, topRight.y - cornerRadius)
                                             radius:cornerRadius];
    [[window.colorTheme.toolbarShadowColor highlightWithLevel:0.5] set];
    [highlightPath setLineWidth:window.colorTheme.toolbarStrokeColor ? 2.0 : 1.0];
    [highlightPath stroke];*/

//    [[NSColor colorWithCalibratedWhite:0.5 alpha:0.5] set];
//    [borderPath stroke];

    [NSGraphicsContext restoreGraphicsState];

    // Draw title
    
    [NSGraphicsContext saveGraphicsState];
    
    NSMutableDictionary *titleAttributes = [[NSMutableDictionary alloc] init];
    [titleAttributes setValue:[NSColor colorWithCalibratedWhite:1.0 alpha:0.85] forKey:NSForegroundColorAttributeName];
    [titleAttributes setValue:[NSFont fontWithName:@"Helvetica Light" size:15] forKey:NSFontAttributeName];
    NSShadow *stringShadow = [[NSShadow alloc] init];
    [stringShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
    [stringShadow setShadowOffset:NSMakeSize(0, 0)];
    [stringShadow setShadowBlurRadius:6];
    [titleAttributes setValue:stringShadow forKey:NSShadowAttributeName];
    NSSize titleSize = [window.title sizeWithAttributes:titleAttributes];

    NSPoint centerPoint;

    centerPoint.x = isAttached ? 10 : (width / 2) - (titleSize.width / 2);
    centerPoint.y = topLeft.y - (window.toolbarView.frame.size.height / 2) /*- (window.attachedToMenuBar ? OBMenuBarWindowArrowHeight / 2 : 0)*/ - (titleSize.height / 2);

    [window.title drawAtPoint:centerPoint withAttributes:titleAttributes];

    // Draw separator line between the titlebar and the content view
    if (isKey) {
        [[window.colorTheme.listBackgroundColor shadowWithLevel:0.5] set];
    }
    else {
        [[window.colorTheme.listBackgroundColor shadowWithLevel:0.2] set];
    }
    NSRect separatorRect = NSMakeRect(originX, originY + height - window.toolbarView.frame.size.height - (isAttached ? arrowHeight : 0) - hairlineWidth, width, hairlineWidth);
    NSRectFill(separatorRect);

    // Draw toolbar stroke
    if (window.colorTheme.toolbarStrokeColor) {
        
        // Stroke open path
        NSBezierPath *strokePath = [NSBezierPath bezierPath];

        if (drawRoundedArrow) {

            [strokePath moveToPoint:bottomLeft];

            [strokePath appendBezierPathWithArcFromPoint:bottomLeft
                                                  toPoint:topLeft
                                                   radius:cornerRadius];
            [strokePath appendBezierPathWithArcFromPoint:topLeft
                                                  toPoint:arrowPointLeft
                                                   radius:cornerRadius];

            [strokePath appendBezierPathWithArcFromPoint:arrowPointLeft
                                                  toPoint:arrowPointMiddle
                                                   radius:OBMenuBarWindowArrowBaseRadius];
            [strokePath appendBezierPathWithArcFromPoint:arrowPointMiddle
                                                  toPoint:arrowPointRight
                                                   radius:arrowPinRadius];

            [strokePath appendBezierPathWithArcFromPoint:arrowPointRight
                                                  toPoint:topRight
                                                   radius:OBMenuBarWindowArrowBaseRadius];
            [strokePath appendBezierPathWithArcFromPoint:topRight
                                                  toPoint:bottomRight
                                                   radius:cornerRadius];
            [strokePath lineToPoint:bottomRight];
        }
        else {
            [strokePath moveToPoint:arrowPointLeft];
            [strokePath lineToPoint:arrowPointMiddle];
            [strokePath lineToPoint:arrowPointRight];
            [strokePath appendBezierPathWithArcFromPoint:topRight
                                                 toPoint:bottomRight
                                                  radius:cornerRadius];
            [strokePath lineToPoint:bottomRight];
            [strokePath moveToPoint:bottomLeft];
            [strokePath appendBezierPathWithArcFromPoint:topLeft
                                                 toPoint:arrowPointLeft
                                                  radius:cornerRadius];
            [strokePath lineToPoint:arrowPointLeft];
        }

        if (isKey) {
            [window.colorTheme.toolbarStrokeColor set];
        }
        else {
            [[window.colorTheme.toolbarStrokeColor highlightWithLevel:0.25] set];
        }

        [toolbarPath setLineWidth:hairlineWidth];
        [toolbarPath setLineJoinStyle:NSRoundLineJoinStyle];
        [toolbarPath addClip];

        [strokePath setLineWidth:strokeWidth];
        [strokePath setLineJoinStyle:NSRoundLineJoinStyle];
        [strokePath stroke];
    }

    [NSGraphicsContext restoreGraphicsState];

    //[self setHasShadow:NO];

    /*CGMutablePathRef shadowPath = CGPathCreateMutable();

    CGPathMoveToPoint(shadowPath, NULL, bottomLeft.x, bottomLeft.y);
    CGPathAddArcToPoint(shadowPath, NULL, bottomLeft.x, bottomLeft.y, topLeft.x, topLeft.y, cornerRadius);
    CGPathAddArcToPoint(shadowPath, NULL, topLeft.x, topLeft.y, topLeft.x, topLeft.y, cornerRadius);
    CGPathAddArcToPoint(shadowPath, NULL, arrowPointLeft.x, arrowPointLeft.y, arrowPointMiddle.x, arrowPointMiddle.y, OBMenuBarWindowArrowBaseRadius);
    CGPathAddArcToPoint(shadowPath, NULL, arrowPointMiddle.x, arrowPointMiddle.y, arrowPointRight.x, arrowPointRight.y, arrowPinRadius);
    CGPathAddArcToPoint(shadowPath, NULL, arrowPointRight.x, arrowPointRight.y, topRight.x, topRight.y, OBMenuBarWindowArrowBaseRadius);
    CGPathAddArcToPoint(shadowPath, NULL, topRight.x, topRight.y, bottomRight.x, bottomRight.y, cornerRadius);
    CGPathAddLineToPoint(shadowPath, NULL, bottomRight.x, bottomRight.y);
    CGPathAddLineToPoint(shadowPath, NULL, listBottomRight.x, listBottomRight.y + cornerRadius);
    CGPathAddArcToPoint(shadowPath, NULL, listBottomRight.x, listBottomRight.y, listBottomLeft.x + cornerRadius, listBottomRight.y, cornerRadius);
    CGPathAddArcToPoint(shadowPath, NULL, listBottomLeft.x, listBottomLeft.y, bottomLeft.x, bottomLeft.y, cornerRadius);
    CGPathAddLineToPoint(shadowPath, NULL, bottomLeft.x, bottomLeft.y);
    CGPathCloseSubpath(shadowPath);

    NSView * shadowView = [super contentView];

    shadowView.wantsLayer = NO;
    shadowView.layer.s
    shadowView.layer.shadowColor = [NSColor blackColor].CGColor;
    shadowView.layer.shadowOpacity = 0.35f;
    shadowView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    shadowView.layer.shadowRadius = 3.0f;
    shadowView.layer.masksToBounds = NO;
    shadowView.layer.shadowPath = shadowPath;

    CGPathRelease(shadowPath);*/

}

- (void)refreshContentImageForKeyWindow:(BOOL)isKey
{
    NSImage *contentImage = [[NSImage alloc] initWithSize:NSMakeSize([self.contentView superview].bounds.size.width, [self.contentView superview].bounds.size.height)];

    [contentImage lockFocus];

    [self renderContentForKeyWindow:isKey];
    
    [contentImage unlockFocus];

    if (isKey) {
        _activeImage = contentImage;
        //NSLog(@"Active image refreshed");
    }
    else {
        _inactiveImage = contentImage;
        //NSLog(@"Inactive image refreshed");
    }
}

- (void)resetContentImagesScheduleRefresh:(BOOL)scheduleRefresh
{
    if (_activeImage || _inactiveImage) {
        _activeImage = nil;
        _inactiveImage = nil;

        //NSLog(@"reset");
    }

    if (scheduleRefresh) {

        self.scheduledRefreshCount++;

        [self performSelector:@selector(refreshContentImages) withObject:nil afterDelay:0.5];
    }
}

- (void)refreshContentImages
{
    if (--self.scheduledRefreshCount) {
        return;
    }
    
    //if (!_activeImage) {
        [self refreshContentImageForKeyWindow:YES];
        //NSLog(@"active image refreshed");
        //}

    //if (!_inactiveImage) {
        [self refreshContentImageForKeyWindow:NO];
        //NSLog(@"inactive image refreshed");
        //}

    // Redraw the theme frame
    [[self.contentView superview] setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (!self.toolbarView) {
        return;
    }

    if (self.cachedContentScale != self.screen.backingScaleFactor) {
        [self resetContentImagesScheduleRefresh:YES];
    }
    
    NSImage *content = self.isKeyWindow || self.attachedToMenuBar ? self.activeImage : self.inactiveImage;

    if (!content) {
        [self renderContentForKeyWindow:self.isKeyWindow];
    }
    else {
        [content drawInRect:dirtyRect fromRect:dirtyRect operation:NSCompositeCopy fraction:1.0];
    }
}

@end
