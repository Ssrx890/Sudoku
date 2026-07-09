import 'package:flutter/material.dart';
import '../managers/audio_manager.dart';

import '../managers/game_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _played = 0;
  int _won = 0;
  int _maestroWon = 0;
  bool _musicOn = AudioManager.isMusicOn;
  bool _sfxOn = AudioManager.isSfxOn;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() async {
    final stats = await GameStorage.getStats();
    if (mounted) {
      setState(() {
        _played = stats['played'] ?? 0;
        _won = stats['won'] ?? 0;
        _maestroWon = stats['maestroWon'] ?? 0;
      });
    }
  }

  Widget _sectionHeader(String text, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 16),
      child: Text(
        text,
        style: TextStyle(
          color: colors.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Ajustes",
          style: TextStyle(color: colors.primary, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.primary),
      ),
      body: ListView(
        children: [
          _sectionHeader("AUDIO", colors),
          SwitchListTile(
            title: Text("Música Zen", style: TextStyle(color: colors.primary)),
            subtitle: Text(
              "Sonido de fondo relajante",
              style: TextStyle(color: colors.primary.withAlpha(140), fontSize: 12),
            ),
            value: _musicOn,
            activeThumbColor: colors.primary,
            activeTrackColor: colors.secondary,
            onChanged: (val) {
              setState(() => _musicOn = val);
              AudioManager.toggleMusic(val);
            },
          ),
          SwitchListTile(
            title:
                Text("Efectos de Sonido", style: TextStyle(color: colors.primary)),
            subtitle: Text(
              "Sonidos al pulsar y al completar",
              style:
                  TextStyle(color: colors.primary.withAlpha(140), fontSize: 12),
            ),
            value: _sfxOn,
            activeThumbColor: colors.primary,
            activeTrackColor: colors.secondary,
            onChanged: (val) {
              setState(() => _sfxOn = val);
              AudioManager.toggleSFX(val);
            },
          ),

          _sectionHeader("ESTADÍSTICAS — MODO RETO", colors),
          _statRow("Partidas jugadas", "$_played", colors),
          _statRow("Partidas ganadas", "$_won", colors),
          _statRow("Victorias Maestro", "$_maestroWon / 10", colors,
              subtitle: _maestroWon >= 10
                  ? "💀 Diabólico desbloqueado"
                  : "Faltan ${10 - _maestroWon} para desbloquear Diabólico"),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, ColorScheme colors,
      {String? subtitle}) {
    return ListTile(
      title: Text(label, style: TextStyle(color: colors.primary)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(
                  color: colors.secondary.withAlpha(200), fontSize: 12))
          : null,
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: colors.primary,
        ),
      ),
    );
  }
}
