//
//  Spotify.swift
//  MusicPlayer
//
//  Created by Michael Row on 2017/8/31.
//

import Foundation
import ScriptingBridge

class Spotify {
    
    var spotifyPlayer: SpotifyApplication
    
    var currentTrack: MusicTrack?
    
    weak var delegate: MusicPlayerDelegate?
    
    let SpotifyClientId = "<CLIENT ID>"
    let SpotifyClientSecret = "<CLIENT SECRET>"
    var apiKeyExpires: Date?
    var apiKey: String?
    
    var rememberedTrackStateDate = Date()
    
    fileprivate(set) var hashValue: Int
    
    required init?() {
        guard let player = SBApplication(bundleIdentifier: MusicPlayerName.spotify.bundleID) else { return nil }
        spotifyPlayer = player
        hashValue = Int(arc4random())
        getApiKey()
    }
    
    deinit {
        stopPlayerTracking()
    }
    
    func isApiKeyExpired() -> Bool {
        if apiKey == nil || apiKeyExpires == nil { return true }
        let currentDate = Date()
        let comparisonResult = currentDate.compare(apiKeyExpires!)

        return comparisonResult == .orderedDescending
    }

    func getApiKey() -> Void {
        let urlString = "https://accounts.spotify.com/api/token"
        let url = URL(string: urlString)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"

        let authorizationHeader = "\(SpotifyClientId):\(SpotifyClientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
        request.setValue("Basic \(authorizationHeader)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Failed to get API key: \(error)")
                return
            }

            do {
                let response = try JSONDecoder().decode(TokenResponse.self, from: data!)
                var calendar = Calendar.current
                calendar.timeZone = TimeZone.current
                
                self.apiKey = response.access_token
                self.apiKeyExpires = calendar.date(byAdding: .second, value: response.expires_in, to: Date())
                print("API key acquired: \(self.apiKey!)")
                
            } catch {
                print("Failed to decode API key: \(error)")
            }
        }
        task.resume()
    }
    
    // MARK: - Player Event Handle
    
    func pauseEvent() {
        PlayerTimer.shared.unregister(self)
        delegate?.player(self, playbackStateChanged: .paused, atPosition: playerPosition)
    }
    
    func stoppedEvent() {
        PlayerTimer.shared.unregister(self)
        delegate?.playerDidQuit(self)
    }
    
    func playingEvent() {
        musicTrackCheckEvent()
        if currentTrack?.key == nil {
            getTrackKey()
        }
        delegate?.player(self, playbackStateChanged: .playing, atPosition: playerPosition)
        startPeriodTimerObserving()
    }
    
    func getTrackKey() {
        if isApiKeyExpired() {
            getApiKey()
            return
        }
        let parts = currentTrack!.id.components(separatedBy: ":")
        getTrackAnalysis(songId: parts[2])
    }
    
    
    func getTrackAnalysis(songId: String) -> Void {
        if isApiKeyExpired() { return }
        let urlString = "https://api.spotify.com/v1/audio-analysis/\(songId)"
        let url = URL(string: urlString)
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey!)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Failed to query track analysis: \(error)")
                return
            }

            do {
                let audioAnalysis = try JSONDecoder().decode(AudioAnalysis.self, from: data!)
                self.currentTrack?.key = getKeyFromAnalysis(audioAnalysis)
            } catch {
                print("Failed to decode track analysis: \(error)")
            }
        }
        task.resume()
    }
    
    // MARK: - Notification Events
    
    @objc func playerInfoChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let playerState = userInfo["Player State"] as? String
        else { return }
        
        switch playerState {
        case "Paused":
            pauseEvent()
        case "Stopped":
            stoppedEvent()
        case "Playing":
            playingEvent()
        default:
            break
        }
    }
    
    // MARK: - Timer Events
    
    func startPeriodTimerObserving() {
        // start timer
        let event = PlayerTimer.Event(kind: .Infinite, precision: MusicPlayerConfig.TimerInterval) { time in
            self.repositionCheckEvent()
        }
        PlayerTimer.shared.register(self, event: event)

        // write down the track start time
        rememberedTrackStateDate = trackStartDate
    }
}


func getKeyFromAnalysis(_ anal: AudioAnalysis) -> String {
    let key = getKey(anal.track.key)
    let mode = anal.track.mode == 0 ? "m" : ""
    return "\(key)\(mode)"
}

func getKey(_ key: Int) -> String {
    switch key {
    case 0: return "C"
    case 1: return "C♯"
    case 2: return "D"
    case 3: return "D♭"
    case 4: return "E"
    case 5: return "F"
    case 6: return "F♯"
    case 7: return "G"
    case 8: return "G♭"
    case 9: return "A"
    case 10: return "B♭"
    case 11: return "B"
    default: return "N/A"
    }
}


struct TokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct AudioAnalysis: Decodable {
    let meta: Meta
    let track: Track
    let bars: [Bar]
    let beats: [Beat]
    let sections: [Section]
    let tatums: [Tatum]
    let segments: [Segment]

    private enum CodingKeys: String, CodingKey {
        case meta
        case track
        case bars
        case beats
        case sections
        case tatums
        case segments
    }
}

struct Meta: Decodable {
    let analyzer_version: String
    let platform: String
    let detailed_status: String
    let status_code: Int
    let timestamp: Int
    let analysis_time: Double
    let input_process: String
}

struct Track: Decodable {
    let num_samples: Int
    let duration: Double
    let sample_md5: String
    let offset_seconds: Int
    let window_seconds: Int
    let analysis_sample_rate: Double
    let analysis_channels: Int
    let end_of_fade_in: Double
    let start_of_fade_out: Double
    let loudness: Double
    let tempo: Double
    let tempo_confidence: Double
    let time_signature: Int
    let time_signature_confidence: Double
    let key: Int
    let key_confidence: Double
    let mode: Int
    let mode_confidence: Double
    let codestring: String
    let code_version: Double
    let echoprintstring: String
    let echoprint_version: Double
    let synchstring: String
    let synch_version: Double
    let rhythmstring: String
    let rhythm_version: Double
}

struct Bar: Decodable {
    let start: Double
    let duration: Double
    let confidence: Double
}

struct Beat: Decodable {
    let start: Double
    let duration: Double
    let confidence: Double
}

struct Section: Decodable {
    let start: Double
    let duration: Double
    let confidence: Double
    let loudness: Double
    let tempo: Double
    let tempo_confidence: Double
    let key: Int
    let key_confidence: Double
    let mode: Int
    let mode_confidence: Double
    let time_signature: Int
    let time_signature_confidence: Double
}

struct Tatum: Decodable {
    let start: Double
    let duration: Double
    let confidence: Double
}

struct Segment: Decodable {
    let start: Double
    let duration: Double
    let confidence: Double
    let loudness_start: Double
    let loudness_max_time: Double
    let loudness_max: Double
    let loudness_end: Double
    let pitches: [Double]
    let timbre: [Double]
}


enum APIError: Error {
    case invalidURL
    case invalidData
}


// MARK: - Spotify Track

extension SpotifyTrack {
    
    var musicTrack: MusicTrack? {
        
        guard let id = id?(),
              let title = name,
              let duration = duration
        else { return nil }
        
        var url: URL? = nil
        if let spotifyUrl = spotifyUrl {
            url = URL(fileURLWithPath: spotifyUrl)
        }
        return MusicTrack(id: id, title: title, album: album, artist: artist, key: nil, duration: TimeInterval(duration/1000), artwork: artwork, artworkUrl: artworkUrl, lyrics: nil, url: url, originalTrack: self as? SBObject)
    }
}
