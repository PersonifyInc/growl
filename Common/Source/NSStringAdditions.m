//
//  NSStringAdditions.m
//  Growl
//
//  Created by Ingmar Stein on 16.05.05.
//  Copyright 2005-2006 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "NSStringAdditions.h"
#include <arpa/inet.h>

@implementation NSString (GrowlAdditions)

//for greater polymorphism with NSNumber.
- (BOOL) boolValue {
	return [self intValue] != 0
		|| (CFStringCompare((CFStringRef)self, CFSTR("yes"), kCFCompareCaseInsensitive) == kCFCompareEqualTo)
		|| (CFStringCompare((CFStringRef)self, CFSTR("true"), kCFCompareCaseInsensitive) == kCFCompareEqualTo);
}

- (unsigned long) unsignedLongValue {
	return strtoul([self UTF8String], /*endptr*/ NULL, /*base*/ 0);
}

- (unsigned) unsignedIntValue {
	return (unsigned int)[self unsignedLongValue];
}

- (BOOL) isSubpathOf:(NSString *)superpath {
	NSString *canonicalSuperpath = [superpath stringByStandardizingPath];
	NSString *canonicalSubpath = [self stringByStandardizingPath];
	return [canonicalSubpath isEqualToString:canonicalSuperpath]
		|| [canonicalSubpath hasPrefix:[canonicalSuperpath stringByAppendingString:@"/"]];
}

- (BOOL)Growl_isLikelyDomainName
{
	NSUInteger length = [self length];
	NSString *lowerSelf = [self lowercaseString];
	if (length > 3 &&
       [self rangeOfString:@"." options:NSLiteralSearch].location != NSNotFound) {
		static NSArray *TLD2 = nil;
		static NSArray *TLD3 = nil;
		static NSArray *TLD4 = nil;
		if (!TLD2) {
			TLD2 = [[NSArray arrayWithObjects:@".ac", @".ad", @".ae", @".af", @".ag", @".ai", @".al", @".am", @".an", @".ao", @".aq", @".ar", @".as", @".at", @".au", @".aw", @".az", @".ba", @".bb", @".bd", @".be", @".bf", @".bg", @".bh", @".bi", @".bj", @".bm", @".bn", @".bo", @".br", @".bs", @".bt", @".bv", @".bw", @".by", @".bz", @".ca", @".cc", @".cd", @".cf", @".cg", @".ch", @".ci", @".ck", @".cl", @".cm", @".cn", @".co", @".cr", @".cu", @".cv", @".cx", @".cy", @".cz", @".de", @".dj", @".dk", @".dm", @".do", @".dz", @".ec", @".ee", @".eg", @".eh", @".er", @".es", @".et", @".eu", @".fi", @".fj", @".fk", @".fm", @".fo", @".fr", @".ga", @".gd", @".ge", @".gf", @".gg", @".gh", @".gi", @".gl", @".gm", @".gn", @".gp", @".gq", @".gr", @".gs", @".gt", @".gu", @".gw", @".gy", @".hk", @".hm", @".hn", @".hr", @".ht", @".hu", @".id", @".ie", @".il", @".im", @".in", @".io", @".iq", @".ir", @".is", @".it", @".je", @".jm", @".jo", @".jp", @".ke", @".kg", @".kh", @".ki", @".km", @".kn", @".kp", @".kr", @".kw", @".ky", @".kz", @".la", @".lb", @".lc", @".li", @".lk", @".lr", @".ls", @".lt", @".lu", @".lv", @".ly", @".ma", @".mc", @".md", @".me", @".mg", @".mh", @".mk", @".ml", @".mm", @".mn", @".mo", @".mp", @".mq", @".mr", @".ms", @".mt", @".mu", @".mv", @".mw", @".mx", @".my", @".mz", @".na", @".nc", @".ne", @".nf", @".ng", @".ni", @".nl", @".no", @".np", @".nr", @".nu", @".nz", @".om", @".pa", @".pe", @".pf", @".pg", @".ph", @".pk", @".pl", @".pm", @".pn", @".pr", @".ps", @".pt", @".pw", @".py", @".qa", @".re", @".ro", @".ru", @".rw", @".sa", @".sb", @".sc", @".sd", @".se", @".sg", @".sh", @".si", @".sj", @".sk", @".sl", @".sm", @".sn", @".so", @".sr", @".st", @".sv", @".sy", @".sz", @".tc", @".td", @".tf", @".tg", @".th", @".tj", @".tk", @".tm", @".tn", @".to", @".tp", @".tr", @".tt", @".tv", @".tw", @".tz", @".ua", @".ug", @".uk", @".um", @".us", @".uy", @".uz", @".va", @".vc", @".ve", @".vg", @".vi", @".vn", @".vu", @".wf", @".ws", @".ye", @".yt", @".yu", @".za", @".zm", @".zw", nil] retain];
			TLD3 = [[NSArray arrayWithObjects:@".com",@".edu",@".gov",@".int",@".mil",@".net",@".org",@".biz",@".",@".pro",@".cat", nil] retain];
			TLD4 = [[NSArray arrayWithObjects:@".info",@".aero",@".coop",@".mobi",@".jobs",@".arpa", nil] retain];
		}
		if ([TLD2 containsObject:[lowerSelf substringFromIndex:length-3]] ||
          (length > 4 && [TLD3 containsObject:[lowerSelf substringFromIndex:length-4]]) ||
          (length > 5 && [TLD4 containsObject:[lowerSelf substringFromIndex:length-5]]) ||
          [lowerSelf hasSuffix:@".museum"] || [lowerSelf hasSuffix:@".travel"]) {
			return YES;
		} else {
			return NO;
		}
	}
	
	return NO;
}

- (BOOL)Growl_isLikelyIPAddress
{
	/* TODO: Use inet_pton(), which will handle ipv4 and ipv6 */
   if(inet_pton(AF_INET, [self cStringUsingEncoding:NSUTF8StringEncoding], nil) == 1 ||
      inet_pton(AF_INET6, [self cStringUsingEncoding:NSUTF8StringEncoding], nil) == 1)
      return YES;
   else
      return NO;
}

- (BOOL)isLocalHost
{
   NSString *hostName = [[NSProcessInfo processInfo] hostName];
   if ([hostName hasSuffix:@".local"]) {
		hostName = [hostName substringToIndex:([hostName length] - [@".local" length])];
	}
	if ([self isEqualToString:@"127.0.0.1"] || 
       [self isEqualToString:@"::1"] || 
       [self isEqualToString:@"0:0:0:0:0:0:0:1"] ||
       [self caseInsensitiveCompare:@"localhost"] == NSOrderedSame ||
       [self caseInsensitiveCompare:hostName] == NSOrderedSame)
		return YES;
	else {
		return NO;
	}
}

@end
