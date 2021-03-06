/*
 Copyright (c) The Growl Project, 2004
 All rights reserved.


 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:


 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.


 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 */

//
//  GrowlTunesController.h
//  GrowlTunes
//
//  Created by Nelson Elhage on Mon Jun 21 2004.
//  Copyright (c) 2004 Nelson Elhage. All rights reserved.
//

#import <Growl/Growl.h>
#import "GrowlAbstractSingletonObject.h"
#import "iTunes.h"

@protocol GrowlTunesPluginArchive;

typedef enum {
	itPLAYING,
	itPAUSED,
	itSTOPPED,
	itUNKNOWN
} iTunesState;

@interface GrowlTunesController : GrowlAbstractSingletonObject <GrowlApplicationBridgeDelegate> {
	iTunesApplication       *iTunes;
    
    NSAppleScript		*getInfoScript;
	NSMutableArray		*plugins;
	NSStatusItem		*statusItem;
	NSString			*playlistName;
	NSMutableArray		*recentTracks;
	NSMenu				*iTunesSubMenu;
	NSMenu				*ratingSubMenu;
	NSDictionary		*noteDict;
	id <GrowlTunesPluginArchive> archivePlugin;

	iTunesState			state;
	int					trackID;
	NSString			*trackURL;		//The file location of the last-known track in iTunes, @"" for none
	NSString			*lastPostedDescription;
	int					trackRating;
}

- (void) showCurrentTrack;

- (BOOL) iTunesIsRunning;
- (BOOL) quitiTunes;

#pragma mark Status item

- (void) createStatusItem;
- (void) tearDownStatusItem;
- (NSMenu *) statusItemMenu;

#pragma mark Plug-ins

- (NSMutableArray *) loadPlugins;

@property (nonatomic, retain) iTunesApplication *iTunes;

@end
