import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

class AudioManager {
  static final AudioPlayer _bgmPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  static bool _musicOn = true;
  static bool _sfxOn = true;
  static bool _isTest = false;

  static Future<void> init() async {
    try {
      try {
        _isTest = const bool.fromEnvironment('FLUTTER_TEST') ||
            WidgetsBinding.instance.toString().contains('Test') ||
            WidgetsBinding.instance.toString().contains('Mock');
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      _musicOn = prefs.getBool('music_on') ?? true;
      _sfxOn = prefs.getBool('sfx_on') ?? true;

      if (_isTest) return;

      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.25); // Volumen Zen
    } catch (e) {
      debugPrint("AudioManager init error: $e");
    }
  }

  static void playGameMusic() async {
    if (_isTest) return;
    try {
      if (_musicOn && _bgmPlayer.state != PlayerState.playing) {
        await _bgmPlayer.play(AssetSource('audio/bg_music.mp3'));
      }
    } catch (e) {
      debugPrint("AudioManager play error: $e");
    }
  }

  static void stopBGM() async {
    if (_isTest) return;
    await _bgmPlayer.stop();
  }

  static void toggleMusic(bool value) async {
    _musicOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_on', value);
    if (_musicOn) {
      playGameMusic();
    } else {
      stopBGM();
    }
  }

  /// Sonido al colocar un número correcto
  static void playClick() {
    if (_isTest) return;
    if (_sfxOn) _sfxPlayer.play(AssetSource('audio/click.mp3'), volume: 0.7);
  }

  /// Sonido al colocar un número incorrecto
  static void playError() {
    if (_isTest) return;
    if (_sfxOn) _sfxPlayer.play(AssetSource('audio/error.mp3'), volume: 0.8);
  }

  /// Sonido al perder la partida (3 errores)
  static void playFail() {
    if (_isTest) return;
    if (_sfxOn) _sfxPlayer.play(AssetSource('audio/fail.mp3'), volume: 0.9);
  }

  /// Sonido al ganar la partida
  static void playWin() {
    if (_isTest) return;
    if (_sfxOn) _sfxPlayer.play(AssetSource('audio/win.mp3'), volume: 0.8);
  }

  static void toggleSFX(bool value) async {
    _sfxOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sfx_on', value);
  }

  static bool get isMusicOn => _musicOn;
  static bool get isSfxOn => _sfxOn;
}
