//
//  GrowlXPCCommunicationAttempt.m
//  Growl
//
//  Created by Rachel Blackman on 8/22/11.
//  Copyright 2011 The Growl Project. All rights reserved.
//

#import "GrowlXPCCommunicationAttempt.h"
#import "GrowlDefines.h"
#import "NSObject+XPCHelpers.h"
#import "GrowlGNTPDefines.h"

#import <xpc/xpc.h>

@implementation GrowlXPCCommunicationAttempt

@synthesize sendingDetails;
@synthesize responseDict;

+ (NSString*)XPCBundleID
{
	return [NSString stringWithFormat:@"%@.GNTPClientService", [[NSBundle mainBundle] bundleIdentifier]];
}

+ (BOOL)canCreateConnection
{   
	static BOOL searched = NO;
	static BOOL found = NO;
	if (xpc_connection_create == NULL)
		return NO;
	
	if(searched) 
		return found;
	
	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	NSString *xpcSubPath = [NSString stringWithFormat:@"Contents/XPCServices/%@", [self XPCBundleID]];
	NSString *xpcPath = [[appPath  stringByAppendingPathComponent:xpcSubPath] stringByAppendingPathExtension:@"xpc"];
	
	searched = YES;
	//If the file exists, and we can create an XPC, lets use it instead.
	if([[NSFileManager defaultManager] fileExistsAtPath:xpcPath]){
		found = YES;
		return YES;
	}
	else {
		return NO;
	}
}

- (NSString *)purpose
{
	return @"erehwon";
}

- (void)begin
{
	if (![self establishConnection]) {
		[self failed];
		return;
	}
	
	if (![self sendMessageWithPurpose:[self purpose]])
		[self failed];
}

- (void)finished
{
	[super finished];
}

- (BOOL) establishConnection
{
	if (xpc_connection_create == NULL) {
		// We are not on Lion.  We can't do this.
		return NO;
	}
	
	__block GrowlXPCCommunicationAttempt *blockSafe = self;
	//Third party developers will need to make sure to rename the bundle, executable, and info.plist stuff to tld.company.product.GNTPClientService 
	xpcConnection = xpc_connection_create([[GrowlXPCCommunicationAttempt XPCBundleID] UTF8String], dispatch_get_main_queue());
	if (!xpcConnection)
		return NO;
	xpc_connection_set_event_handler(xpcConnection, ^(xpc_object_t object) {
		xpc_type_t type = xpc_get_type(object);
		
		if (type == XPC_TYPE_ERROR) {
			
			if (object == XPC_ERROR_CONNECTION_INTERRUPTED) {
				//NSLog(@"Interrupted connection to XPC service %@", blockSafe);
			} else if (object == XPC_ERROR_CONNECTION_INVALID) {
				NSString *errorDescription = [NSString stringWithUTF8String:xpc_dictionary_get_string(object, XPC_ERROR_KEY_DESCRIPTION)];
				NSLog(@"Connection Invalid error for XPC service (%@)", errorDescription);
				xpc_release(xpcConnection);
				xpcConnection = NULL;
				[blockSafe failed];
			} else {
				NSLog(@"Unexpected error for XPC service");
				[blockSafe failed];
			}
			[blockSafe finished];
		} else {
			[blockSafe handleReply:object];
		}
		
	});
	xpc_connection_resume(xpcConnection);
	return YES;
}

- (void) handleReply:(xpc_object_t)reply
{
	// We received a reply, which will either be a 'success' marker 
	// for registration, or some horrific failure.  "Do or do not,
	// there is no try."
	
	xpc_type_t type = xpc_get_type(reply);
	
	if (XPC_TYPE_ERROR == type) {
		[self failed];
		[self finished];
		return; 
	}
	
	if (XPC_TYPE_DICTIONARY != type) {
		[self failed];
		[self finished];
		return;
	}
	
	NSDictionary *dict = [NSObject xpcObjectToNSObject:reply];
	NSString *responseAction = [dict objectForKey:@"GrowlActionType"];
	
	if([responseAction isEqualToString:@"reregister"]){
		[self queueAndReregister];
	}else if([responseAction isEqualToString:@"feedback"]){
		BOOL clicked = [[dict objectForKey:@"Clicked"] boolValue];
		NSString *context = [dict objectForKey:@"Context"];
		if(clicked){
			if(delegate && [delegate respondsToSelector:@selector(notificationClicked:context:)])
				[delegate notificationClicked:self context:context];
		}else{
			if(delegate && [delegate respondsToSelector:@selector(notificationTimedOut:context:)])
				[delegate notificationTimedOut:self context:context];
		}
	}else if([responseAction isEqualToString:@"stoppedAttempts"]){
		[self stopAttempts];
	}else if([responseAction isEqualToString:@"finishedAttempt"]){
		[self finished];
	}else{
		self.responseDict = dict;
		BOOL success = [dict objectForKey:@"Success"] != nil ? [[dict objectForKey:@"Success"] boolValue] : NO;
		if (success){
			[self succeeded];
		}else{
			GrowlGNTPErrorCode reason = (GrowlGNTPErrorCode)[[dict objectForKey:@"Error-Code"] integerValue];
			NSString *description = [dict objectForKey:@"Error-Description"];
			NSLog(@"Failed with code %ld, \"%@\"", reason, description);
			if([responseAction isEqualToString:@"notification"] && reason == GrowlGNTPUserDisabledErrorCode){
				[self stopAttempts];
			}else{
				[self failed];
			}
		}
	}
}

- (BOOL) sendMessageWithPurpose:(NSString *)purpose
{
	if (!xpcConnection)
		return NO;
	
	NSMutableDictionary *messageDict = [NSMutableDictionary dictionary];
	[messageDict setObject:purpose forKey:@"GrowlDictType"];
	[messageDict setObject:self.dictionary forKey:@"GrowlDict"];
	if(self.sendingDetails){
		//Get our host/address/password to send
		NSString *host = [sendingDetails objectForKey:@"GNTPHost"];
		NSString *password = [sendingDetails objectForKey:@"GNTPPassword"];
		NSData *addressData = [sendingDetails objectForKey:@"GNTPAddressData"];
		if(host)
			[messageDict setObject:host forKey:@"GNTPHost"];
		if(password)
			[messageDict setObject:password forKey:@"GNTPPassword"];
		if(addressData)
			[messageDict objectForKey:@"GNTPAddressData"];
	}
	
	xpc_object_t xpcMessage = [(NSObject*)messageDict newXPCObject];
	if(xpcMessage){
		xpc_connection_send_message(xpcConnection, xpcMessage);
		xpc_release(xpcMessage);
	}else{
		NSLog(@"Error generating XPC message for dictionary: %@", dictionary);
		return NO;
	}
	return YES;
}

@end
