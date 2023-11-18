import UIKit
import MediaPlayer

class ViewController: UIViewController {
    
    var musicPlayer: MPMusicPlayerController?
    var batteryStateTimer: Timer?
    var selectTimer: Timer?
    var locked = false
    var albumArtworkVisible = true
    var repeatMode = false
    
    @IBOutlet weak var albumArtwork: UIImageView!
    
    @IBOutlet weak var titleOutlet: UILabel!
    
    @IBOutlet weak var artistOutlet: UILabel!
    
    @IBOutlet weak var rewindButton: UIImageView!
    
    @IBOutlet weak var playPauseButton: UIImageView!
    
    @IBOutlet weak var skipButton: UIImageView!
    
    @IBOutlet weak var batteryStatus: UIImageView!
    
    @IBOutlet weak var lockButton: UIImageView!
    
    @IBOutlet weak var repeatButton: UIImageView!
    
    func pressAnimation(button: UIImageView) {
        button.alpha = 0.3

        selectTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in button.alpha = 1.0 }
    }
    
    @IBAction func rewindButtonPress (_ sender: UITapGestureRecognizer) {
        if locked == true || musicPlayer == nil { return }
        pressAnimation(button: rewindButton)

        if musicPlayer!.currentPlaybackTime < 5 {
            musicPlayer?.skipToPreviousItem()
        } else {
            musicPlayer?.skipToBeginning()
        }
    }
    
    @IBAction func playPauseButtonPress(_ sender: UITapGestureRecognizer) {
        if locked == true || musicPlayer == nil { return }
        pressAnimation(button: playPauseButton)

        if musicPlayer?.playbackState == .playing {
            musicPlayer?.pause()
            playPauseButton.image = UIImage(systemName: "play.fill")
        } else {
            musicPlayer?.play()
            playPauseButton.image = UIImage(systemName: "pause.fill")
        }
    }
    
    @IBAction func skipButtonPressed(_ sender: UITapGestureRecognizer) {
        if locked == true || musicPlayer == nil { return }
        pressAnimation(button: skipButton)
        musicPlayer?.skipToNextItem()
    }
    
    @IBAction func lockButtonPressed(_ sender: UITapGestureRecognizer) {
        pressAnimation(button: lockButton)
        if locked == true {
            lockButton.image = UIImage(systemName: "lock.open.fill")
            lockButton.tintColor = UIColor.green
            locked = false

            rewindButton.tintColor = UIColor.white
            playPauseButton.tintColor = UIColor.white
            skipButton.tintColor = UIColor.white
            repeatButton.tintColor = UIColor.white

        } else {
            lockButton.image = UIImage(systemName: "lock.fill")
            lockButton.tintColor = UIColor.red
            locked = true

            rewindButton.tintColor = UIColor.red
            playPauseButton.tintColor = UIColor.red
            skipButton.tintColor = UIColor.red
            repeatButton.tintColor = UIColor.red
        }
    }
    
    @IBAction func toggleAlbumArtworkVisible(_ sender: UITapGestureRecognizer) {
        albumArtworkVisible = albumArtworkVisible == true ? false : true
        displayAlbumArtwork()
    }
    
    @IBAction func toggleRepeatSong(_ sender: UITapGestureRecognizer) {
        if locked == true { return }
        
        if repeatMode == true {
            repeatMode = false
            musicPlayer?.repeatMode = .all
            repeatButton.tintColor = UIColor.white
            repeatButton.image = UIImage(systemName: "repeat")
        } else {
            repeatMode = true
            musicPlayer?.repeatMode = .one
            repeatButton.tintColor = UIColor.green
            repeatButton.image = UIImage(systemName: "repeat.1")
        }
    }
    
    func displayAlbumArtwork() {
        if albumArtworkVisible == true {
            if let albumImage = musicPlayer?.nowPlayingItem?.artwork?.image(at: CGSize(width: 500, height: 500)) {
                albumArtwork.image = albumImage
            } else {
                albumArtwork.image = UIImage(systemName: "photo.artframe")
                albumArtwork.tintColor = UIColor.white
            }
        } else {
            albumArtwork.image = nil
        }
    }
    
    func togglePlayButtonIcon() {
        if musicPlayer?.playbackState == .playing {
            playPauseButton.image = UIImage(systemName: "pause.fill")
        } else if musicPlayer?.playbackState == .paused {
            playPauseButton.image = UIImage(systemName: "play.fill")
        }
    }
    
    @objc func getAuthorization() {
        let mediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()

        if mediaLibraryAuthorizationStatus != .authorized {
            MPMediaLibrary.requestAuthorization { authorizationStatus in
                if authorizationStatus == .authorized {
                    DispatchQueue.main.async {
                        
                        if self.musicPlayer == nil {
                            self.musicPlayer = MPMusicPlayerController.systemMusicPlayer
                            self.musicPlayer?.repeatMode = .all
                        }
                        
                        self.displayMusicInfo()
                        self.togglePlayButtonIcon()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showPermissionDeniedAlert()
                        self.titleOutlet.text = "Permission refused"
                        self.artistOutlet.text = "Change permissions in Settings or re-install app"
                    }
                }
            }
        } else {
            
            if self.musicPlayer == nil {
                self.musicPlayer = MPMusicPlayerController.systemMusicPlayer
                self.musicPlayer?.repeatMode = .all
            }
            
            return;
        }
    }
    
    func showPermissionDeniedAlert() {
        let alertController = UIAlertController(
            title: "Permission Denied",
            message: "To use this app, you must grant permission to access your music library. Please go to Settings and grant the necessary permissions, or re-install the app.",
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        UIDevice.current.isBatteryMonitoringEnabled = true

        getAuthorization()
        displayMusicInfo()
                                
        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateChanged(_:)), name: UIDevice.batteryStateDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(systemSongDidChange(_:)), name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: musicPlayer)
        
        NotificationCenter.default.addObserver(self, selector: #selector(displayMusicInfo), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
        
    @objc func batteryStateChanged(_ notification: Notification) {
        
        let batteryState = UIDevice.current.batteryState

        if (batteryState == .charging || batteryState == .full) {
            
            batteryStatus.image = UIImage(systemName: "battery.100.bolt")
            batteryStatus.tintColor = UIColor.green
            
            if locked == true { return }
            cancelBatteryCheckTimer()
            musicPlayer?.play()
            playPauseButton.image = UIImage(systemName: "pause.fill")

        } else if batteryState == .unplugged {
            batteryStatus.image = UIImage(systemName: "battery.0")
            batteryStatus.tintColor = UIColor.red
            
            if locked == true { return }
            startBatteryCheckTimer()
        }
    }
    
    @objc func systemSongDidChange(_ notification: Notification) {
        displayMusicInfo()
    }
    
    @objc func displayMusicInfo() {
        if let currentlyPlaying = musicPlayer?.nowPlayingItem {
            displayAlbumArtwork()
            titleOutlet.text = currentlyPlaying.title != nil ? currentlyPlaying.title : ""
            artistOutlet.text = currentlyPlaying.artist != nil ? currentlyPlaying.artist : ""
        }
                
        togglePlayButtonIcon()
        
        let batteryState = UIDevice.current.batteryState
        
        if (batteryState == .charging || batteryState == .full) {
            batteryStatus.image = UIImage(systemName: "battery.100.bolt")
            batteryStatus.tintColor = UIColor.green
    
        } else if batteryState == .unplugged {
            batteryStatus.image = UIImage(systemName: "battery.0")
            batteryStatus.tintColor = UIColor.red
        }
    }
        
    func startBatteryCheckTimer() {
        cancelBatteryCheckTimer()
        batteryStateTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.checkBatteryStateAndPauseMusic()
        }
    }
    
    func cancelBatteryCheckTimer() {
        batteryStateTimer?.invalidate()
        batteryStateTimer = nil
    }
    
    func checkBatteryStateAndPauseMusic() {
        let batteryState = UIDevice.current.batteryState

        if batteryState == .unplugged {
            musicPlayer?.pause()
            playPauseButton.image = UIImage(systemName: "play.fill")
        }
    }
}

