//
//  GNTPRegisterPacket.m
//  GNTPTestServer
//
//  Created by Daniel Siemer on 7/4/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "GNTPRegisterPacket.h"
#import "GrowlDefines.h"
#import "GrowlDefinesInternal.h"

@interface GNTPRegisterPacket ()

@property (nonatomic, assign) NSUInteger totalNotifications;
@property (nonatomic, assign) NSUInteger readNotifications;

@end

@implementation GNTPRegisterPacket

@synthesize totalNotifications = _totalNotifications;
@synthesize readNotifications = _readNotifications;
@synthesize notificationDicts = _notificationDicts;

-(id)init {
	if((self = [super init])){
		_totalNotifications = 0;
		_readNotifications = 0;
		_notificationDicts = [[NSMutableArray alloc] init];
	}
	return self;
}

-(BOOL)validateNoteDictionary:(NSDictionary*)noteDict {
	
	return [noteDict valueForKey:GrowlGNTPNotificationName] != nil;
}

-(NSInteger)parseDataBlock:(NSData *)data
{
	NSInteger result = 0;
	switch (self.state) {
		case 101:
		{
			//Reading in notifications
			//break it down
			NSString *noteHeaderBlock = [NSString stringWithUTF8String:[data bytes]];
			NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
			[GNTPPacket enumerateHeaders:noteHeaderBlock
									 withBlock:^BOOL(NSString *headerKey, NSString *headerValue) {
										 if([headerValue isKindOfClass:[NSString class]]) {
											 NSRange resourceRange = [headerValue rangeOfString:@"x-growl-resource://"];
											 if(resourceRange.location != NSNotFound && resourceRange.location == 0){
												 //This is a resource ID; add the ID to the array of waiting IDs
												 NSString *dataBlockID = [headerValue substringFromIndex:resourceRange.location + resourceRange.length];
												 [self.dataBlockIdentifiers addObject:dataBlockID];
											 }
											 [dictionary setObject:headerValue forKey:headerKey];
										 }
										 return NO;
									 }];
			//validate
			if(![self validateNoteDictionary:dictionary]){
				NSLog(@"Unable to validate notification %@ in registration packet", dictionary);
			}else{
				[self.notificationDicts addObject:dictionary];
			}
			[dictionary release];
			//Even if we can't validate it, we did read it, skip it and move on
			self.readNotifications++;
			
			if(self.totalNotifications - self.readNotifications == 0) {
				if([self.dataBlockIdentifiers count] > 0)
					self.state = 1;
				else{
					self.state = 999;
				}
			}
			break;
		}
		default:
			[super parseDataBlock:data];
			break;
	}
	if(self.totalNotifications == 0)
		result = -1;
	else
		result = (self.totalNotifications - self.readNotifications) + [self.dataBlockIdentifiers count];
	
	if(self.totalNotifications - self.readNotifications > 0) {
		self.state = 101; //More notifications to read, read them, otherwise state is controlled by the call to super parseDataBlock
	}
	
	return result;
}

-(void)parseHeaderKey:(NSString *)headerKey value:(NSString *)stringValue
{
	if([headerKey caseInsensitiveCompare:GrowlGNTPNotificationCountHeader] == NSOrderedSame){
		self.totalNotifications = [stringValue integerValue];
		if(self.totalNotifications == 0)
			NSLog(@"Error parsing %@ as an integer for a number of notifications", stringValue);
	}else{
		[super parseHeaderKey:headerKey value:stringValue];
	}
}

-(void)receivedResourceDataBlock:(NSData *)data forIdentifier:(NSString *)identifier {
	[self.notificationDicts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		//check the icon, its the main thing that will need replacing
		id icon = [obj objectForKey:GrowlGNTPNotificationIcon];
		if([icon isKindOfClass:[NSString class]] && [icon rangeOfString:identifier].location != NSNotFound){
			//Found an icon that matches the ID
			[obj setObject:data forKey:identifier];
		}
	}];
	//pass it back up to super in case there are things that need replacing up there
	[super receivedResourceDataBlock:data forIdentifier:identifier];
}

-(BOOL)validate {
	return [super validate] && self.totalNotifications == [self.notificationDicts count];
}

-(NSDictionary*)convertedGrowlDict {
	NSMutableDictionary *convertedDict = [[super convertedGrowlDict] retain];
	NSMutableArray *notificationNames = [NSMutableArray arrayWithCapacity:[self.notificationDicts count]];
	NSMutableDictionary *displayNames = [NSMutableDictionary dictionary];
	//2.0 framework should be upgraded to include descriptions
	NSMutableDictionary *notificationDescriptions = [NSMutableDictionary dictionary];
	NSMutableArray *enabledNotes = [NSMutableArray array];
	//Should really upgrade 2.0 to support note icons during registration;
	NSMutableDictionary *noteIcons = [NSMutableDictionary dictionary];
	[self.notificationDicts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *notificationName = [obj objectForKey:GrowlGNTPNotificationName];
		if(notificationName){
			[notificationNames addObject:notificationName];
			
			NSString *displayName = [obj objectForKey:GrowlGNTPNotificationDisplayName];
			NSString *enabledString = [obj objectForKey:GrowlGNTPNotificationEnabled];
			NSString *description = [obj objectForKey:@"X-Notification-Description"];
			id icon = [obj objectForKey:GrowlGNTPNotificationIcon];
			NSData *iconData = nil;
			
			if([icon isKindOfClass:[NSString class]]){
				/* 
				 * Download the URL if it can be made;
				 * We will get away with this blocking download method
				 * because this will be happening on a concurrent queue
				 */
				NSURL *url = [NSURL URLWithString:icon];
				if(url)
					iconData = [NSData dataWithContentsOfURL:url];
				else
					NSLog(@"Icon String: %@ is not a URL, and was not retrieved by the packet as a resource", icon);
			}else if([icon isKindOfClass:[NSData class]]){
				iconData = icon;
			}
			
			if(displayName)
				[displayNames setObject:displayName forKey:notificationName];
			if(description)
				[notificationDescriptions setObject:description forKey:notificationName];
			if(enabledString && 
				([enabledString caseInsensitiveCompare:@"Yes"] == NSOrderedSame || 
				[enabledString caseInsensitiveCompare:@"True"] == NSOrderedSame))
			{
				[enabledNotes addObject:notificationName];
			}
			if(iconData)
				[noteIcons setObject:iconData forKey:notificationName];
		}else{
			NSLog(@"Unable to process note without name!");
		}
	}];
	
	[convertedDict setObject:notificationNames forKey:GROWL_NOTIFICATIONS_ALL];
	if([enabledNotes count] > 0)
		[convertedDict setObject:enabledNotes forKey:GROWL_NOTIFICATIONS_DEFAULT];
	if([[displayNames allValues] count] > 0)
		[convertedDict setObject:displayNames forKey:GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES];
	if([[notificationDescriptions allValues] count] > 0)
		[convertedDict setObject:notificationDescriptions forKey:GROWL_NOTIFICATIONS_DESCRIPTIONS];
	if([noteIcons count] > 0)
		[convertedDict setObject:noteIcons forKey:@"NotificationIcons"];
	return [convertedDict autorelease];
}

@end
