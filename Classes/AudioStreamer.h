//
//  AudioStreamer.h
//  StreamingAudioPlayer
//
//  Created by Matt Gallagher on 27/09/08.
//  Modified by Randy Simon on 30/06/09 to allow for playback of fixed-length files.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#ifdef TARGET_OS_IPHONE			
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif TARGET_OS_IPHONE			

#include <pthread.h>
#include <AudioToolbox/AudioToolbox.h>

#define kNumAQBufs 4			// number of audio queue buffers we allocate
#define kAQBufSize 16384		// number of bytes in each audio queue buffer -- originally 2048, raised to support ALAC
#define kAQMaxPacketDescs 512	// number of packet descriptions in our array

typedef enum
{
	AS_INITIALIZED = 0,
	AS_STARTING_FILE_THREAD,
	AS_WAITING_FOR_DATA,
	AS_WAITING_FOR_QUEUE_TO_START,
	AS_PLAYING,
	AS_BUFFERING,
	AS_STOPPING,
	AS_STOPPED,
	AS_PAUSED
} AudioStreamerState;

typedef enum
{
	AS_NO_STOP = 0,
	AS_STOPPING_EOF,
	AS_STOPPING_USER_ACTION,
	AS_STOPPING_ERROR,
	AS_STOPPING_TEMPORARILY
} AudioStreamerStopReason;

typedef enum
{
	AS_NO_ERROR = 0,
	AS_NETWORK_CONNECTION_FAILED,
	AS_FILE_STREAM_GET_PROPERTY_FAILED,
	AS_FILE_STREAM_SEEK_FAILED,
	AS_FILE_STREAM_PARSE_BYTES_FAILED,
	AS_FILE_STREAM_OPEN_FAILED,
	AS_FILE_STREAM_CLOSE_FAILED,
	AS_AUDIO_DATA_NOT_FOUND,
	AS_AUDIO_QUEUE_CREATION_FAILED,
	AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED,
	AS_AUDIO_QUEUE_ENQUEUE_FAILED,
	AS_AUDIO_QUEUE_ADD_LISTENER_FAILED,
	AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED,
	AS_AUDIO_QUEUE_START_FAILED,
	AS_AUDIO_QUEUE_PAUSE_FAILED,
	AS_AUDIO_QUEUE_BUFFER_MISMATCH,
	AS_AUDIO_QUEUE_DISPOSE_FAILED,
	AS_AUDIO_QUEUE_STOP_FAILED,
	AS_AUDIO_QUEUE_FLUSH_FAILED,
	AS_AUDIO_STREAMER_FAILED,
	AS_GET_AUDIO_TIME_FAILED
} AudioStreamerErrorCode;

extern NSString * const ASStatusChangedNotification;


@interface AudioStreamer : NSObject
{
	NSURL *url;

	//
	// Special threading consideration:
	//	The audioQueue property should only ever be accessed inside a
	//	synchronized(self) block and only *after* checking that ![self isFinishing]
	//
	AudioQueueRef audioQueue;
	AudioFileStreamID audioFileStream;	// the audio file stream parser
	
	AudioQueueBufferRef audioQueueBuffer[kNumAQBufs];		// audio queue buffers
	AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs];	// packet descriptions for enqueuing audio
	unsigned int fillBufferIndex;	// the index of the audioQueueBuffer that is being filled
	size_t bytesFilled;				// how many bytes have been filled
	size_t packetsFilled;			// how many packets have been filled
	bool inuse[kNumAQBufs];			// flags to indicate that a buffer is still in use
	NSInteger buffersUsed;
	
	AudioStreamerState state;
	AudioStreamerStopReason stopReason;
	AudioStreamerErrorCode errorCode;
	OSErr err;
	
	bool discontinuous;			// flag to indicate middle of the stream
	
	pthread_mutex_t queueBuffersMutex;			// a mutex to protect the inuse flags
	pthread_cond_t queueBufferReadyCondition;	// a condition varable for handling the inuse flags

	CFReadStreamRef stream;
	NSNotificationCenter *notificationCenter;
	
	NSUInteger dataOffset;
	UInt32 bitRate;
	
	NSUInteger thisFileDataOffset;
	UInt32 offsetStart;

	bool seekNeeded;
	double seekTime;
	double sampleRate;
	double lastProgress;
	
	// This value is updated by the downloader to notify the streamer when the file is fully downloaded.
	BOOL fileDownloadComplete;
	
	// This value is updated by the downloader to notify the streamer how much of the file has been downloaded.
	int fileDownloadCurrentSize;
	
	// Inidicates the number of bytes we have read from the stream.
	int fileDownloadBytesRead;
	
	// Flag to indicate if we are playing fixed length files.
	BOOL fixedLength;
	
	// The twitter post timer
	BOOL shouldInvalidateTweetTimer;
	NSTimer *tweetTimer;
	
	// The scrobbling timer
	BOOL shouldInvalidateScrobbleTimer;
	NSTimer *scrobbleTimer;
}

@property AudioStreamerErrorCode errorCode;
@property (readonly) AudioStreamerState state;
@property (readonly) double progress;
@property (readonly) UInt32 bitRate;
@property UInt32 offsetStart;
@property (readonly) AudioStreamerStopReason stopReason;
@property BOOL fileDownloadComplete;
@property int fileDownloadCurrentSize;
@property int fileDownloadBytesRead;


- (id)initWithURL:(NSURL *)aURL;
- (id)initWithFileURL:(NSURL *)aURL;
- (void)start;
- (void)startWithOffsetInSecs:(UInt32) offsetInSecs;
- (void)stop;
- (void)pause;
- (BOOL)isPlaying;
- (BOOL)isPaused;
- (BOOL)isWaiting;
- (BOOL)isIdle;
- (BOOL)isFinishing;
- (BOOL)queueFailed;
- (BOOL)nonQueueError;

// Method for getting and setting the volume in the Audio Queue Service
- (void)setVolume:(float)volume;
- (float)getVolume;

@end






