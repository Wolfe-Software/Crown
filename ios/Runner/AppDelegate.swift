import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CrownMoveAudio") {
      CrownMoveAudio.register(with: registrar)
    }
  }
}

/// Preloaded short effects use media volume and honor the silent switch.
final class CrownMoveAudio: NSObject, FlutterPlugin {
  private var sounds: [Int: CrownClickPlayer] = [:]
  private var nextID = 0

  private func activateSession() throws {
    let session = AVAudioSession.sharedInstance()
    // Ambient mixes with other apps and uses playback volume, not alert volume.
    try session.setCategory(.ambient, mode: .default)
    try session.setActive(true)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "crown/move_audio", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(CrownMoveAudio(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "prepare" {
      let key = FlutterDartProject.lookupKey(forAsset: "assets/move.wav")
      guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
        result(FlutterError(code: "move-audio-asset", message: "Move click asset is missing", details: nil))
        return
      }
      do {
        try activateSession()
        let sound = try CrownClickPlayer(url: URL(fileURLWithPath: path))
        nextID += 1
        sounds[nextID] = sound
        result(nextID)
      } catch {
        result(FlutterError(code: "move-audio-prepare", message: error.localizedDescription, details: nil))
      }
      return
    }
    guard call.method == "play" || call.method == "dispose" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let number = call.arguments as? NSNumber, let sound = sounds[number.intValue] else {
      result(FlutterError(code: "move-audio-id", message: "Move click is not prepared", details: nil))
      return
    }
    if call.method == "play" {
      do {
        try activateSession()
        sound.play(result: result)
      } catch {
        result(FlutterError(code: "move-audio-session", message: error.localizedDescription, details: nil))
      }
    } else {
      sound.stop()
      sounds.removeValue(forKey: number.intValue)
      result(nil)
    }
  }

  deinit {
    for sound in sounds.values { sound.stop() }
  }
}

final class CrownClickPlayer: NSObject, AVAudioPlayerDelegate {
  private let player: AVAudioPlayer
  private var completion: FlutterResult?

  init(url: URL) throws {
    player = try AVAudioPlayer(contentsOf: url)
    super.init()
    player.delegate = self
    player.volume = 1
    guard player.prepareToPlay() else {
      throw NSError(domain: "CrownMoveAudio", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot preload move click"])
    }
  }

  func play(result: @escaping FlutterResult) {
    // Pause preserves preloaded audio resources; stop is reserved for disposal.
    player.pause()
    finish(nil)
    player.currentTime = 0
    completion = result
    if !player.play() {
      finish(FlutterError(code: "move-audio-play", message: "Cannot start move click", details: nil))
    }
  }

  func stop() {
    player.stop()
    finish(nil)
  }

  private func finish(_ value: Any?) {
    let callback = completion
    completion = nil
    callback?(value)
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    finish(flag ? nil : FlutterError(code: "move-audio-play", message: "Move click interrupted", details: nil))
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    finish(FlutterError(code: "move-audio-decode", message: error?.localizedDescription, details: nil))
  }
}
