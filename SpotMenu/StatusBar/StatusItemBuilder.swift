//
//  StatusItemBuilder.swift
//  SpotMenu
//
//  Created by Miklós Kristyán on 2017. 05. 01..
//  Copyright © 2017. KM. All rights reserved.
//

import Foundation

final class StatusItemBuilder {

    // MARK: - Properties

    private var title = ""
    private var artist = ""
    private var albumName = ""
    private var key = ""
    private var playingIcon = ""
    private var isPlaying: Bool = false
    private var hideWhenPaused = false

    // MARK: - Lifecycle method

    init(title: String?, artist: String?, albumName: String?, key: String?, isPlaying: Bool) {
        if let v = title {
            self.title = v
        }
        if let v = artist {
            self.artist = v
        }
        if let v = albumName {
            self.albumName = v
        }
        if let v = key {
            self.key = v
        }
        self.isPlaying = isPlaying
    }

    // MARK: - Methods
    
    func setKey(newValue: String) {
        self.key = newValue
    }

    func hideWhenPaused(v: Bool) -> StatusItemBuilder {
        hideWhenPaused = v
        return self
    }

    func showTitle(v: Bool) -> StatusItemBuilder {
        if !v {
            title = ""
            return self
        }
        if !isPlaying && hideWhenPaused {
            title = ""
            return self
        }
        return self
    }

    func showArtist(v: Bool) -> StatusItemBuilder {
        if !v {
            artist = ""
            return self
        }
        if !isPlaying && hideWhenPaused {
            artist = ""
            return self
        }
        return self
    }

    func showAlbumName(v: Bool) -> StatusItemBuilder {
        if !v {
            albumName = ""
            return self
        }
        if !isPlaying && hideWhenPaused {
            albumName = ""
            return self
        }
        return self
    }
    
    func showTrackKey(v: Bool) -> StatusItemBuilder {
        if !v {
            key = ""
            return self
        }
        if !isPlaying && hideWhenPaused {
            key = ""
            return self
        }
        return self
    }

    func showPlayingIcon(v: Bool) -> StatusItemBuilder {
        if !v {
            playingIcon = ""
            return self
        }
        if isPlaying {
            playingIcon = "♫ "
        } else {
            playingIcon = ""
        }
        return self
    }

    func getString() -> String {
        var res = "\(playingIcon)"
        if artist.count != 0 {
            res += artist
        }
        if title.count != 0 {
            res += " - \(title)"
        }
        if albumName.count != 0 {
            res += " - \(albumName)"
        }
        if key.count != 0 {
            res += " - \(key)"
        }
        
        return res
    }
}
