//
//  PlayQueue.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation
import MediaPlayer
import Async
import Nuke

@objc public enum RepeatMode: Int {
    case normal
    case repeatOne
    case repeatAll
}

@objc public enum ShuffleMode: Int {
    case normal
    case shuffle
}

@objc open class PlayQueue: NSObject {
    
    //
    // MARK: - Notifications -
    //
    
    // TODO: Make these available in Obj-C
    public struct Notifications {
        public static let playQueueIndexChanged = ISMSNotification_CurrentPlaylistIndexChanged
    }
    
    fileprivate func notifyPlayQueueIndexChanged() {
        NotificationCenter.postNotificationToMainThread(withName: PlayQueue.Notifications.playQueueIndexChanged, object: nil)
    }
    
    fileprivate func registerForNotifications() {
        // Watch for changes to the play queue playlist
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueue.playlistChanged(_:)), name: Playlist.Notifications.playlistChanged, object: nil)
    }
    
    fileprivate func unregisterForNotifications() {
        NotificationCenter.removeObserver(onMainThread: self, name: Playlist.Notifications.playlistChanged, object: nil)
    }
    
    @objc fileprivate func playlistChanged(_ notification: Notification) {
        
    }
    
    //
    // MARK: - Properties -
    //
    
    open static let si = PlayQueue()
    
    open var repeatMode = RepeatMode.normal
    open var shuffleMode = ShuffleMode.normal { didSet { /* TODO: Do something */ } }
    
    open fileprivate(set) var currentIndex = -1 {
        didSet {
            updateLockScreenInfo()
            
            if currentIndex != oldValue {
                notifyPlayQueueIndexChanged()
            }
        }
    }
    open var previousIndex: Int { return indexAtOffset(-1, fromIndex: currentIndex) }
    open var nextIndex: Int { return indexAtOffset(1, fromIndex: currentIndex) }
    open var currentDisplaySong: ISMSSong? { return currentSong ?? previousSong }
    open var currentSong: ISMSSong? { return playlist.song(atIndex: currentIndex) }
    open var previousSong: ISMSSong? { return playlist.song(atIndex: previousIndex) }
    open var nextSong: ISMSSong? { return playlist.song(atIndex: nextIndex) }
    open var songCount: Int { return playlist.songCount }
    open var isPlaying: Bool { return audioEngine.isPlaying() }
    open var isStarted: Bool { return audioEngine.isStarted() }
    open var currentSongProgress: Double { return audioEngine.progress() }
    open var songs: [ISMSSong] { return playlist.songs }
    open var playlist: Playlist { return Playlist.playQueue }
    
    fileprivate var audioEngine: AudioEngine { return AudioEngine.si() }
    
    //
    // MARK: - Play Queue -
    //
    
    open func reset() {
        playlist.removeAllSongs()
        audioEngine.stop()
        currentIndex = -1
    }
    
    open func removeSongs(atIndexes indexes: IndexSet) {
        // Stop the music if we're removing the current song
        let containsCurrentIndex = indexes.contains(currentIndex)
        if containsCurrentIndex {
            audioEngine.stop()
        }
        
        // Remove the songs
        playlist.remove(songsAtIndexes: indexes)
        
        // Adjust the current index if songs are removed below it
        if currentIndex >= 0 {
            let range = NSMakeRange(0, currentIndex)
            let countOfIndexesBelowCurrent = indexes.count(in: range.toRange() ?? 0..<0)
            currentIndex = currentIndex - countOfIndexesBelowCurrent
        }
        
        // If we removed the current song, start the next one
        if containsCurrentIndex {
            playSong(atIndex: currentIndex)
        }
    }
    
    open func removeSong(atIndex index: Int) {
        var indexSet = IndexSet()
        indexSet.insert(index)
        removeSongs(atIndexes: indexSet)
    }
    
    open func insertSong(song: ISMSSong, index: Int, notify: Bool = false) {
        playlist.insert(song: song, index: index, notify: notify)
        ISMSStreamManager.si().fillStreamQueue(self.audioEngine.isStarted())
    }
    
    open func insertSongNext(song: ISMSSong, notify: Bool = false) {
        let index = currentIndex < 0 ? songCount : currentIndex + 1
        playlist.insert(song: song, index: index, notify: notify)
        ISMSStreamManager.si().fillStreamQueue(self.audioEngine.isStarted())
    }
    
    open func moveSong(fromIndex: Int, toIndex: Int, notify: Bool = false) {
        if playlist.moveSong(fromIndex: fromIndex, toIndex: toIndex, notify: notify) {
            if fromIndex == currentIndex && toIndex < currentIndex {
                // Moved the current song to a lower index
                currentIndex = toIndex
            } else if fromIndex == currentIndex && toIndex > currentIndex {
                // Moved the current song to a higher index
                currentIndex = toIndex - 1
            } else if fromIndex > currentIndex && toIndex <= currentIndex {
                // Moved a song from after the current song to before
                currentIndex += 1
            } else if fromIndex < currentIndex && toIndex >= currentIndex {
                // Moved a song from before the current song to after
                currentIndex -= 1
            }
            
            ISMSStreamManager.si().fillStreamQueue(self.audioEngine.isStarted())
        }
    }
    
    open func songAtIndex(_ index: Int) -> ISMSSong? {
        return playlist.song(atIndex: index)
    }
    
    open func indexAtOffset(_ offset: Int, fromIndex: Int) -> Int {
        switch repeatMode {
        case .normal:
            if offset >= 0 {
                if fromIndex + offset > songCount {
                    // If we're past the end of the play queue, always return the last index + 1
                    return songCount
                } else {
                    return fromIndex + offset
                }
            } else {
                return fromIndex + offset >= 0 ? fromIndex + offset : 0;
            }
        case .repeatAll:
            if offset >= 0 {
                if fromIndex + offset >= songCount {
                    let remainder = offset - (songCount - fromIndex)
                    return indexAtOffset(remainder, fromIndex: 0)
                } else {
                    return fromIndex + offset
                }
            } else {
                return fromIndex + offset >= 0 ? fromIndex + offset : songCount + fromIndex + offset;
            }
        case .repeatOne:
            return fromIndex
        }
    }
    
    open func indexAtOffsetFromCurrentIndex(_ offset: Int) -> Int {
        return indexAtOffset(offset, fromIndex: self.currentIndex)
    }
    
    //
    // MARK: - Player Control -
    //
    
    open func playSongs(_ songs: [ISMSSong], playIndex: Int) {
        reset()
        playlist.add(songs: songs)
        playSong(atIndex: playIndex)
    }
    
    open func playSong(atIndex index: Int) {
        currentIndex = index
        if let currentSong = currentSong {
            ISMSStreamManager.si().removeAllStreamsExcept(for: currentSong)
            if currentSong.contentType?.basicType == .audio {
                startSong()
            }
        }
    }

    open func playPreviousSong() {
        if audioEngine.progress() > 10.0 {
            // Past 10 seconds in the song, so restart playback instead of changing songs
            playSong(atIndex: self.currentIndex)
        } else {
            // Within first 10 seconds, go to previous song
            playSong(atIndex: self.previousIndex)
        }
    }
    
    open func playNextSong() {
        playSong(atIndex: self.nextIndex)
    }
    
    open func play() {
        audioEngine.play()
    }
    
    open func pause() {
        audioEngine.pause()
    }
    
    open func playPause() {
        audioEngine.playPause()
    }
    
    open func stop() {
        audioEngine.stop()
    }
    
    fileprivate var startSongDelayTimer: DispatchSourceTimer?
    func startSong(byteOffset: Int = 0) {
        if let startSongDelayTimer = startSongDelayTimer {
            startSongDelayTimer.cancel()
            self.startSongDelayTimer = nil
        }
        
        if currentSong != nil {
            // Only start the caching process if it's been a half second after the last request
            // Prevents crash when skipping through playlist fast
            startSongDelayTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
            startSongDelayTimer!.scheduleOneshot(deadline: .now() + .milliseconds(600), leeway: .nanoseconds(0))
            startSongDelayTimer!.setEventHandler {
                self.startSongDelayed(byteOffset: byteOffset)
            }
            startSongDelayTimer!.resume()
        } else {
            audioEngine.stop()
        }
    }
    
    fileprivate func startSongDelayed(byteOffset: Int) {
        // Destroy the streamer to start a new song
        self.audioEngine.stop()
        
        if let currentSong = currentSong {
            let settings = SavedSettings.si()
            let streamManager = ISMSStreamManager.si()
            let audioEngineStartSong = {
                self.audioEngine.start(currentSong, index: self.currentIndex, byteOffset: byteOffset)
            }
            
            // Check to see if the song is already cached
            if currentSong.isFullyCached {
                // The song is fully cached, start streaming from the local copy
                audioEngineStartSong()
            } else {
                // Fill the stream queue
                if !settings.isOfflineMode {
                    streamManager.fillStreamQueue(true)
                } else if !currentSong.isFullyCached && settings.isOfflineMode {
                    // TODO: Prevent this running forever in RepeatAll mode with no songs available
                    self.playSong(atIndex: nextIndex)
                } else {
                    if let currentSong = CacheQueueManager.si.currentSong, currentSong.isEqual(to: currentSong) {
                        // The cache queue is downloading this song, remove it before continuing
                        CacheQueueManager.si.removeCurrentSong()
                    }
                    
                    if streamManager.isSongDownloading(currentSong) {
                        // The song is caching, start streaming from the local copy
                        if let handler = streamManager.handler(for: currentSong) {
                            if !audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                                // Only start the player if the handler isn't going to do it itself
                                audioEngineStartSong()
                            }
                        }
                    } else if streamManager.isSongFirst(inQueue: currentSong) && !streamManager.isDownloading {
                        // The song is first in queue, but the queue is not downloading. Probably the song was downloading
                        // when the app quit. Resume the download and start the player
                        streamManager.resumeQueue()
                        
                        // The song is caching, start streaming from the local copy
                        if let handler = streamManager.handler(for: currentSong) {
                            if !self.audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                                // Only start the player if the handler isn't going to do it itself
                                audioEngineStartSong()
                            }
                        }
                    } else {
                        // Clear the stream manager
                        streamManager.removeAllStreams()
                        
                        var isTempCache = false
                        if byteOffset > 0 || !settings.isSongCachingEnabled {
                            isTempCache = true
                        }
                        
                        // Start downloading the current song from the correct offset
                        streamManager.queueStream(for: currentSong, byteOffset: UInt64(byteOffset), at: 0, isTempCache: isTempCache, isStartDownload: true)
                        
                        // Fill the stream queue
                        if settings.isSongCachingEnabled {
                            streamManager.fillStreamQueue(self.audioEngine.isStarted())
                        }
                    }
                }
            }
        }
    }
    
    //
    // MARK: - Lock Screen -
    //
    
    fileprivate var defaultItemArtwork: MPMediaItemArtwork = {
        MPMediaItemArtwork(image: CachedImage.default(forSize: .player))
    }()
    
    fileprivate var lockScreenUpdateTimer: Timer?
    open func updateLockScreenInfo() {
        #if os(iOS)
            var trackInfo = [String: AnyObject]()
            if let song = self.currentSong {
                if let title = song.title {
                    trackInfo[MPMediaItemPropertyTitle] = title as AnyObject?
                }
                if let albumName = song.album?.name {
                    trackInfo[MPMediaItemPropertyAlbumTitle] = albumName as AnyObject?
                }
                if let artistName = song.artistDisplayName {
                    trackInfo[MPMediaItemPropertyArtist] = artistName as AnyObject?
                }
                if let genre = song.genre?.name {
                    trackInfo[MPMediaItemPropertyGenre] = genre as AnyObject?
                }
                if let duration = song.duration {
                    trackInfo[MPMediaItemPropertyPlaybackDuration] = duration
                }
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex as AnyObject?
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = songCount as AnyObject?
                trackInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.progress() as AnyObject?
                trackInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0 as AnyObject?
                
                trackInfo[MPMediaItemPropertyArtwork] = defaultItemArtwork
                if let coverArtId = song.coverArtId, let image = CachedImage.cached(coverArtId: coverArtId, size: .player) {
                    trackInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
                }
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = trackInfo
            }
            
            // Run this every 30 seconds to update the progress and keep it in sync
            if let lockScreenUpdateTimer = self.lockScreenUpdateTimer {
                lockScreenUpdateTimer.invalidate()
            }
            lockScreenUpdateTimer = Timer(timeInterval: 30.0, target: self, selector: #selector(PlayQueue.updateLockScreenInfo), userInfo: nil, repeats: false)
        #endif
    }
}

extension PlayQueue: BassGaplessPlayerDelegate {
    
    public func bassFirstStreamStarted(_ player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.si().playerClearSocial()
    }
    
    public func bassSongEndedCalled(_ player: BassGaplessPlayer) {
        // Increment current playlist index
        currentIndex = nextIndex
        
        // TODO: Is this the best place for this?
        SocialSingleton.si().playerClearSocial()
    }
    
    public func bassFreed(_ player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.si().playerClearSocial()
    }

    public func bassIndex(atOffset offset: Int, from index: Int, player: BassGaplessPlayer) -> Int {
        return indexAtOffset(offset, fromIndex: index)
    }
    
    public func bassSong(for index: Int, player: BassGaplessPlayer) -> ISMSSong? {
        return songAtIndex(index)
    }
    
    public func bassCurrentPlaylistIndex(_ player: BassGaplessPlayer) -> Int {
        return currentIndex
    }
    
    public func bassRetrySong(at index: Int, player: BassGaplessPlayer) {
        Async.main {
            self.playSong(atIndex: index)
        }
    }
    
    public func bassUpdateLockScreenInfo(_ player: BassGaplessPlayer) {
        updateLockScreenInfo()
    }
    
    public func bassRetrySongAtOffset(inBytes bytes: Int, player: BassGaplessPlayer) {
        startSong(byteOffset: bytes)
    }
    
    public func bassFailedToCreateNextStream(for index: Int, player: BassGaplessPlayer) {
        // The song ended, and we tried to make the next stream but it failed
        if let song = self.songAtIndex(index), let handler = ISMSStreamManager.si().handler(for: song) {
            if !handler.isDownloading || handler.isDelegateNotifiedToStartPlayback {
                // If the song isn't downloading, or it is and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
                Async.main {
                    self.playSong(atIndex: index)
                }
            }
        }
    }
    
    public func bassRetrievingOutputData(_ player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.si().playerHandleSocial()
    }
}