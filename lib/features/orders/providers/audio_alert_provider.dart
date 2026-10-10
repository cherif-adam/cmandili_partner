import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../data/models/order.dart';
import 'partner_orders_provider.dart';
import '../../../core/push/alarm_volume.dart';

/// Service responsable de la lecture de la sonnerie en boucle.
class AudioAlertService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isInitialized = false;

  AudioAlertService();

  Future<void> _init() async {
    if (_isInitialized) return;
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Alarm stream, not media: with the media volume turned down (a phone
    // that was used for a video and muted) this in-app alert was silent
    // while the partner sat on the orders screen. The alarm stream is the
    // one maxAlarmVolume() raises, and it plays through silent mode.
    await _audioPlayer.setAudioContext(const AudioContext(
      android: AudioContextAndroid(
        usageType: AndroidUsageType.alarm,
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    ));
    _isInitialized = true;
  }

  Future<void> playNewOrderAlert() async {
    if (_isPlaying) return;
    try {
      _isPlaying = true;
      await _init();
      // If stopAlert was called during init, cancel playback.
      if (!_isPlaying) return;
      // assets/audio/new_order.wav: the same alarm as the notification
      // (android res/raw/new_order.wav), boosted to full level.
      await maxAlarmVolume();
      await _audioPlayer.play(AssetSource('audio/new_order.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('Erreur lors de la lecture de l\'alerte sonore: $e');
      _isPlaying = false;
    }
  }

  Future<void> stopAlert() async {
    if (!_isPlaying) return;
    try {
      _isPlaying = false;
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Erreur lors de l\'arrêt de l\'alerte sonore: $e');
    }
  }
}

final audioAlertServiceProvider = Provider<AudioAlertService>((ref) {
  final service = AudioAlertService();
  ref.onDispose(() => service._audioPlayer.dispose());
  return service;
});

/// Provider qui écoute le flux des commandes et déclenche ou arrête le son
/// en fonction de la présence de commandes 'pending'.
final orderAlertProvider = Provider<void>((ref) {
  final audioService = ref.read(audioAlertServiceProvider);
  final ordersAsync = ref.watch(partnerOrdersStreamProvider);

  ordersAsync.whenData((orders) {
    // Vérifie s'il y a au moins une commande en attente
    final hasPendingOrders = orders.any((order) => order.status == OrderStatus.pending);

    if (hasPendingOrders) {
      audioService.playNewOrderAlert();
    } else {
      audioService.stopAlert();
    }
  });
});
