//
//  GrowlPreferencesController.m
//  Growl
//
//  Created by Nelson Elhage on 8/24/04.
//  Renamed from GrowlPreferences.m by Peter Hosey on 2005-06-27.
//  Copyright 2004-2006 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details


#import "GrowlPreferencesController.h"
#import "GrowlDefinesInternal.h"
#import "GrowlDefines.h"
#import "GrowlPathUtilities.h"
#import "GrowlProcessUtilities.h"
#import "NSStringAdditions.h"
#import "GrowlIdleStatusController.h"
#import "GrowlNotificationDatabase.h"
#import "GrowlApplicationController.h"
#include "CFURLAdditions.h"
#include <Security/SecKeychain.h>
#include <Security/SecKeychainItem.h>

#define keychainServiceName "Growl"
#define keychainAccountName "Growl"

CFTypeRef GrowlPreferencesController_objectForKey(CFTypeRef key) {
	return [[GrowlPreferencesController sharedController] objectForKey:(id)key];
}

CFIndex GrowlPreferencesController_integerForKey(CFTypeRef key) {
	Boolean keyExistsAndHasValidFormat;
	return CFPreferencesGetAppIntegerValue((CFStringRef)key, (CFStringRef)GROWL_HELPERAPP_BUNDLE_IDENTIFIER, &keyExistsAndHasValidFormat);
}

Boolean GrowlPreferencesController_boolForKey(CFTypeRef key) {
	Boolean keyExistsAndHasValidFormat;
	return CFPreferencesGetAppBooleanValue((CFStringRef)key, (CFStringRef)GROWL_HELPERAPP_BUNDLE_IDENTIFIER, &keyExistsAndHasValidFormat);
}

unsigned short GrowlPreferencesController_unsignedShortForKey(CFTypeRef key)
{
	CFIndex theIndex = GrowlPreferencesController_integerForKey(key);
	
	if (theIndex > USHRT_MAX)
		return USHRT_MAX;
	else if (theIndex < 0)
		return 0;
	return (unsigned short)theIndex;
}

@implementation GrowlPreferencesController

+ (GrowlPreferencesController *) sharedController {
	static GrowlPreferencesController *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id) init {
	if ((self = [super init])) {
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(growlPreferencesChanged:)
			name:GrowlPreferencesChanged
			object:nil];
		loginItems = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, /*options*/ NULL);
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	CFRelease(loginItems);

	[super dealloc];
}

#pragma mark -

- (void) registerDefaults:(NSDictionary *)inDefaults {
	NSUserDefaults *helperAppDefaults = [[NSUserDefaults alloc] init];
	[helperAppDefaults addSuiteNamed:GROWL_HELPERAPP_BUNDLE_IDENTIFIER];
	NSDictionary *existing = [helperAppDefaults persistentDomainForName:GROWL_HELPERAPP_BUNDLE_IDENTIFIER];
	if (existing) {
		NSMutableDictionary *domain = [inDefaults mutableCopy];
		[domain addEntriesFromDictionary:existing];
		[helperAppDefaults setPersistentDomain:domain forName:GROWL_HELPERAPP_BUNDLE_IDENTIFIER];
		[domain release];
	} else {
		[helperAppDefaults setPersistentDomain:inDefaults forName:GROWL_HELPERAPP_BUNDLE_IDENTIFIER];
	}
	[helperAppDefaults release];
	SYNCHRONIZE_GROWL_PREFS();
}

- (id) objectForKey:(NSString *)key {
	id value = (id)CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)GROWL_HELPERAPP_BUNDLE_IDENTIFIER);
	if(value)
		CFMakeCollectable(value);
	return [value autorelease];
}

- (void) setObject:(id)object forKey:(NSString *)key {
	CFPreferencesSetAppValue((CFStringRef)key,
							 (CFPropertyListRef)object,
							 (CFStringRef)GROWL_HELPERAPP_BUNDLE_IDENTIFIER);

	SYNCHRONIZE_GROWL_PREFS();

	int pid = getpid();
	CFNumberRef pidValue = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &pid);
	CFStringRef pidKey = CFSTR("pid");
	CFDictionaryRef userInfo = CFDictionaryCreate(kCFAllocatorDefault, (const void **)&pidKey, (const void **)&pidValue, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFRelease(pidValue);
	CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
										 (CFStringRef)GrowlPreferencesChanged,
										 /*object*/ key,
										 /*userInfo*/ userInfo,
										 /*deliverImmediately*/ false);
	CFRelease(userInfo);
}

- (BOOL) boolForKey:(NSString *)key {
	return GrowlPreferencesController_boolForKey((CFTypeRef)key);
}

- (void) setBool:(BOOL)value forKey:(NSString *)key {
	NSNumber *object = [[NSNumber alloc] initWithBool:value];
	[self setObject:object forKey:key];
	[object release];
}

- (CFIndex) integerForKey:(NSString *)key {
	return GrowlPreferencesController_integerForKey((CFTypeRef)key);
}

- (void) setInteger:(CFIndex)value forKey:(NSString *)key {
#ifdef __LP64__
	NSNumber *object = [[NSNumber alloc] initWithInteger:value];
#else
	NSNumber *object = [[NSNumber alloc] initWithInt:value];
#endif
	[self setObject:object forKey:key];
	[object release];
}

- (unsigned short)unsignedShortForKey:(NSString *)key
{
	return GrowlPreferencesController_unsignedShortForKey((CFTypeRef)key);
}


- (void)setUnsignedShort:(unsigned short)theShort forKey:(NSString *)key
{
	[self setObject:[NSNumber numberWithUnsignedShort:theShort] forKey:key];
}

- (void) synchronize {
	SYNCHRONIZE_GROWL_PREFS();
}

#pragma mark -
#pragma mark Start-at-login control

- (BOOL) allowStartAtLogin{
    return [self boolForKey:GrowlAllowStartAtLogin];
}

- (void) setAllowStartAtLogin:(BOOL)start{
    [self setBool:start forKey:GrowlAllowStartAtLogin];
}

- (BOOL) shouldStartGrowlAtLogin {
	Boolean    foundIt = false;

	//get the prefpane bundle and find GHA within it.
	NSString *pathToGHA      = [[NSBundle bundleWithIdentifier:GROWL_HELPERAPP_BUNDLE_IDENTIFIER] bundlePath];
	if(pathToGHA) {
		//get the file url to GHA.
		CFURLRef urlToGHA = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)pathToGHA, kCFURLPOSIXPathStyle, true);
		
		UInt32 seed = 0U;
		NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
		for (id itemObject in currentLoginItems) {
			LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
			
			UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
			CFURLRef URL = NULL;
			OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
			if (err == noErr) {
				foundIt = CFEqual(URL, urlToGHA);
				CFRelease(URL);
				
				if (foundIt)
					break;
			}
		}
		
		CFRelease(urlToGHA);
	}
	else {
		NSLog(@"Growl: your install is corrupt, you will need to reinstall\nyour Growl.app is:%@", pathToGHA);
	}
	
	return foundIt;
}

- (void) setShouldStartGrowlAtLogin:(BOOL)flag {
	//get the prefpane bundle and find GHA within it.
	NSString *pathToGHA = [[NSBundle bundleWithIdentifier:GROWL_HELPERAPP_BUNDLE_IDENTIFIER] bundlePath];
	[self setStartAtLogin:pathToGHA enabled:flag];
}

- (void) setStartAtLogin:(NSString *)path enabled:(BOOL)enabled {
	OSStatus status;
	CFURLRef URLToToggle = (CFURLRef)[NSURL fileURLWithPath:path];
	LSSharedFileListItemRef existingItem = NULL;

	UInt32 seed = 0U;
	NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
	for (id itemObject in currentLoginItems) {
		LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;

		UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
		CFURLRef URL = NULL;
		OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
		if (err == noErr) {
			Boolean foundIt = CFEqual(URL, URLToToggle);
			CFRelease(URL);

			if (foundIt) {
				existingItem = item;
				break;
			}
		}
	}

	if (enabled && (existingItem == NULL)) {
		NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:path];
		IconRef icon = NULL;
		FSRef ref;
		Boolean gotRef = CFURLGetFSRef(URLToToggle, &ref);
		if (gotRef) {
			status = GetIconRefFromFileInfo(&ref,
											/*fileNameLength*/ 0, /*fileName*/ NULL,
											kFSCatInfoNone, /*catalogInfo*/ NULL,
											kIconServicesNormalUsageFlag,
											&icon,
											/*outLabel*/ NULL);
			if (status != noErr)
				icon = NULL;
		}

		LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, (CFStringRef)displayName, icon, URLToToggle, /*propertiesToSet*/ NULL, /*propertiesToClear*/ NULL);
	} else if (!enabled && (existingItem != NULL))
		LSSharedFileListItemRemove(loginItems, existingItem);
}

#pragma mark -
#pragma mark Growl running state

- (void) launchGrowl:(BOOL)noMatterWhat {
#if GROWL_PREFPANE_AND_HELPERAPP_ARE_SEPARATE
	NSString *helperPath = [[GrowlPathUtilities helperAppBundle] bundlePath];
	NSURL *helperURL = [NSURL fileURLWithPath:helperPath];

	unsigned options = NSWorkspaceLaunchWithoutAddingToRecents | NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchAsync;
	if (noMatterWhat)
		options |= NSWorkspaceLaunchNewInstance;
	[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:helperURL]
	                withAppBundleIdentifier:nil
	                                options:options
	         additionalEventParamDescriptor:nil
	                      launchIdentifiers:NULL];
#endif
}

- (void) setSquelchMode:(BOOL)squelch
{
    [self willChangeValueForKey:@"squelchMode"];
    [self setBool:squelch forKey:GrowlSquelchMode];
    [self didChangeValueForKey:@"squelchMode"];
   
   if(!squelch && [[GrowlNotificationDatabase sharedInstance] notificationsWhileAway] && [self isRollupAutomatic]){
       [self setRollupShown:YES];
   }
}

- (BOOL) squelchMode
{
    return [self boolForKey:GrowlSquelchMode];
}

#pragma mark -
//Simplified accessors

#pragma mark UI

- (NSUInteger) selectedPreferenceTab{
   return [self integerForKey:GrowlSelectedPrefPane];
}
- (void) setSelectedPreferenceTab:(NSUInteger)tab{
   if (tab < 7 ) {
      [self setInteger:tab forKey:GrowlSelectedPrefPane];
   }else {
      [self setInteger:0 forKey:GrowlSelectedPrefPane];
   }

}

- (CFIndex)selectedPosition {
	return [self integerForKey:GROWL_POSITION_PREFERENCE_KEY];
}

- (NSString *) defaultDisplayPluginName {
	return [self objectForKey:GrowlDisplayPluginKey];
}
- (void) setDefaultDisplayPluginName:(NSString *)name {
	[self setObject:name forKey:GrowlDisplayPluginKey];
}

- (NSNumber*) idleThreshold {
#ifdef __LP64__
	return [NSNumber numberWithInteger:[self integerForKey:GrowlStickyIdleThresholdKey]];
#else
	return [NSNumber numberWithInt:[self integerForKey:GrowlStickyIdleThresholdKey]];
#endif
}

- (void) setIdleThreshold:(NSNumber*)value {
	[self setInteger:[value intValue] forKey:GrowlStickyIdleThresholdKey];
   GrowlIdleStatusController_setThreshold([value intValue]);
}

#pragma mark Logging

- (BOOL) loggingEnabled {
	return [self boolForKey:GrowlLoggingEnabledKey];
}

- (void) setLoggingEnabled:(BOOL)flag {
	[self setBool:flag forKey:GrowlLoggingEnabledKey];
}

- (BOOL) isGrowlServerEnabled {
	return [self boolForKey:GrowlStartServerKey];
}

- (void) setGrowlServerEnabled:(BOOL)enabled {
	[self setBool:enabled forKey:GrowlStartServerKey];
}

- (void) setMenuNumber:(NSNumber*)state{
   [self setMenuState:[state integerValue]];
}
- (NSInteger) menuState {
   return [self integerForKey:GrowlMenuState];
}
- (void) setMenuState:(NSInteger)state {
   NSInteger current = [self menuState];
   if(state == current)
      return;
   
   switch (state) {
      case GrowlStatusMenu:
         if(current == GrowlDockMenu || current == GrowlBothMenus){
            [self removeDockMenu];
         }
         break;
      case GrowlDockMenu:
      case GrowlBothMenus:
         [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
         [[NSApp dockTile] setBadgeLabel:nil];
         break;
      case GrowlNoMenu:
         if(![self isBackgroundAllowed]){
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning! Enabling this option will cause Growl to run in the background", nil)
                                             defaultButton:NSLocalizedString(@"Ok", nil)
                                           alternateButton:NSLocalizedString(@"Cancel", nil)
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Enabling this option will cause Growl to run without showing a dock icon or a menu item.\n\nTo access preferences, tap Growl in Launchpad, or open Growl in Finder.", nil)];
            [alert setShowsSuppressionButton:YES];
            NSInteger allow = [alert runModal];
            BOOL suppress = [[alert suppressionButton] state] == NSOnState;
            if(suppress)
               [self setBackgroundAllowed:YES];
            
            if(allow == NSAlertDefaultReturn)
               [self removeDockMenu];
            else{
               //While the state will already be reset below, we call the new setMenuNumber with our current, and thats enough to trigger the menu updating
               [self performSelector:@selector(setMenuNumber:) withObject:[NSNumber numberWithInteger:current] afterDelay:0];
               state = current;
            }
         }else
            [self removeDockMenu];
         
         break;
      default:
         //Don't know what to do, leave it where it was
         return;
   }
   
   [[GrowlApplicationController sharedController] updateMenu:state];
   [self setInteger:state forKey:GrowlMenuState];
}

- (void)removeDockMenu {
   //We can't actually remove the dock menu without restarting, inform the user.
   if([self menuState] != GrowlDockMenu && [self menuState] != GrowlBothMenus)
      return;

   if(![self boolForKey:GrowlRelaunchWarnSuppress]){
      NSAlert *alert = [[NSAlert alloc] init];
      [alert setMessageText:NSLocalizedString(@"Growl must restart for this change to take effect.",nil)];
      [alert setShowsSuppressionButton:YES];
      [alert runModal];
      if([[alert suppressionButton] state] == NSOnState){
         [self setBool:YES forKey:GrowlRelaunchWarnSuppress];
      }
      [alert release];
   }
}

- (BOOL) isBackgroundAllowed {
   return [self boolForKey:GrowlBackgroundAllowed];
}
- (void) setBackgroundAllowed:(BOOL)allow {
   [self setBool:allow forKey:GrowlBackgroundAllowed];
}

- (BOOL)isGrowlMenuPulseEnabled {
   return [self boolForKey:GrowlMenuPulseEnabled];
}
- (void)setGrowlMenuPulseEnabled:(BOOL)enabled {
   [self setBool:enabled forKey:GrowlMenuPulseEnabled];
}

#pragma mark Notification History

- (BOOL) isRollupShown {
   return [self boolForKey:GrowlRollupShown];
}
- (void) setRollupShown:(BOOL)shown {
   if(shown && ![self isRollupShown] && ![self isRollupEnabled])
      shown = NO;
   [self setBool:shown forKey:GrowlRollupShown];
   if (shown) {
      [[GrowlNotificationDatabase sharedInstance] showRollup];
   }else{
      [[GrowlNotificationDatabase sharedInstance] hideRollup];
   }
}
- (BOOL) isRollupEnabled {
   return [self boolForKey:GrowlRollupEnabled];
}
- (void) setRollupEnabled:(BOOL)enabled{
   [self setBool:enabled forKey:GrowlRollupEnabled];
}
- (BOOL) isRollupAutomatic {
   return [self boolForKey:GrowlRollupAutomatic];
}
- (void) setRollupAutomatic:(BOOL)automatic {
   [self setBool:automatic forKey:GrowlRollupAutomatic];
}

- (BOOL) isGrowlHistoryLogEnabled {
   return [self boolForKey:GrowlHistoryLogEnabled];
}
- (void) setGrowlHistoryLogEnabled:(BOOL)flag {
   [self setBool:flag forKey:GrowlHistoryLogEnabled];
}

- (BOOL) retainAllNotesWhileAway {
   return [self boolForKey:GrowlHistoryRetainAllWhileAway];
}
- (void) setRetainAllNotesWhileAway:(BOOL)flag {
   [self setBool:flag forKey:GrowlHistoryRetainAllWhileAway];
}

- (NSUInteger) growlHistoryDayLimit {
	return [self integerForKey:GrowlHistoryDayLimit];
}
- (void) setGrowlHistoryDayLimit:(NSUInteger)limit {
	[self setInteger:limit forKey:GrowlHistoryDayLimit];
}

- (NSUInteger) growlHistoryCountLimit {
   return [self integerForKey:GrowlHistoryCountLimit];
}
- (void) setGrowlHistoryCountLimit:(NSUInteger)limit {
	[self setInteger:limit forKey:GrowlHistoryCountLimit];
}

- (BOOL) isGrowlHistoryTrimByDate {
   return [self boolForKey:GrowlHistoryTrimByDate];
}
- (void) setGrowlHistoryTrimByDate:(BOOL)flag {
   [self setBool:flag forKey:GrowlHistoryTrimByDate];
}

- (BOOL) isGrowlHistoryTrimByCount {
   return [self boolForKey:GrowlHistoryTrimByCount];
}
- (void) setGrowlHistoryTrimByCount:(BOOL)flag {
   [self setBool:flag forKey:GrowlHistoryTrimByCount];
}

#pragma mark Remote Growling

- (NSString *) remotePassword {
	unsigned char *password;
	UInt32 passwordLength;
	OSStatus status;
	status = SecKeychainFindGenericPassword(NULL,
											(UInt32)strlen(keychainServiceName), keychainServiceName,
											(UInt32)strlen(keychainAccountName), keychainAccountName,
											&passwordLength, (void **)&password, NULL);

	NSString *passwordString;
	if (status == noErr) {
		passwordString = (NSString *)CFStringCreateWithBytes(kCFAllocatorDefault, password, passwordLength, kCFStringEncodingUTF8, false);
		if(passwordString) {
			CFMakeCollectable(passwordString);
			[passwordString autorelease];
			SecKeychainItemFreeContent(NULL, password);
		}
	} else {
		if (status != errSecItemNotFound)
			NSLog(@"Failed to retrieve password from keychain. Error: %d", (int)status);
		passwordString = @"";
	}

	return passwordString;
}

- (void) setRemotePassword:(NSString *)value {
	const char *password = value ? [value UTF8String] : "";
	size_t length = strlen(password);
	OSStatus status;
	SecKeychainItemRef itemRef = nil;
	status = SecKeychainFindGenericPassword(NULL,
											(UInt32)strlen(keychainServiceName), keychainServiceName,
											(UInt32)strlen(keychainAccountName), keychainAccountName,
											NULL, NULL, &itemRef);
	if (status == errSecItemNotFound) {
		// add new item
		status = SecKeychainAddGenericPassword(NULL,
											   (UInt32)strlen(keychainServiceName), keychainServiceName,
											   (UInt32)strlen(keychainAccountName), keychainAccountName,
											   (UInt32)length, password, NULL);
		if (status)
			NSLog(@"Failed to add password to keychain.");
	} else {
		// change existing password
		SecKeychainAttribute attrs[] = {
			{ kSecAccountItemAttr, (UInt32)strlen(keychainAccountName), (char *)keychainAccountName },
			{ kSecServiceItemAttr, (UInt32)strlen(keychainServiceName), (char *)keychainServiceName }
		};
		const SecKeychainAttributeList attributes = { (UInt32)sizeof(attrs) / (UInt32)sizeof(attrs[0]), attrs };
		status = SecKeychainItemModifyAttributesAndData(itemRef,		// the item reference
														&attributes,	// no change to attributes
														(UInt32)length,			// length of password
														password		// pointer to password data
														);
		if (itemRef)
			CFRelease(itemRef);
		if (status)
			NSLog(@"Failed to change password in keychain.");
	}
}

- (BOOL) isForwardingEnabled {
	return [self boolForKey:GrowlEnableForwardKey];
}
- (void) setForwardingEnabled:(BOOL)enabled {
	[self setBool:enabled forKey:GrowlEnableForwardKey];
}

#pragma mark -
/*
 * @brief Growl preferences changed
 *
 * Synchronize our NSUserDefaults to immediately get any changes from the disk
 */
- (void) growlPreferencesChanged:(NSNotification *)notification {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSString *object = [notification object];
//	NSLog(@"%s: %@\n", __func__, object);
	SYNCHRONIZE_GROWL_PREFS();
	if (!object || [object isEqualToString:GrowlDisplayPluginKey]) {
		[self willChangeValueForKey:@"defaultDisplayPluginName"];
		[self didChangeValueForKey:@"defaultDisplayPluginName"];
	}
	if (!object || [object isEqualToString:GrowlMenuExtraKey]) {
		[self willChangeValueForKey:@"growlMenuEnabled"];
		[self didChangeValueForKey:@"growlMenuEnabled"];
	}
	if (!object || [object isEqualToString:GrowlEnableForwardKey]) {
		[self willChangeValueForKey:@"forwardingEnabled"];
		[self didChangeValueForKey:@"forwardingEnabled"];
	}
	if (!object || [object isEqualToString:GrowlStickyIdleThresholdKey]) {
		[self willChangeValueForKey:@"idleThreshold"];
		[self didChangeValueForKey:@"idleThreshold"];
	}
	if (!object || [object isEqualToString:GrowlSelectedPrefPane]) {
		[self willChangeValueForKey:@"selectedPreferenceTab"];
		[self didChangeValueForKey:@"selectedPreferenceTab"];
	}	
	[pool release];
}

@end
