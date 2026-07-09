import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GameState {
  final List<int> board;
  final List<int> initial;
  final List<int> solution;
  final Map<int, List<int>> notes;
  final int mistakes;
  final int helpCount;
  final int elapsedTime; // en segundos
  final String mode; // 'zen' o 'reto'
  final int difficulty;

  GameState({
    required this.board,
    required this.initial,
    required this.solution,
    required this.notes,
    required this.mistakes,
    required this.helpCount,
    required this.elapsedTime,
    required this.mode,
    required this.difficulty,
  });

  Map<String, dynamic> toJson() => {
        'board': board,
        'initial': initial,
        'solution': solution,
        'notes': notes.map((k, v) => MapEntry(k.toString(), v)),
        'mistakes': mistakes,
        'helpCount': helpCount,
        'elapsedTime': elapsedTime,
        'mode': mode,
        'difficulty': difficulty,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> notesJson = json['notes'] ?? {};
    Map<int, List<int>> parsedNotes = {};
    notesJson.forEach((k, v) {
      parsedNotes[int.parse(k)] = List<int>.from(v);
    });

    return GameState(
      board: List<int>.from(json['board']),
      initial: List<int>.from(json['initial']),
      solution: List<int>.from(json['solution']),
      notes: parsedNotes,
      mistakes: json['mistakes'] ?? 0,
      helpCount: json['helpCount'] ?? 3,
      elapsedTime: json['elapsedTime'] ?? 0,
      mode: json['mode'] ?? 'reto',
      difficulty: json['difficulty'] ?? 1,
    );
  }
}

class GameStorage {
  static const String _keyState = 'current_game_state';
  static const String _keyStatsRetoWon = 'stats_reto_won';
  static const String _keyStatsRetoPlayed = 'stats_reto_played';
  static const String _keyStatsMaestroWon = 'stats_maestro_won';
  static const String _keyTutorialSeen = 'tutorial_seen';
  static const String _keyUnlockedQuotes = 'unlocked_quotes';
  // Se desbloquea Diabólico tras ganar 10 partidas en Modo Reto Maestro
  static const int _diabolicoUnlockThreshold = 10;

  static Future<void> saveGameState(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyState, jsonEncode(state.toJson()));
  }

  // --- Tutorial ---
  static Future<bool> hasTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTutorialSeen) ?? false;
  }

  static Future<void> setTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialSeen, true);
  }

  // --- Quotes / Recompensas ---
  static Future<List<int>> getUnlockedQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyUnlockedQuotes) ?? [];
    return list.map((e) => int.tryParse(e)).where((e) => e != null).cast<int>().toList();
  }

  static Future<void> unlockQuote(int id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_keyUnlockedQuotes) ?? [];
    if (!list.contains(id.toString())) {
      list.add(id.toString());
      await prefs.setStringList(_keyUnlockedQuotes, list);
    }
  }

  static Future<GameState?> loadGameState() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyState);
    if (data != null) {
      try {
        return GameState.fromJson(jsonDecode(data));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clearGameState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyState);
  }

  static Future<void> incrementRetoPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyStatsRetoPlayed) ?? 0;
    await prefs.setInt(_keyStatsRetoPlayed, current + 1);
  }

  static Future<void> incrementRetoWon({int difficulty = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyStatsRetoWon) ?? 0;
    await prefs.setInt(_keyStatsRetoWon, current + 1);
    // Contabilizar si fue una victoria en Maestro (dificultad 3)
    if (difficulty == 3) {
      int maestroWon = prefs.getInt(_keyStatsMaestroWon) ?? 0;
      await prefs.setInt(_keyStatsMaestroWon, maestroWon + 1);
    }
  }

  static Future<bool> isDiabolicoUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    int maestroWon = prefs.getInt(_keyStatsMaestroWon) ?? 0;
    return maestroWon >= _diabolicoUnlockThreshold;
  }

  static Future<int> getMaestroWins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStatsMaestroWon) ?? 0;
  }

  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'played': prefs.getInt(_keyStatsRetoPlayed) ?? 0,
      'won': prefs.getInt(_keyStatsRetoWon) ?? 0,
      'maestroWon': prefs.getInt(_keyStatsMaestroWon) ?? 0,
    };
  }
}
