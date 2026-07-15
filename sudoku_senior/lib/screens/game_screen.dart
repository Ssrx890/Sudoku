import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../engine/sudoku_engine.dart';
import '../managers/game_storage.dart';
import '../managers/ad_manager.dart';
import '../managers/audio_manager.dart';
import '../data/quotes_data.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/numpad.dart';
import '../widgets/mini_board.dart';
import '../widgets/mini_numpad.dart';
import '../widgets/zen_background.dart';
import 'tutorial_screen.dart';

class GameStateSnapshot {
  final List<int> board;
  final Map<int, List<int>> notes;
  GameStateSnapshot(this.board, this.notes);
}

class GameScreen extends StatefulWidget {
  final String mode; // 'zen', 'reto', 'continue', 'aprendiz'
  final int difficulty;
  final int gridSize; // 9 = clásico, 4 = Modo Aprendiz

  const GameScreen({
    super.key,
    required this.mode,
    required this.difficulty,
    this.gridSize = 9,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  List<int> board = [];
  List<int> initial = [];
  List<int> solution = [];
  Map<int, List<int>> notes = {};
  
  int selectedIndex = -1;
  bool isPencilMode = false;
  int mistakes = 0;
  int helpCount = 3;
  int elapsedTime = 0;
  String currentMode = 'reto';
  int currentDifficulty = 1;
  int currentGridSize = 9; // 9 o 4 (Modo Aprendiz)

  List<GameStateSnapshot> undoStack = [];
  Timer? _timer;

  late AdManager _adManager;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isPaused = false;
  bool _isGenerating = false; // Generación asíncrona en progreso
  bool _gameFinished = false; // Evita guardar estado tras ganar/perder
  bool _tenMinuteRewardOffered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Asegurar que la música de fondo suene en la partida
    AudioManager.playGameMusic();
    
    _adManager = AdManager();
    // Crear banner con listener que actualiza UI al cargar
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
    _adManager.loadInterstitial();
    _adManager.loadRewarded();

    if (widget.mode == 'continue') {
      _loadGame();
    } else {
      currentMode = widget.mode;
      currentDifficulty = widget.difficulty;
      currentGridSize = widget.gridSize;
      _newGame();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          elapsedTime++;
        });
        
        if (elapsedTime >= 600 && !_tenMinuteRewardOffered) {
          _tenMinuteRewardOffered = true;
          _showTenMinuteReward();
        }

        if (elapsedTime % 10 == 0) _saveGame(); // Auto-save every 10s
      }
    });
  }

  void _showTenMinuteReward() {
    setState(() => _isPaused = true);
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text("¡Llevas 10 minutos!", style: TextStyle(color: colors.primary)),
          content: Text("Tómate un respiro. Mira un video corto y recibe 1 pista de regalo para continuar tu partida.",
              style: TextStyle(color: colors.primary.withAlpha(180))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) setState(() => _isPaused = false);
              },
              child: const Text("Seguir jugando"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _adManager.showRewarded(
                  () { // onUserEarnedReward
                    if (mounted) {
                      setState(() {
                        helpCount += 1;
                        _isPaused = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("¡Has recibido 1 pista gratis!")),
                      );
                    }
                  },
                  onAdFailed: () {
                    if (mounted) {
                      setState(() => _isPaused = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Anuncio no disponible. Intenta de nuevo más tarde.")),
                      );
                    }
                  },
                );
              },
              child: const Text("Ver Anuncio"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadGame() async {
    setState(() => _isGenerating = true);
    final state = await GameStorage.loadGameState();
    if (!mounted) return;
    if (state != null) {
      setState(() {
        board = state.board;
        initial = state.initial;
        solution = state.solution;
        notes = state.notes;
        mistakes = state.mistakes;
        helpCount = state.helpCount;
        elapsedTime = state.elapsedTime;
        currentMode = state.mode;
        currentDifficulty = state.difficulty;
        currentGridSize = state.gridSize;
        _isGenerating = false;
      });
      _startTimer();
    } else {
      setState(() => _isGenerating = false);
      currentMode = 'reto';
      currentGridSize = 9;
      _newGame();
    }
  }

  Future<void> _newGame() async {
    setState(() => _isGenerating = true);

    // Genera el puzzle en un Isolate secundario para no bloquear la UI
    final GeneratedPuzzle puzzle;
    if (currentGridSize == 4) {
      puzzle = await SudokuEngine4x4.generateAsync();
    } else {
      puzzle = await SudokuEngine.generateAsync(currentDifficulty);
    }

    if (!mounted) return;
    setState(() {
      solution = puzzle.solution;
      initial = puzzle.puzzle;
      board = List.from(puzzle.puzzle);
      notes = {};
      mistakes = 0;
      selectedIndex = -1;
      elapsedTime = 0;
      undoStack.clear();
      _isPaused = false;
      _tenMinuteRewardOffered = false; // Permitir la recompensa de 10 min en la nueva partida
      _isGenerating = false;
    });
    _saveGame();
    _startTimer();
    if (currentMode == 'reto') {
      GameStorage.incrementRetoPlayed();
    }
    // Mostrar tutorial la primera vez que el usuario abre un juego
    await _showTutorialIfNeeded();
  }

  Future<void> _showTutorialIfNeeded() async {
    final seen = await GameStorage.hasTutorialSeen();
    if (!seen && mounted) {
      // Pausa el timer mientras dure el tutorial
      if (mounted) setState(() => _isPaused = true);
      await Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) => TutorialScreen(
            onFinished: () => Navigator.pop(context),
          ),
        ),
      );
      if (mounted) setState(() => _isPaused = false);
    }
  }

  void _saveGame() {
    if (board.isEmpty) return;
    GameStorage.saveGameState(GameState(
      board: board,
      initial: initial,
      solution: solution,
      notes: notes,
      mistakes: mistakes,
      helpCount: helpCount,
      elapsedTime: elapsedTime,
      mode: currentMode,
      difficulty: currentDifficulty,
      gridSize: currentGridSize,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _bannerAd?.dispose();
    // Solo guardar si el juego sigue activo (no terminado/perdido)
    if (!_gameFinished) _saveGame();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) setState(() => _isPaused = true);
      _saveGame();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _isPaused = false);
    }
  }

  void _pushUndo() {
    Map<int, List<int>> notesCopy = {};
    notes.forEach((key, value) {
      notesCopy[key] = List.from(value);
    });
    undoStack.add(GameStateSnapshot(List.from(board), notesCopy));
  }

  void _onUndo() {
    if (undoStack.isEmpty) return;
    final state = undoStack.removeLast();
    setState(() {
      board = state.board;
      notes = state.notes;
    });
    _saveGame();
  }

  void _onInput(int num) {
    if (selectedIndex == -1) return;
    if (initial[selectedIndex] != 0) return; // Fixed cell

    if (isPencilMode) {
      _pushUndo();
      
      setState(() {
        if (notes[selectedIndex] == null) notes[selectedIndex] = [];
        if (notes[selectedIndex]!.contains(num)) {
          notes[selectedIndex]!.remove(num);
        } else {
          notes[selectedIndex]!.add(num);
        }
      });
      // Las notas no son aciertos: sin sonido de éxito
    } else {
      if (board[selectedIndex] == num) return;
      _pushUndo();

      if (currentMode == 'reto') {
        if (solution[selectedIndex] == num) {
          _placeNumber(num);
        } else {
          _handleMistake();
        }
      } else {
        // Zen / Aprendiz: validamos conflictos, feedback suave, sin penalización.
        if (_hasConflict(selectedIndex, num)) {
          AudioManager.playError();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Ya existe ese número en la fila, columna o caja."),
                duration: Duration(milliseconds: 700),
              ),
            );
          }
          undoStack.removeLast();
        } else {
          _placeNumber(num);
        }
      }
    }
    _saveGame();
  }

  void _placeNumber(int num) {
    setState(() {
      board[selectedIndex] = num;
      notes.remove(selectedIndex);
      _cleanNotes(selectedIndex, num);
    });
    AudioManager.playClick();
    _checkWin();
  }

  void _handleMistake() {
    // Verificar ANTES de incrementar para evitar mostrar snackbar y dialog simultáneos
    final willLose = mistakes + 1 >= 3;
    setState(() => mistakes++);
    AudioManager.playError();
    if (willLose) {
      _showGameOverDialog();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Número incorrecto"), duration: Duration(milliseconds: 500)),
        );
      }
    }
  }

  void _cleanNotes(int idx, int num) {
    final gs = currentGridSize;
    final box = gs == 4 ? 2 : 3;
    int row = idx ~/ gs;
    int col = idx % gs;
    for (int i = 0; i < gs * gs; i++) {
      int r = i ~/ gs;
      int c = i % gs;
      if (r == row || c == col ||
          (r ~/ box == row ~/ box && c ~/ box == col ~/ box)) {
        notes[i]?.remove(num);
      }
    }
  }

  /// Verifica si colocar [num] en [idx] viola las reglas del tablero actual
  /// (fila, columna o caja), ignorando el propio valor de la celda.
  bool _hasConflict(int idx, int num) {
    final gs = currentGridSize;
    final box = gs == 4 ? 2 : 3;
    int row = idx ~/ gs;
    int col = idx % gs;
    for (int i = 0; i < gs * gs; i++) {
      if (i == idx) continue;
      if (board[i] != num) continue;
      int r = i ~/ gs;
      int c = i % gs;
      if (r == row || c == col ||
          (r ~/ box == row ~/ box && c ~/ box == col ~/ box)) {
        return true;
      }
    }
    return false;
  }

  void _useHelp() {
    if (helpCount > 0) {
      int target = -1;

      // Prioridad 1: celda seleccionada vacía o incorrecta sin conflicto
      if (selectedIndex != -1 &&
          initial[selectedIndex] == 0 &&
          board[selectedIndex] != solution[selectedIndex] &&
          !_hasConflict(selectedIndex, solution[selectedIndex])) {
        target = selectedIndex;
      }

      // Prioridad 2: cualquier celda vacía cuya solución no crea conflicto
      if (target == -1) {
        List<int> candidates = [];
        for (int i = 0; i < currentGridSize * currentGridSize; i++) {
          if (board[i] == 0 && !_hasConflict(i, solution[i])) {
            candidates.add(i);
          }
        }
        if (candidates.isNotEmpty) {
          target = candidates[Random().nextInt(candidates.length)];
        }
      }

      // Prioridad 3: celda incorrecta (no vacía) cuya solución no crea conflicto
      if (target == -1) {
        List<int> incorrect = [];
        for (int i = 0; i < currentGridSize * currentGridSize; i++) {
          if (initial[i] == 0 &&
              board[i] != solution[i] &&
              !_hasConflict(i, solution[i])) {
            incorrect.add(i);
          }
        }
        if (incorrect.isNotEmpty) {
          target = incorrect[Random().nextInt(incorrect.length)];
        }
      }

      if (target != -1) {
        _pushUndo();
        setState(() {
          board[target] = solution[target];
          helpCount--;
          selectedIndex = target;
          notes.remove(target);
          _cleanNotes(target, solution[target]);
        });
        AudioManager.playClick();
        _saveGame();
        _checkWin();
      }
    } else {
      _showRewardDialog();
    }
  }

  void _showRewardDialog() {
    setState(() => _isPaused = true);
    showDialog(
      context: context,
      barrierDismissible: false, // Evita que isPaused quede bloqueado
      builder: (ctx) => AlertDialog(
        title: const Text("¿Necesitas Ayuda?"),
        content: const Text("Mira un video para obtener 3 ayudas más."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) setState(() => _isPaused = false);
            },
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _adManager.showRewarded(
                () { // onUserEarnedReward
                  if (mounted) setState(() { helpCount += 3; _isPaused = false; });
                },
                onAdFailed: () {
                  if (mounted) {
                    setState(() => _isPaused = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Anuncio no disponible. Intenta de nuevo más tarde.")),
                    );
                  }
                },
              );
            },
            child: const Text("Ver Video"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkWin() async {
    if (board.contains(0)) return;

    // Validar que todos los valores coincidan con la solución (todos los modos)
    bool isWin = true;
    for (int i = 0; i < currentGridSize * currentGridSize; i++) {
      if (board[i] != solution[i]) {
        isWin = false;
        break;
      }
    }

      if (isWin) {
        _timer?.cancel();
        _gameFinished = true;
        GameStorage.clearGameState();
        if (currentMode == 'reto') GameStorage.incrementRetoWon(difficulty: currentDifficulty);
        AudioManager.playWin();

        // Guardar referencia al navigator antes del await para evitar context inválido
        final nav = Navigator.of(context);

        final unlockedIds = await GameStorage.getUnlockedQuotes();
        List<ZenQuote> lockedQuotes = zenQuotes.where((q) => !unlockedIds.contains(q.id)).toList();

        ZenQuote rewardQuote;
        bool isNew = false;
        if (lockedQuotes.isNotEmpty) {
          rewardQuote = lockedQuotes[Random().nextInt(lockedQuotes.length)];
          isNew = true;
          await GameStorage.unlockQuote(rewardQuote.id);
        } else {
          rewardQuote = zenQuotes[Random().nextInt(zenQuotes.length)];
        }

        if (!mounted) return;

        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (ctx) {
            final colors = Theme.of(ctx).colorScheme;
            return AlertDialog(
              title: Text(isNew ? "¡Nuevo Pergamino Desbloqueado!" : "¡Completado!"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Tiempo: ${_formatTime(elapsedTime)}", style: TextStyle(color: colors.primary)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(20),
                      border: Border.all(color: colors.primary.withAlpha(50)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "\"${rewardQuote.text}\"",
                          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: colors.primary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "- ${rewardQuote.author}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.secondary),
                          textAlign: TextAlign.right,
                        ),
                        if (rewardQuote.meaning != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            rewardQuote.meaning!,
                            style: TextStyle(fontSize: 12, color: colors.primary.withAlpha(160)),
                            textAlign: TextAlign.center,
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _adManager.showInterstitial(() {
                      if (nav.canPop()) nav.pop();
                    });
                  },
                  child: const Text("Volver al Menú"),
                ),
              ],
            );
          },
        );
      } else {
        if ((currentMode == 'zen' || currentMode == 'aprendiz') && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("El tablero está lleno pero hay errores.")),
          );
        }
      }
  }

  static const List<String> _motivationalMessages = [
    "Cada gran maestro empezó cometiendo errores. ¡Tú puedes!",
    "El sudoku es paciencia. Respira y vuelve a intentarlo.",
    "Los errores son el camino al aprendizaje. ¡Ánimo!",
    "Un tropiezo no es una caída. ¡Sigue adelante!",
    "La práctica hace al maestro. ¡Un intento más!",
    "¡Casi lo tenías! La próxima es la vencida.",
    "Los grandes jugadores no se rinden. ¡Tú tampoco!",
  ];

  void _showGameOverDialog() {
    _timer?.cancel();
    _gameFinished = true;
    GameStorage.clearGameState();
    AudioManager.playFail();
    final nav = Navigator.of(context);
    final msg = _motivationalMessages[
      DateTime.now().millisecondsSinceEpoch % _motivationalMessages.length
    ];
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text("Fin del Juego"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Has cometido 3 errores."),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  border: Border.all(color: colors.primary.withAlpha(50)),
                ),
                child: Text(
                  msg,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: colors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _adManager.showInterstitial(() {
                  if (nav.canPop()) nav.pop();
                });
              },
              child: const Text("Menú"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Resetear _gameFinished para que dispose() pueda guardar
                // la nueva partida si el usuario sale antes de terminarla
                _gameFinished = false;
                _newGame();
              },
              child: const Text("¡Reintentar!"),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ZenBackground(
      isGame: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: BackButton(
          color: colors.primary,
          onPressed: () {
            _saveGame();
            Navigator.pop(context);
          },
        ),
        // Errores / modo (izquierda del título)
        title: currentMode == 'reto'
            ? Text(
                "Errores: $mistakes/3",
                style: TextStyle(fontSize: 15, color: colors.primary),
              )
            : Text(
                currentMode == 'aprendiz' ? "Modo Aprendiz" : "Modo Zen",
                style: TextStyle(fontSize: 15, color: colors.primary),
              ),
        // Timer de Reto + contador de Ayudas (derecha)
        actions: [
          if (currentMode == 'reto')
            GestureDetector(
              onTap: _togglePause,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  // Sin borderRadius — consistente con el resto de la UI
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(elapsedTime),
                      style: TextStyle(fontSize: 14, color: colors.primary),
                    ),
                  ],
                ),
              ),
            ),
          // Contador de ayudas
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colors.primary),
                const SizedBox(width: 2),
                Text(
                  "$helpCount",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: _isBannerLoaded && _bannerAd != null
          ? SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
      body: _isGenerating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    "Preparando el tablero...",
                    style: TextStyle(fontSize: 16, color: colors.primary, letterSpacing: 1),
                  ),
                ],
              ),
            )
          : _isPaused
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle_outline, size: 80, color: colors.primary.withAlpha(128)),
                  const SizedBox(height: 20),
                  Text("PAUSADO", style: TextStyle(fontSize: 24, color: colors.primary, letterSpacing: 4)),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: _togglePause,
                    child: const Text("Continuar"),
                  )
                ],
              ),
            )
          : Column(
              children: [
                // ── Barra de progreso (arriba del tablero) ──────────────
                Builder(
                  builder: (context) {
                    final totalCells = currentGridSize * currentGridSize;
                    final filledCount = board.where((val) => val != 0).length;
                    final progressPercent = filledCount / totalCells;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colors.primary.withAlpha(20),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${(progressPercent * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.secondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progressPercent,
                              backgroundColor: colors.primary.withAlpha(15),
                              valueColor: AlwaysStoppedAnimation<Color>(colors.secondary),
                              minHeight: 4,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "$filledCount / $totalCells",
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.primary.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // ── Tablero y Teclado agrupados en el centro ───────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (currentGridSize == 4)
                        MiniBoard(
                          board: board,
                          initial: initial,
                          notes: notes,
                          selectedIndex: selectedIndex,
                          onCellTap: (index) {
                            setState(() => selectedIndex = index);
                          },
                        )
                      else
                        SudokuBoard(
                          board: board,
                          initial: initial,
                          notes: notes,
                          selectedIndex: selectedIndex,
                          onCellTap: (index) {
                            setState(() => selectedIndex = index);
                          },
                        ),
                      const SizedBox(height: 12),
                      if (currentGridSize == 4)
                        MiniNumPad(
                          isPencilMode: isPencilMode,
                          onTogglePencil: () => setState(() => isPencilMode = !isPencilMode),
                          onNumberInput: _onInput,
                          onErase: () {
                            if (selectedIndex != -1 && initial[selectedIndex] == 0) {
                              if (board[selectedIndex] != 0 ||
                                  (notes[selectedIndex] != null &&
                                      notes[selectedIndex]!.isNotEmpty)) {
                                _pushUndo();
                                setState(() {
                                  board[selectedIndex] = 0;
                                  notes.remove(selectedIndex);
                                });
                                _saveGame();
                              }
                            }
                          },
                          onHelp: _useHelp,
                          onUndo: _onUndo,
                        )
                      else
                        NumPad(
                          isPencilMode: isPencilMode,
                          onTogglePencil: () => setState(() => isPencilMode = !isPencilMode),
                          onNumberInput: _onInput,
                          onErase: () {
                            if (selectedIndex != -1 && initial[selectedIndex] == 0) {
                              if (board[selectedIndex] != 0 ||
                                  (notes[selectedIndex] != null &&
                                      notes[selectedIndex]!.isNotEmpty)) {
                                _pushUndo();
                                setState(() {
                                  board[selectedIndex] = 0;
                                  notes.remove(selectedIndex);
                                });
                                _saveGame();
                              }
                            }
                          },
                          onHelp: _useHelp,
                          onUndo: _onUndo,
                        ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
