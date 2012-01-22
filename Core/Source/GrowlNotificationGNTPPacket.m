//
//  GrowlNotificationGNTPPacket.m
//  Growl
//
//  Created by Evan Schoenberg on 10/2/08.
//  Copyright 2008-2009 The Growl Project. All rights reserved.
//

#import "GrowlNotificationGNTPPacket.h"
#import "GrowlGNTPHeaderItem.h"
#import "GrowlGNTPBinaryChunk.h"
#import "GrowlDefines.h"
#import "GrowlImageAdditions.h"
#import "ISO8601DateFormatter.h"

@implementation GrowlNotificationGNTPPacket

#if GROWLHELPERAPP

- (id)init
{
	if ((self = [super init])) {
		notificationDict = [[NSMutableDictionary alloc] init];
		callbackTargetMethod = CallbackURLTargetUnknownMethod;
	} 
	return self;
}
- (void)dealloc
{
	[notificationDict release]; notificationDict = nil;

	[iconID release];
	[iconURL release];

	[super dealloc];
}

- (NSString *)applicationName
{
	return [notificationDict objectForKey:GROWL_APP_NAME];
}
- (void)setApplicationName:(NSString *)string
{
	[notificationDict setValue:string forKey:GROWL_APP_NAME];
}

- (NSString *)notificationName
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_NAME];
}
- (void)setNotificationName:(NSString *)string
{
	[notificationDict setObject:string
						 forKey:GROWL_NOTIFICATION_NAME];
}

- (NSString *)title
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_TITLE];
}
- (void)setTitle:(NSString *)string
{
	[notificationDict setObject:string
						 forKey:GROWL_NOTIFICATION_TITLE];
}

- (NSString *)identifier
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_INTERNAL_ID];
}
- (void)setIdentifier:(NSString *)string
{
	[notificationDict setObject:string
						 forKey:GROWL_NOTIFICATION_INTERNAL_ID];
	/* Now update our identifier and our delegate GrowlGNTPPacket's identifier */
	[self setPacketID:string];
}
- (NSString *)coalesceIdentifier
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_IDENTIFIER];
}
- (void)setCoalesceIdentifier:(NSString *)string
{
	[notificationDict setObject:string
						 forKey:GROWL_NOTIFICATION_IDENTIFIER];
}

- (NSString *)text
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION];
}
- (void)setText:(NSString *)string
{
	[notificationDict setObject:string
						 forKey:GROWL_NOTIFICATION_DESCRIPTION];
}

- (BOOL)sticky
{
	return [[notificationDict objectForKey:GROWL_NOTIFICATION_STICKY] boolValue];
}
- (void)setSticky:(BOOL)inSticky
{
	[notificationDict setObject:[NSNumber numberWithBool:inSticky]
						 forKey:GROWL_NOTIFICATION_STICKY];
}


- (void)setIconID:(NSString *)string
{
	[iconID autorelease];
	iconID = [string retain];
	
	if (!pendingBinaryIdentifiers) pendingBinaryIdentifiers = [[NSMutableSet alloc] init];
	[pendingBinaryIdentifiers addObject:iconID];
}
- (void)setIconURL:(NSURL *)url
{
	[iconURL autorelease];
	iconURL = [url retain];
	
	/* XXX Start loading the URL in the background */
}

- (void)setPriority:(int)priority
{
	[notificationDict setObject:[NSNumber numberWithInt:priority]
						 forKey:GROWL_NOTIFICATION_PRIORITY];
}
- (int)priority
{
	return [[notificationDict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue];
}

- (NSData *)iconData
{
	NSData *data = nil;
	if (iconID) {
		data = [binaryDataByIdentifier objectForKey:iconID];
	} else if (iconURL) {
      /* FIX ME: Implement a full, asynchronous download system */
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
         NSLog(@"URL based notification icon's are not presently supported.  Support will return in a future release of Growl.app");
      });
      NSLog(@"Not downloading icon for notification %@ of application %@", [self notificationName], [self applicationName]);
	}
	
	return data;
}

- (id)callbackContext
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT];
}
- (void)setCallbackContext:(id)value
{
	[notificationDict setObject:value
						 forKey:GROWL_NOTIFICATION_CLICK_CONTEXT];
}
- (NSString *)callbackContextType
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTENT_TYPE];
}
- (void)setCallbackContextType:(NSString *)value
{
	[notificationDict setObject:value
						 forKey:GROWL_NOTIFICATION_CLICK_CONTENT_TYPE];
}
- (NSString *)callbackTarget
{
	return [notificationDict objectForKey:GROWL_NOTIFICATION_CALLBACK_URL_TARGET];
}
- (void)setCallbackTarget:(NSString *)value
{
	[notificationDict setObject:value
						 forKey:GROWL_NOTIFICATION_CALLBACK_URL_TARGET];
}
- (void)setCallbackTargetMethod:(CallbackURLTargetMethod)inMethod
{
	[notificationDict setObject:(inMethod == CallbackURLTargetGetMethod ? @"GET" : @"POST")
						 forKey:GROWL_NOTIFICATION_CALLBACK_URL_TARGET_METHOD];
	callbackTargetMethod = inMethod;
}
- (void)addReceivedHeader:(NSString *)string
{
	NSMutableArray *receivedValues = [notificationDict valueForKey:GROWL_NOTIFICATION_GNTP_RECEIVED];
	if (!receivedValues) {
		receivedValues = [NSMutableArray array];
		[notificationDict setObject:receivedValues
							 forKey:GROWL_NOTIFICATION_GNTP_RECEIVED];
	}
	
	[receivedValues addObject:string];
}
- (void)setSentBy:(NSString *)string
{
	[notificationDict setValue:string forKey:GROWL_NOTIFICATION_GNTP_SENT_BY];
}
- (GrowlReadDirective)receivedHeaderItem:(GrowlGNTPHeaderItem *)headerItem
{
	NSString *name = [headerItem headerName];
	NSString *value = [headerItem headerValue];

	if (headerItem == [GrowlGNTPHeaderItem separatorHeaderItem]) {
		/* A notification just has a single section; we're done */
		if (pendingBinaryIdentifiers.count > 0)
			return GrowlReadDirective_SectionComplete;
		else
			return GrowlReadDirective_PacketComplete;
	}

	if ([name caseInsensitiveCompare:GrowlGNTPApplicationNameHeader] == NSOrderedSame) {
		[self setApplicationName:value];
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationName] == NSOrderedSame) {
		[self setNotificationName:value];	
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationTitle] == NSOrderedSame) {
		[self setTitle:value];	
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationID] == NSOrderedSame) {
		[self setIdentifier:value];	
	} else if ([name caseInsensitiveCompare:@"Notification-Coalescing-ID"] == NSOrderedSame) {
		[self setCoalesceIdentifier:value];
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationText] == NSOrderedSame) {
		[self setText:value];	
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationPriority] == NSOrderedSame) {
		int priority = [value intValue];
		if (priority >= -2 && priority <= 2)
			[self setPriority:priority];
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationSticky] == NSOrderedSame) {
		BOOL sticky = (
			   ([value caseInsensitiveCompare:@"Yes"] == NSOrderedSame)
			|| ([value caseInsensitiveCompare:@"True"] == NSOrderedSame)
			|| [value boolValue]
		);
		[self setSticky:sticky];	
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationIcon] == NSOrderedSame) {
		if ([value rangeOfString:@"x-growl-resource://" options:(NSLiteralSearch | NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound) {
			/* Extract the resource ID from the value */
			[self setIconID:[value substringFromIndex:[@"x-growl-resource://" length]]];
		} else {
			/* If it's not an x-growl-resource, it must be a URL. If value isn't an URL, we'll be setting
			 * iconURL to nil as NSURL returns nil. That's fine fall-through behavior.
			 */
			[self setIconURL:[NSURL URLWithString:value]];
		}
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationCallbackContext] == NSOrderedSame) {
      id clickContext = nil;
      if([self callbackContextType] && [[self callbackContextType] caseInsensitiveCompare:@"PList"] == NSOrderedSame){
            clickContext = [NSPropertyListSerialization propertyListWithData:[value dataUsingEncoding:NSUTF8StringEncoding]
                                                                     options:0
                                                                      format:NULL
                                                                       error:nil];
      }
      //If we don't know the type yet, or it isn't a PList, just set it as a string
      if(!clickContext)
         clickContext = value;

		[self setCallbackContext:clickContext];
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationCallbackContextType] == NSOrderedSame) {
      [self setCallbackContextType:value];
      //If we already have our context, and we find out it should be a PList serlialized, reset it
		if([self callbackContext] && [[self callbackContext] isKindOfClass:[NSString class]] 
         && [value caseInsensitiveCompare:@"PList"] == NSOrderedSame)
      {
         id newContext = [NSPropertyListSerialization propertyListWithData:[[self callbackContext] dataUsingEncoding:NSUTF8StringEncoding]
                                                                   options:0
                                                                    format:NULL
                                                                     error:nil];
         
         [self setCallbackContext:newContext];
      }
	} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationCallbackTarget] == NSOrderedSame) {
		[self setCallbackTarget:value];
	} else if ([name caseInsensitiveCompare:@"Notification-Callback-Target-Method"] == NSOrderedSame) {
		CallbackURLTargetMethod method;
		if ([value caseInsensitiveCompare:@"GET"] == NSOrderedSame) {
			method = CallbackURLTargetGetMethod;
		} else if ([value caseInsensitiveCompare:@"POST"] == NSOrderedSame) {
			method = CallbackURLTargetPostMethod;
		} else {
			method = CallbackURLTargetUnknownMethod;
		}

		[self setCallbackTargetMethod:method];
	} else if ([name caseInsensitiveCompare:@"Received"] == NSOrderedSame) {
		[self addReceivedHeader:value];
	} else if ([name caseInsensitiveCompare:@"Sent-By"] == NSOrderedSame) {
		[self setSentBy:value];
	} else if ([name caseInsensitiveCompare:GrowlGNTPOriginMachineName] == NSOrderedSame) {
		[notificationDict setObject:value
							 forKey:GROWL_GNTP_ORIGIN_MACHINE];
	} else if ([name caseInsensitiveCompare:GrowlGNTPOriginSoftwareName] == NSOrderedSame) {
		[notificationDict setObject:value
							 forKey:GROWL_GNTP_ORIGIN_SOFTWARE_NAME];
	} else if ([name caseInsensitiveCompare:GrowlGNTPOriginSoftwareVersion] == NSOrderedSame) {
		[notificationDict setObject:value
							 forKey:GROWL_GNTP_ORIGIN_SOFTWARE_VERSION];
	} else if ([name caseInsensitiveCompare:GrowlGNTPOriginPlatformName] == NSOrderedSame) {
		[notificationDict setObject:value
							 forKey:GROWL_GNTP_ORIGIN_PLATFORM_NAME];
	} else if ([name caseInsensitiveCompare:GrowlGNTPOriginPlatformVersion] == NSOrderedSame) {
		[notificationDict setObject:value
							 forKey:GROWL_GNTP_ORIGIN_PLATFORM_VERSION];
	} else if ([name caseInsensitiveCompare:GrowlGNTPApplicationPIDHeader] == NSOrderedSame) {
		[notificationDict setObject:value
							 forKey:GROWL_APP_PID];
	} else if ([name rangeOfString:@"X-" options:(NSLiteralSearch | NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound) {
		[self addCustomHeader:headerItem];
	}
	
	return GrowlReadDirective_Continue;
}

/*!
 * @brief Headers to be returned via the -OK success result
 */
- (NSArray *)headersForResult
{
	NSMutableArray *headersForResult = [[[super headersForResult] mutableCopy] autorelease];
	if (!headersForResult) headersForResult = [NSMutableArray array];
	[headersForResult addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationID value:[self identifier]]];

	return headersForResult;
}

#pragma mark Callbacks
- (GrowlGNTPCallbackBehavior)callbackResultSendBehavior
{
	if ([self callbackContext] && [self callbackContextType]) {
		if ([self callbackTarget] && (callbackTargetMethod != CallbackURLTargetUnknownMethod)) {
			return GrowlGNTP_URLCallback;
		} else {
			return GrowlGNTP_TCPCallback;
		}
	} else {
		return GrowlGNTP_NoCallback;	
	}
}

#endif

+ (GrowlGNTPCallbackBehavior)callbackResultSendBehaviorForHeaders:(NSArray *)headers
{		
	BOOL hasContext = NO, hasContextType = NO, hasTarget = NO;
	CallbackURLTargetMethod targetMethod = CallbackURLTargetUnknownMethod;

	for (GrowlGNTPHeaderItem *header in headers) {
		NSString *name = [header headerName];
		if ([name caseInsensitiveCompare:GrowlGNTPNotificationCallbackContext] == NSOrderedSame) {
			hasContext = YES;
		} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationCallbackContextType] == NSOrderedSame) {
			hasContextType = YES;
		} else if ([name caseInsensitiveCompare:GrowlGNTPNotificationCallbackTarget] == NSOrderedSame) {
			hasTarget = YES;
		} else if ([name caseInsensitiveCompare:@"Notification-Callback-Target-Method"] == NSOrderedSame) {
			NSString *value = [header headerValue];
			if ([value caseInsensitiveCompare:@"GET"] == NSOrderedSame) {
				targetMethod = CallbackURLTargetGetMethod;
			} else if ([value caseInsensitiveCompare:@"POST"] == NSOrderedSame) {
				targetMethod = CallbackURLTargetPostMethod;
			} else {
				targetMethod = CallbackURLTargetUnknownMethod;
			}
		}
	}
	
	if (hasContext && hasContextType) {
		if (hasTarget && (targetMethod != CallbackURLTargetUnknownMethod)) {
			return GrowlGNTP_URLCallback;
		} else {
			return GrowlGNTP_TCPCallback;
		}
	} else {
		return GrowlGNTP_NoCallback;	
	}
}

#if GROWLHELPERAPP

- (NSArray *)headersForCallbackResult_wasClicked:(BOOL)wasClicked
{
	ISO8601DateFormatter *formatter = [[[ISO8601DateFormatter alloc] init] autorelease];
	NSString *nowAsISO8601 = [formatter stringFromDate:[NSDate date]];

	NSMutableArray *headersForCallbackResult = [[[self headersForResult] mutableCopy] autorelease];
	[headersForCallbackResult addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationCallbackResult
																		  value:(wasClicked ? GrowlGNTPCallbackClicked : GrowlGNTPCallbackClosed)]];
	[headersForCallbackResult addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationCallbackTimestamp
																		  value:nowAsISO8601]];
	[headersForCallbackResult addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationCallbackContext value:[self callbackContext]]];
	[headersForCallbackResult addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationCallbackContextType value:[self callbackContextType]]];
	[headersForCallbackResult addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPApplicationNameHeader value:[self applicationName]]];

	if ([notificationDict objectForKey:GROWL_APP_PID]) {
		[headersForCallbackResult addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPApplicationPIDHeader value:[notificationDict objectForKey:GROWL_APP_PID]]];
	}
	
	return headersForCallbackResult;
}

- (NSURLRequest *)urlRequestForCallbackResult_wasClicked:(BOOL)wasClicked
{
	ISO8601DateFormatter *formatter = [[[ISO8601DateFormatter alloc] init] autorelease];
	NSString *nowAsISO8601 = [formatter stringFromDate:[NSDate date]];

	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

	NSMutableString *responsePost = [NSMutableString string];
	[responsePost appendFormat:@"%@=%@", GrowlGNTPNotificationID, [self identifier]];
	[responsePost appendFormat:@"&%@=%@", GrowlGNTPNotificationCallbackResult, (wasClicked ? GrowlGNTPCallbackClicked : GrowlGNTPCallbackClosed)];
	[responsePost appendFormat:@"&%@=%@", GrowlGNTPNotificationCallbackTimestamp, nowAsISO8601];
	[responsePost appendFormat:@"&%@=%@", GrowlGNTPNotificationCallbackContextType, [self callbackContextType]];
	[responsePost appendFormat:@"&%@=%@", GrowlGNTPNotificationCallbackContext, [self callbackContext]];
	[responsePost appendFormat:@"&%@=%@", GrowlGNTPApplicationNameHeader, [self applicationName]];

	for (GrowlGNTPHeaderItem *headerItem in [self customHeaders]) {
		[responsePost appendFormat:@"&%@=%@", [headerItem headerName], [headerItem headerValue]];
	}
	
	if (callbackTargetMethod == CallbackURLTargetPostMethod) {
		NSData *responsePostData = [responsePost dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
		NSString *responsePostLength = [NSString stringWithFormat:@"%d", [responsePostData length]];

		[request setHTTPMethod:@"POST"];
		[request setURL:[NSURL URLWithString:[self callbackTarget]]];
		[request setValue:responsePostLength forHTTPHeaderField:@"Content-Length"];
		[request setHTTPBody:responsePostData];
	
	} else /* CallbackURLTargetGetMethod */ {
		NSString *urlString = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																				  (CFStringRef)[NSString stringWithFormat:@"%@?%@", [self callbackTarget], responsePost],
																				  /* charactersToLeaveUnescaped */ NULL,
																				  /* legalURLCharactersToBeEscaped */ NULL,
																				  kCFStringEncodingUTF8);
		
	    [request setHTTPMethod:@"GET"];
		[request setURL:[NSURL URLWithString:urlString]];
		[urlString release];
	}

	return request;
}


/*!
 * @brief Return a Growl registration dictionary
 *
 * Dictionary format as per the documentation for GrowlApplicationBridgeDelegate_InformalProtocol's registrationDictionary
 * found in GrowlApplicationBridge.h.
 */
- (NSDictionary *)growlDictionary
{
	NSMutableDictionary *growlDictionary = [[[super growlDictionary] mutableCopy] autorelease];
	
	[growlDictionary addEntriesFromDictionary:notificationDict];
	[growlDictionary setValue:[self iconData]
					   forKey:GROWL_NOTIFICATION_ICON_DATA];
	
	return growlDictionary;
}

#endif

+ (void)getHeaders:(NSArray **)outHeadersArray binaryChunks:(NSArray **)outBinaryChunks notificationID:(NSString **)outNotificationID forNotificationDict:(NSDictionary *)dict
{
	NSMutableArray *headersArray = [NSMutableArray array];
	NSMutableArray *binaryChunks = [NSMutableArray array];

	if ([dict objectForKey:GROWL_APP_NAME])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPApplicationNameHeader value:[dict objectForKey:GROWL_APP_NAME]]];
	if ([dict objectForKey:GROWL_NOTIFICATION_NAME])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationName value:[dict objectForKey:GROWL_NOTIFICATION_NAME]]];
	if ([dict objectForKey:GROWL_NOTIFICATION_TITLE])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationTitle value:[dict objectForKey:GROWL_NOTIFICATION_TITLE]]];
	if ([dict objectForKey:GROWL_NOTIFICATION_IDENTIFIER])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:@"Notification-Coalescing-ID" value:[dict objectForKey:GROWL_NOTIFICATION_IDENTIFIER]]];
	if ([dict objectForKey:GROWL_NOTIFICATION_DESCRIPTION])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationText value:[dict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]]];
	if ([dict objectForKey:GROWL_NOTIFICATION_STICKY]) {
		//The only two valid values for C99's _Bool type are 0 and 1. Anything else gets turned to 1 in the conversion.
		NSString *boolString = [[dict objectForKey:GROWL_NOTIFICATION_STICKY] boolValue]
			? @"Yes"
			: @"No";
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationSticky value:boolString]];
	}
	if ([dict objectForKey:GROWL_NOTIFICATION_PRIORITY])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationPriority value:[NSString stringWithFormat:@"%i", [[dict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]]]];
	if ([dict objectForKey:GROWL_NOTIFICATION_ICON_DATA]) {
		NSData *iconData = [dict objectForKey:GROWL_NOTIFICATION_ICON_DATA];
		if ([iconData isKindOfClass:[NSImage class]])
			iconData = [(NSImage *)iconData PNGRepresentation];
		NSString *identifier = [GrowlGNTPBinaryChunk identifierForBinaryData:iconData];
		
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationIcon
																		value:[NSString stringWithFormat:@"x-growl-resource://%@", identifier]]];
		[binaryChunks addObject:[GrowlGNTPBinaryChunk chunkForData:iconData withIdentifier:identifier]];
	}
	if ([dict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]) {
      NSString *type = [dict objectForKey:GROWL_NOTIFICATION_CLICK_CONTENT_TYPE];
      id context = [dict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT];
      NSString *contextString = nil;
      
      //No sense sending a huge XML for a string
      if(!type && [context isKindOfClass:[NSString class]])
         type = @"String";
      
      //If we dont have a type here, we assume we can make a PList out of it since it likely came from one of our apps
      if(!type)
         type = @"PList";
      
      //If we have a type of PList, try to make a PList out of the data.  
      if([type caseInsensitiveCompare:@"PList"] == NSOrderedSame){
         NSError *error = nil;
         NSData *data = [NSPropertyListSerialization dataWithPropertyList:context 
                                                                   format:NSPropertyListXMLFormat_v1_0 
                                                                  options:0 
                                                                    error:&error];
         if(!error){
            contextString = [NSString stringWithUTF8String:[data bytes]];
         }else{
            NSLog(@"Error creating PList XML: %@", error);
         }
      }else{
         //If we aren't a PList, we left whatever we got originally as a string
         contextString = context;
      }
      
      //If we managed to get both a context string succesfully, send it out
      if(contextString){
         [headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationCallbackContext value:contextString]];
         [headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationCallbackContextType value:type]];
      }
	}
	if ([dict objectForKey:GROWL_NOTIFICATION_CALLBACK_URL_TARGET])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationCallbackTarget value:[dict objectForKey:GROWL_NOTIFICATION_CALLBACK_URL_TARGET]]];
	if ([dict objectForKey:GROWL_NOTIFICATION_CALLBACK_URL_TARGET_METHOD])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:@"Notification-Callback-Target-Method" value:[dict objectForKey:GROWL_NOTIFICATION_CALLBACK_URL_TARGET_METHOD]]];
	if ([dict objectForKey:GROWL_GNTP_ORIGIN_MACHINE])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPOriginMachineName value:[dict objectForKey:GROWL_GNTP_ORIGIN_MACHINE]]];
	if ([dict objectForKey:GROWL_GNTP_ORIGIN_SOFTWARE_NAME])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPOriginSoftwareName value:[dict objectForKey:GROWL_GNTP_ORIGIN_SOFTWARE_NAME]]];
	if ([dict objectForKey:GROWL_GNTP_ORIGIN_SOFTWARE_VERSION])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPOriginSoftwareVersion value:[dict objectForKey:GROWL_GNTP_ORIGIN_SOFTWARE_VERSION]]];
	if ([dict objectForKey:GROWL_GNTP_ORIGIN_PLATFORM_NAME])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPOriginPlatformName value:[dict objectForKey:GROWL_GNTP_ORIGIN_PLATFORM_NAME]]];
	if ([dict objectForKey:GROWL_GNTP_ORIGIN_PLATFORM_VERSION])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPOriginPlatformVersion value:[dict objectForKey:GROWL_GNTP_ORIGIN_PLATFORM_VERSION]]];
	if ([dict objectForKey:GROWL_APP_PID])
		[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPApplicationPIDHeader value:[dict objectForKey:GROWL_APP_PID]]];
	
	NSString *notificationID = [dict objectForKey:GROWL_NOTIFICATION_INTERNAL_ID];
	if (!notificationID) {
		/* Create a Notification-ID if this dictionary doesn't have one yet */
		CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
        CFStringRef uuidStrRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
		notificationID = [[(NSString*)uuidStrRef copy] autorelease];
        CFRelease(uuidStrRef);
		CFRelease(uuidRef);
	}
	[headersArray addObject:[GrowlGNTPHeaderItem headerItemWithName:GrowlGNTPNotificationID value:notificationID]];

	[self addSentAndReceivedHeadersFromDict:dict toArray:headersArray];

	if (outNotificationID) *outNotificationID = notificationID;
	if (outHeadersArray) *outHeadersArray = headersArray;
	if (outBinaryChunks) *outBinaryChunks = binaryChunks;
}

@end
