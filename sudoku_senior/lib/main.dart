import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:audioplayers/audioplayers.dart';

// ==========================================
// 1. GESTORES (AUDIO, IAP, ADS)
// ==========================================

class AudioManager {
  static final AudioPlayer _bgmPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  static bool _musicOn = true;
  static bool _sfxOn = true;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicOn = prefs.getBool('music_on') ?? true;
      _sfxOn = prefs.getBool('sfx_on') ?? true;
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.25); // Volumen Zen
    } catch (e) {
      debugPrint("AudioManager init error: $e");
    }
  }

  static void playGameMusic() async {
    try {
      if (_musicOn && _bgmPlayer.state != PlayerState.playing) {
        await _bgmPlayer.play(AssetSource('audio/bg_music.mp3'));
      }
    } catch (e) {
      debugPrint("AudioManager play error: $e");
    }
  }

  static void stopBGM() async {
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

  static void playClick() {
    if (_sfxOn) _sfxPlayer.play(AssetSource('audio/click.mp3'), volume: 0.6);
  }

  static void playWin() {
    if (_sfxOn) _sfxPlayer.play(AssetSource('audio/win.mp3'), volume: 0.8);
  }

  static void playError() {
    if (_sfxOn) _sfxPlayer.play(AssetSource('audio/click.mp3'), volume: 1.0);
  } // O un sonido de error si tienes

  static void toggleSFX(bool value) async {
    _sfxOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sfx_on', value);
  }

  static bool get isMusicOn => _musicOn;
  static bool get isSfxOn => _sfxOn;
}

class IAPManager {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static bool available = true;
  static const String _productId = 'remove_ads';
  static Future<void> initialize() async {
    try {
      available = await _iap.isAvailable();
    } catch (e) {
      available = false;
      debugPrint("IAPManager init error: $e");
    }
  }

  static void buyRemoveAds() {
    if (available) {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: ProductDetails(
          id: _productId,
          title: 'No Ads',
          description: '',
          price: '',
          rawPrice: 0,
          currencyCode: 'USD',
        ),
      );
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }
}

class AdManager {
  // IDs REALES o DE PRUEBA
  static final String _bannerId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';
  static final String _interstitialId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';
  static final String _rewardedId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialReady = false;
  bool _isRewardedReady = false;

  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
        },
        onAdFailedToLoad: (err) {
          _isInterstitialReady = false;
        },
      ),
    );
  }

  void showInterstitial(bool isPro, Function onAdClosed) {
    if (isPro) {
      onAdClosed();
      return;
    }
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitial();
          onAdClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          loadInterstitial();
          onAdClosed();
        },
      );
      _interstitialAd!.show();
      _isInterstitialReady = false;
    } else {
      onAdClosed();
      loadInterstitial();
    }
  }

  void loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedReady = true;
        },
        onAdFailedToLoad: (err) {
          _isRewardedReady = false;
        },
      ),
    );
  }

  void showRewarded(Function onUserEarnedReward) {
    if (_isRewardedReady && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadRewarded();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          loadRewarded();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onUserEarnedReward();
        },
      );
      _isRewardedReady = false;
    } else {
      loadRewarded();
    }
  }

  static BannerAd createBanner() {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }
}

// ==========================================
// 2. MOTOR DE SUDOKU (BACKTRACKING)
// ==========================================

class SudokuEngine {
  List<int> solution = List.filled(81, 0); // La respuesta correcta
  List<int> puzzle = List.filled(81, 0); // Lo que ve el usuario

  void generate(int difficulty) {
    // 1. Limpiar
    solution = List.filled(81, 0);

    // 2. Generar un tablero completo válido
    _fillDiagonal();
    _fillRemaining(0, 3);

    // 3. Crear el puzzle borrando números según dificultad
    // 1: Fácil (Dejar ~40 pistas)
    // 2: Medio (Dejar ~32 pistas)
    // 3: Difícil (Dejar ~24 pistas)
    int holes = difficulty == 1 ? 40 : (difficulty == 2 ? 49 : 57);

    puzzle = List.from(solution);
    _removeDigits(holes);
  }

  void _fillDiagonal() {
    for (int i = 0; i < 9; i = i + 3) {
      _fillBox(i, i);
    }
  }

  void _fillBox(int row, int col) {
    int num;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        do {
          num = Random().nextInt(9) + 1;
        } while (!_isSafeInBox(row, col, num));
        solution[(row + i) * 9 + (col + j)] = num;
      }
    }
  }

  bool _isSafeInBox(int rowStart, int colStart, int num) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (solution[(rowStart + i) * 9 + (colStart + j)] == num) return false;
      }
    }
    return true;
  }

  bool _checkIfSafe(int i, int j, int num) {
    return (_unUsedInRow(i, num) &&
        _unUsedInCol(j, num) &&
        _isSafeInBox(i - i % 3, j - j % 3, num));
  }

  bool _unUsedInRow(int i, int num) {
    for (int j = 0; j < 9; j++) {
      if (solution[i * 9 + j] == num) return false;
    }
    return true;
  }

  bool _unUsedInCol(int j, int num) {
    for (int i = 0; i < 9; i++) {
      if (solution[i * 9 + j] == num) return false;
    }
    return true;
  }

  bool _fillRemaining(int i, int j) {
    if (j >= 9 && i < 8) {
      i = i + 1;
      j = 0;
    }
    if (i >= 9 && j >= 9) return true;
    if (i < 3) {
      if (j < 3) j = 3;
    } else if (i < 6) {
      if (j == (i ~/ 3) * 3) j = j + 3;
    } else {
      if (j == 6) {
        i = i + 1;
        j = 0;
        if (i >= 9) return true;
      }
    }

    for (int num = 1; num <= 9; num++) {
      if (_checkIfSafe(i, j, num)) {
        solution[i * 9 + j] = num;
        if (_fillRemaining(i, j + 1)) return true;
        solution[i * 9 + j] = 0;
      }
    }
    return false;
  }

  void _removeDigits(int count) {
    while (count != 0) {
      int cellId = Random().nextInt(81);
      if (puzzle[cellId] != 0) {
        count--;
        puzzle[cellId] = 0;
      }
    }
  }
}

// ==========================================
// 3. TEMAS ZEN (ESTÉTICA JAPONESA)
// ==========================================

class AppTheme {
  final String name;
  final Color background; // Papel
  final Color primary; // Tinta
  final Color surface; // Bloques
  final Color accent; // Detalles (Rojo Sello)
  final Color highlight; // Selección suave
  final Brightness brightness;

  AppTheme({
    required this.name,
    required this.background,
    required this.primary,
    required this.surface,
    required this.accent,
    required this.highlight,
    required this.brightness,
  });
}

final List<AppTheme> myThemes = [
  AppTheme(
    name: "Tinta Zen",
    background: const Color(0xFFF9F7F2), // Blanco roto (Papel washi)
    primary: const Color(0xFF212121), // Tinta negra suave
    surface: const Color(0xFFFFFFFF),
    accent: const Color(0xFFB71C1C), // Rojo Japón
    highlight: const Color(0xFFE3F2FD),
    brightness: Brightness.light,
  ),
  AppTheme(
    name: "Noche Kyoto",
    background: const Color(0xFF181818),
    primary: const Color(0xFFE0E0E0),
    surface: const Color(0xFF262626),
    accent: const Color(0xFF81C784), // Verde bambú suave
    highlight: const Color(0xFF333333),
    brightness: Brightness.dark,
  ),
];

// ==========================================
// 4. MAIN & STATE
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ConsentRequestParameters params = ConsentRequestParameters();
  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
    () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        ConsentForm.loadConsentForm(
          (ConsentForm consentForm) async {
            var status = await ConsentInformation.instance.getConsentStatus();
            if (status == ConsentStatus.required) {
              consentForm.show((FormError? formError) {
                _initializeAdsAndApp();
              });
            } else {
              _initializeAdsAndApp();
            }
          },
          (FormError formError) {
            _initializeAdsAndApp();
          },
        );
      } else {
        _initializeAdsAndApp();
      }
    },
    (FormError formError) {
      _initializeAdsAndApp();
    },
  );
}

Future<void> _initializeAdsAndApp() async {
  MobileAds.instance.initialize();
  await AudioManager.init();
  runApp(const SudokuApp());
}

class SudokuApp extends StatefulWidget {
  const SudokuApp({super.key});
  static _SudokuAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_SudokuAppState>();
  @override
  State<SudokuApp> createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> with WidgetsBindingObserver {
  int _themeIndex = 0;
  bool _isPro = false;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _initIAP();
      AudioManager.playGameMusic();
    } catch (e) {
      debugPrint("Init error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AudioManager.stopBGM();
    } else if (state == AppLifecycleState.resumed && AudioManager.isMusicOn)
      AudioManager.playGameMusic();
  }

  void _initIAP() async {
    await IAPManager.initialize();
    _subscription = InAppPurchase.instance.purchaseStream.listen((list) {
      for (var p in list) {
        if (p.status == PurchaseStatus.purchased) setState(() => _isPro = true);
      }
    });
  }

  void changeTheme() =>
      setState(() => _themeIndex = (_themeIndex + 1) % myThemes.length);
  void setPro(bool v) => setState(() => _isPro = v);
  bool get isPro => _isPro;

  @override
  Widget build(BuildContext context) {
    final t = myThemes[_themeIndex];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sudoku Zen',
      theme: ThemeData(
        brightness: t.brightness,
        scaffoldBackgroundColor: t.background,
        primaryColor: t.primary,
        cardColor: t.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: t.primary,
          primary: t.primary,
          surface: t.surface,
          onSurface: t.primary,
          secondary: t.accent,
          background: t.background,
          brightness: t.brightness,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// 5. HOME SCREEN (Minimalista)
// ==========================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPro = SudokuApp.of(context)?.isPro ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => SudokuApp.of(context)?.changeTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primary, width: 2),
                ),
                child: Text(
                  "数",
                  style: TextStyle(
                    fontSize: 60,
                    color: colors.primary,
                    fontFamily: 'Serif',
                  ),
                ), // Kanji de "Número"
              ),
              const SizedBox(height: 10),
              Text(
                "S U D O K U",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 60),

              // SELECTORES DE DIFICULTAD
              _buildLevelBtn(context, "PRINCIPIANTE", 1),
              _buildLevelBtn(context, "NORMAL", 2),
              _buildLevelBtn(context, "MAESTRO", 3),

              if (!isPro)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: TextButton(
                    onPressed: () => SudokuApp.of(context)?.setPro(true),
                    child: const Text(
                      "DEV: Simular Premium",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBtn(BuildContext context, String text, int difficulty) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: SizedBox(
        width: 240,
        height: 60,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colors.primary, width: 1),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ), // Cuadrado estilo japonés
          ),
          onPressed: () {
            AudioManager.playClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameScreen(difficulty: difficulty),
              ),
            );
          },
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.primary,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 6. GAME SCREEN (TABLERO JAPONÉS)
// ==========================================

class GameScreen extends StatefulWidget {
  final int difficulty;
  const GameScreen({super.key, required this.difficulty});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late SudokuEngine engine;
  List<int> board = []; // Tablero actual
  List<int> initial = []; // Celdas fijas (Tinta negra)
  List<int> solution = []; // Solución (Para ayuda infalible)
  Map<int, List<int>> notes = {}; // Notas (lápiz)

  int selectedIndex = -1;
  bool isPencilMode = false;
  int mistakes = 0;
  int helpCount = 3; // "Pistas" ahora es "Ayuda"

  late AdManager _adManager;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool isPro = false;

  @override
  void initState() {
    super.initState();
    isPro = SudokuApp.of(context)?.isPro ?? false;
    _adManager = AdManager();
    if (!isPro) {
      _bannerAd = AdManager.createBanner();
      _bannerAd?.load().then((_) => setState(() => _isBannerLoaded = true));
      _adManager.loadInterstitial();
    }
    _adManager.loadRewarded();

    _newGame();
  }

  void _newGame() {
    engine = SudokuEngine();
    engine.generate(widget.difficulty);
    setState(() {
      solution = List.from(engine.solution);
      initial = List.from(engine.puzzle);
      board = List.from(engine.puzzle);
      notes = {};
      mistakes = 0;
      selectedIndex = -1;
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onInput(int num) {
    if (selectedIndex == -1) return;
    if (initial[selectedIndex] != 0) return; // No editar fijos

    if (isPencilMode) {
      setState(() {
        if (notes[selectedIndex] == null) notes[selectedIndex] = [];
        if (notes[selectedIndex]!.contains(num)) {
          notes[selectedIndex]!.remove(num);
        } else {
          notes[selectedIndex]!.add(num);
        }
      });
      AudioManager.playClick();
    } else {
      // Validar input inmediatamente contra la solución
      if (board[selectedIndex] == num) return;

      if (solution[selectedIndex] == num) {
        // CORRECTO
        setState(() {
          board[selectedIndex] = num;
          notes.remove(selectedIndex);
          _cleanNotes(selectedIndex, num);
        });
        AudioManager.playClick();
        _checkWin();
      } else {
        // ERROR
        setState(() => mistakes++);
        AudioManager.playError();

        if (mistakes >= 3) {
          _showGameOverDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Número incorrecto"),
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      }
    }
  }

  void _cleanNotes(int idx, int num) {
    int row = idx ~/ 9;
    int col = idx % 9;
    // Limpiar fila, columna y caja
    for (int i = 0; i < 81; i++) {
      int r = i ~/ 9;
      int c = i % 9;
      if (r == row || c == col || (r ~/ 3 == row ~/ 3 && c ~/ 3 == col ~/ 3)) {
        notes[i]?.remove(num);
      }
    }
  }

  // --- AYUDA INFALIBLE ---
  void _useHelp() {
    if (helpCount > 0) {
      // Si hay celda seleccionada vacía, revelar esa. Si no, una al azar.
      int target = -1;

      if (selectedIndex != -1 && board[selectedIndex] == 0) {
        target = selectedIndex;
      } else {
        List<int> empty = [];
        for (int i = 0; i < 81; i++) {
          if (board[i] == 0) empty.add(i);
        }
        if (empty.isNotEmpty) target = empty[Random().nextInt(empty.length)];
      }

      if (target != -1) {
        setState(() {
          board[target] = solution[target]; // Revelar solución real
          helpCount--;
          selectedIndex = target;
          notes.remove(target);
          _cleanNotes(target, solution[target]);
        });
        AudioManager.playClick(); // Sonido suave
        _checkWin();
      }
    } else {
      _showRewardDialog();
    }
  }

  void _showRewardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Necesitas Ayuda?"),
        content: const Text("Mira un video para obtener 3 ayudas más."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _adManager.showRewarded(() {
                setState(() => helpCount += 3);
              });
            },
            child: const Text("Ver Video"),
          ),
        ],
      ),
    );
  }

  void _checkWin() {
    if (!board.contains(0)) {
      AudioManager.playWin();
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¡Completado!"),
          content: const Text("Tu mente está en calma y afilada."),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _adManager.showInterstitial(isPro, () {
                  Navigator.pop(context);
                });
              },
              child: const Text("Volver al Menú"),
            ),
          ],
        ),
      );
    }
  }

  void _showGameOverDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Fin del Juego"),
        content: const Text("Has cometido 3 errores. ¡Inténtalo de nuevo!"),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo
              _adManager.showInterstitial(isPro, () {
                Navigator.pop(context); // Volver al menú principal
              });
            },
            child: const Text("Volver al Menú"),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo
              _newGame(); // Reiniciar nivel
            },
            child: const Text("Reintentar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Encontrar el tema actual para obtener el color 'highlight' y 'surface' personalizados
    final myTheme = myThemes.firstWhere((t) => t.primary == colors.primary);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: colors.primary),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Errores: $mistakes/3  ",
              style: TextStyle(fontSize: 16, color: colors.primary),
            ),
            const Spacer(),
            const Icon(Icons.help_outline, size: 20), // Icono Ayuda
            Text(
              " $helpCount",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: (!isPro && _isBannerLoaded)
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      body: Column(
        children: [
          // TABLERO ZEN
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.primary, width: 3),
                  color: myTheme.surface,
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 81,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 9,
                        ),
                    itemBuilder: (context, index) {
                      int row = index ~/ 9;
                      int col = index % 9;

                      // Bordes gruesos para cuadrantes 3x3
                      BorderSide right = (col % 3 == 2 && col != 8)
                          ? BorderSide(color: colors.primary, width: 2)
                          : BorderSide(
                              color: colors.primary.withOpacity(0.2),
                              width: 0.5,
                            );
                      BorderSide bottom = (row % 3 == 2 && row != 8)
                          ? BorderSide(color: colors.primary, width: 2)
                          : BorderSide(
                              color: colors.primary.withOpacity(0.2),
                              width: 0.5,
                            );

                      // Estado Visual
                      bool isSelected = index == selectedIndex;
                      bool isRelated = false;
                      bool isSameNumber = false;
                      if (selectedIndex != -1) {
                        int r2 = selectedIndex ~/ 9;
                        int c2 = selectedIndex % 9;
                        // Iluminar fila, columna y caja
                        if (row == r2 ||
                            col == c2 ||
                            (row ~/ 3 == r2 ~/ 3 && col ~/ 3 == c2 ~/ 3)) {
                          isRelated = true;
                        }
                        // Iluminar números iguales
                        if (board[selectedIndex] != 0 &&
                            board[index] == board[selectedIndex]) {
                          isSameNumber = true;
                        }
                      }

                      Color cellBg = myTheme.surface;
                      if (isSelected) {
                        cellBg = myTheme.highlight; // Selección directa
                      } else if (isSameNumber)
                        cellBg = myTheme.highlight.withOpacity(
                          0.6,
                        ); // Mismo número
                      else if (isRelated)
                        cellBg = myTheme.highlight.withOpacity(
                          0.2,
                        ); // Fila/Columna

                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedIndex = index);
                          AudioManager.playClick();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: cellBg,
                            border: Border(right: right, bottom: bottom),
                          ),
                          child: Stack(
                            children: [
                              if (board[index] != 0)
                                Center(
                                  child: Text(
                                    "${board[index]}",
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: initial[index] != 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      // Tinta (Negro/Gris) vs Azul (Usuario)
                                      color: initial[index] != 0
                                          ? colors.primary
                                          : colors.secondary,
                                    ),
                                  ),
                                ),

                              if (board[index] == 0 && notes[index] != null)
                                Padding(
                                  padding: const EdgeInsets.all(1),
                                  child: Wrap(
                                    children: notes[index]!
                                        .map(
                                          (n) => SizedBox(
                                            width: 10,
                                            height: 10,
                                            child: Text(
                                              "$n",
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: colors.primary
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // TECLADO Y HERRAMIENTAS
          Container(
            padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
            child: Column(
              children: [
                // Herramientas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _toolBtn(Icons.refresh, "Reiniciar", () {
                      _newGame();
                    }),
                    _toolBtn(
                      Icons.edit,
                      "Notas",
                      () => setState(() => isPencilMode = !isPencilMode),
                      isActive: isPencilMode,
                    ),
                    _toolBtn(Icons.delete_outline, "Borrar", () {
                      if (selectedIndex != -1 && initial[selectedIndex] == 0) {
                        setState(() {
                          board[selectedIndex] = 0;
                          notes[selectedIndex] = [];
                        });
                      }
                    }),
                    _toolBtn(
                      Icons.auto_awesome,
                      "Ayuda",
                      _useHelp,
                    ), // Nuevo icono y nombre
                  ],
                ),
                const SizedBox(height: 15),
                // Números
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(9, (i) => _numBtn(i + 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? colors.secondary : Colors.transparent,
              borderRadius: BorderRadius.circular(8), // Un poco más cuadrado
              border: Border.all(
                color: isActive
                    ? colors.secondary
                    : colors.primary.withOpacity(0.3),
              ),
            ),
            child: Icon(icon, color: isActive ? Colors.white : colors.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: colors.primary)),
        ],
      ),
    );
  }

  Widget _numBtn(int num) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: SizedBox(
          height: 55,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(
                color: colors.primary.withOpacity(0.5),
                width: 1,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ), // BOTONES CUADRADOS ZEN
            ),
            onPressed: () => _onInput(num),
            child: Text(
              "$num",
              style: TextStyle(
                fontSize: 24,
                color: colors.primary,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
