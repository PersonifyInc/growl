//
//  GrowlGNTPKeyController.h
//  Growl
//
//  Created by Rudy Richter on 10/10/09.
//  Copyright 2009 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GNTPKey.h"

@interface GrowlGNTPKeyController : NSObject
{
	NSMutableDictionary *_storage;
}

+ (GrowlGNTPKeyController *)sharedInstance;

- (void)removeKeyForUUID:(NSString*)uuid;
- (void)setKey:(GNTPKey*)key forUUID:(NSString*)uuid;
- (GNTPKey*)keyForUUID:(NSString*)uuid;

@end
