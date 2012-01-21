#pragma mark iTunes.h shortcuts
#define StateStopped ITunesEPlSStopped
#define StatePlaying ITunesEPlSPlaying
#define StatePaused ITunesEPlSPaused
#define StateFastForward ITunesEPlSFastForwarding
#define StateRewind ITunesEPlSRewinding

#pragma mark logger tags
#define LogTagInit (1 << 0)
#define LogTagKVC (1 << 1)
#define LogTagState (1 << 2)

#pragma mark beta expiry
#if defined(BETA) && BETA
#define DAYSTOEXPIRY 14
#endif

#pragma mark compilation metadata
#define COMPILED_ON __DATE__
#define COMPILED_AT __TIME__
#define COMPILER_VERSION __VERSION__

#pragma mark defaults setting names
#define NOTIFY_ITUNES_FRONTMOST @"notifyWhenITunesIsFrontmost"

#pragma mark bundle/notification IDs
#define ITUNES_BUNDLE_ID @"com.apple.iTunes"
#define PLAYER_INFO_ID ITUNES_BUNDLE_ID ".playerInfo"
#define SOURCE_SAVED_ID ITUNES_BUNDLE_ID ".sourceSaved"

#pragma mark growl notification names
#define NotifierChangedTracks           @"Changed Tracks"
#define NotifierPaused                  @"Paused"
#define NotifierStopped                 @"Stopped"
#define NotifierStarted                 @"started"
#define NotifierChangedTracksReadable   NSLocalizedString(@"Changed Tracks", nil)
#define NotifierPausedReadable          NSLocalizedString(@"Paused", nil)
#define NotifierStoppedReadable         NSLocalizedString(@"Stopped", nil)
#define NotifierStartedReadable         NSLocalizedString(@"Started", nil)

#pragma mark formatting helpers
#define formattingTypes                 @"podcast", @"stream", @"show", @"movie", @"musicVideo", @"music"
#define formattingAttributes            @"title", @"line1", @"line2", @"line3"

#pragma mark formatting tokens
#define TokenAlbum                      @"album"
#define TokenAlbumArtist                @"albumArtist"
#define TokenArtist                     @"artist"
#define TokenBestArtist                 @"bestArtist"
#define TokenBestDescription            @"bestDescription"
#define TokenComment                    @"comment"
#define TokenDescription                @"description"
#define TokenEpisodeID                  @"episodeID"
#define TokenEpisodeNumber              @"episodeNumber"
#define TokenLongDescription            @"longDescription"
#define TokenName                       @"name"
#define TokenSeasonNumber               @"seasonNumber"
#define TokenShow                       @"show"
#define TokenStreamTitle                @"streamTitle"
#define TokenTrackCount                 @"trackCount"
#define TokenTrackNumber                @"trackNumber"
#define TokenTime                       @"time"
#define TokenVideoKindName              @"videoKindName"
#define TokenAlbumReadable              NSLocalizedString(@"Album", nil)
#define TokenAlbumArtistReadable        NSLocalizedString(@"Album Artist", nil)
#define TokenArtistReadable             NSLocalizedString(@"Artist", nil)
#define TokenBestArtistReadable         NSLocalizedString(@"Album Artist or Artist", nil)
#define TokenBestDescriptionReadable    NSLocalizedString(@"Long Description, Comment, or Description", nil)
#define TokenCommentReadable            NSLocalizedString(@"Comment", nil)
#define TokenDescriptionReadable        NSLocalizedString(@"Description", nil)
#define TokenEpisodeIDReadable          NSLocalizedString(@"Episode ID", nil)
#define TokenEpisodeNumberReadable      NSLocalizedString(@"Episode Number", nil)
#define TokenLongDescriptionReadable    NSLocalizedString(@"Long Description", nil)
#define TokenNameReadable               NSLocalizedString(@"Name", nil)
#define TokenSeasonNumberReadable       NSLocalizedString(@"Season Number", nil)
#define TokenShowReadable               NSLocalizedString(@"Show", nil)
#define TokenStreamTitleReadable        NSLocalizedString(@"Stream Title", nil)
#define TokenTrackCountReadable         NSLocalizedString(@"Track Count", nil)
#define TokenTrackNumberReadable        NSLocalizedString(@"Track Number", nil)
#define TokenTimeReadable               NSLocalizedString(@"Play Time", nil)
#define TokenVideoKindNameReadable      NSLocalizedString(@"Video Kind", nil)

#pragma mark menu entries
#define MenuPlayPause                   NSLocalizedString(@"▶ Play/Pause", nil)
#define MenuNextTrack                   NSLocalizedString(@"→ Next Track", nil)
#define MenuPreviousTrack               NSLocalizedString(@"← Previous Track", nil)
#define MenuRating                      NSLocalizedString(@"Rating", nil)
#define MenuVolume                      NSLocalizedString(@"Volume", nil)
#define MenuBringITunesToFront          NSLocalizedString(@"Bring iTunes to Front", nil)
#define MenuQuitBoth                    NSLocalizedString(@"Quit Both", nil)
#define MenuQuitITunes                  NSLocalizedString(@"Quit iTunes", nil)
#define MenuQuitGrowlTunes              NSLocalizedString(@"Quit GrowlTunes", nil)
#define MenuStartITunes                 NSLocalizedString(@"Start iTunes", nil)
#define MenuNotifyWithITunesActive      NSLocalizedString(@"Notify when iTunes is active", nil)
#define MenuConfigureFormatting         NSLocalizedString(@"Configure Formatting", nil)
