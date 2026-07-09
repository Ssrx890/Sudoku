import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'managers/audio_manager.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SudokuApp());
}

class SudokuApp extends StatefulWidget {
  const SudokuApp({super.key});
  @override
  State<SudokuApp> createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> with WidgetsBindingObserver {
  int _themeIndex = 0;
  bool _appReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Initial configuration
    try {
      await AudioManager.init();
      AudioManager.playGameMusic();
    } catch (e) {
      debugPrint("Audio init error: $e");
    }

    // 2. Request Consent & Initialize Ads
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
                  _initializeAdsAndProceed();
                });
              } else {
                _initializeAdsAndProceed();
              }
            },
            (FormError formError) {
              _initializeAdsAndProceed();
            },
          );
        } else {
          _initializeAdsAndProceed();
        }
      },
      (FormError formError) {
        _initializeAdsAndProceed();
      },
    );
  }

  Future<void> _initializeAdsAndProceed() async {
    MobileAds.instance.initialize();
    if (mounted) {
      setState(() => _appReady = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AudioManager.stopBGM();
    } else if (state == AppLifecycleState.resumed && AudioManager.isMusicOn) {
      AudioManager.playGameMusic();
    }
  }

  void changeTheme() =>
      setState(() => _themeIndex = (_themeIndex + 1) % myThemes.length);

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
          brightness: t.brightness,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      home: !_appReady
          ? const _SplashWidget()
          : HomeScreen(onThemeChanged: changeTheme),
    );
  }
}

/// Pantalla de splash mínima mientras se inicializa la app
class _SplashWidget extends StatelessWidget {
  const _SplashWidget();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Text(
          "数",
          style: TextStyle(
            fontSize: 72,
            color: colors.primary,
            fontFamily: 'Serif',
          ),
        ),
      ),
    );
  }
}
