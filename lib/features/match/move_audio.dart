import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A preloaded UI click owned by a match screen.
/// Playback gain is fixed; the device's media volume controls audible loudness.
class MoveAudio {
  MoveAudio({AudioPlayer? player})
    : _useNativePlayer =
          player == null &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS,
      _player = player;

  static const _channel = MethodChannel('crown/move_audio');
  final bool _useNativePlayer;
  AudioPlayer? _player;
  int? _soundId;
  Future<void>? _preparation;
  Future<void> _queue = Future.value();
  Completer<void>? _playbackFinished;
  StreamSubscription<void>? _completionSubscription;
  bool _ready = false;
  bool _disposed = false;

  Future<void> prepare() {
    if (_disposed) return Future.value();
    return _preparation ??= _prepare().whenComplete(() {
      if (!_ready) _preparation = null;
    });
  }

  Future<void> _prepare() async {
    try {
      if (_useNativePlayer) {
        _soundId = await _channel.invokeMethod<int>('prepare');
        if (_soundId == null) {
          throw PlatformException(
            code: 'move-audio-prepare',
            message: 'Move sound was not created',
          );
        }
      } else {
        final player = _player ??= AudioPlayer();
        _completionSubscription ??= player.onPlayerComplete.listen((_) {
          final finished = _playbackFinished;
          if (finished != null && !finished.isCompleted) finished.complete();
        });
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(1);
        await player.setSource(AssetSource('move.wav'));
      }
      _ready = true;
    } on MissingPluginException {
      // Audio is unavailable in hosts without a native plugin.
    } on Exception catch (error) {
      debugPrint('Unable to prepare move audio: $error');
    }
  }

  Future<void> play() {
    if (_disposed) return Future.value();
    return _queue = _queue.then((_) => _play());
  }

  Future<void> _play() async {
    if (_disposed) return;
    await prepare();
    if (_disposed) return;
    if (!_ready) return;
    try {
      if (_useNativePlayer) {
        await _channel
            .invokeMethod<void>('play', _soundId)
            .timeout(const Duration(seconds: 2));
      } else {
        await _player!.stop();
        if (_disposed) return;
        final finished = _playbackFinished = Completer<void>();
        await _player!.resume();
        await finished.future.timeout(const Duration(seconds: 2));
      }
    } on Exception catch (error) {
      debugPrint('Unable to play move audio: $error');
    } finally {
      _playbackFinished = null;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final finished = _playbackFinished;
    if (finished != null && !finished.isCompleted) finished.complete();
    await _preparation;
    try {
      if (_soundId != null) {
        await _channel.invokeMethod<void>('dispose', _soundId);
      }
      await _player?.dispose();
      await _completionSubscription?.cancel();
    } on MissingPluginException {
      // No native player was created.
    } on Exception catch (error) {
      debugPrint('Unable to release move audio: $error');
    }
  }
}
