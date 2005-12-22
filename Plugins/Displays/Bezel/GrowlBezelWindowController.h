//
//  GrowlBezelWindowController.h
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 09/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import "GrowlDisplayFadingWindowController.h"

@class GrowlBezelWindowView, GrowlAnimation;

@interface GrowlBezelWindowController : GrowlDisplayWindowController {

	int						priority;
	BOOL					flipIn;
	BOOL					flipOut;
	BOOL					shrinkEnabled;
	BOOL					flipEnabled;
	NSString				*identifier;
}

- (id) init;
- (void) setNotification: (GrowlApplicationNotification *) theNotification;
- (NSString *) identifier;
- (void) dealloc;

- (NSPoint) idealOriginInRect:(NSRect)rect;
- (GrowlExpansionDirection) primaryExpansionDirection;
- (GrowlExpansionDirection) secondaryExpansionDirection;
- (float) requiredDistanceFromExistingDisplays;

@end
