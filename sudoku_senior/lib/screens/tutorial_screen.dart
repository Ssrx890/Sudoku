import 'package:flutter/material.dart';
import '../managers/game_storage.dart';

/// Tutorial de bienvenida que se muestra solo la primera vez que el usuario
/// abre la app. Usa un PageView con pasos visuales, no bloquea el UI.
class TutorialScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const TutorialScreen({super.key, required this.onFinished});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_TutorialStep> _steps = const [
    _TutorialStep(
      emoji: "数",
      title: "Bienvenido a Sudoku Zen",
      body:
          "Rellena el tablero de 9×9 para que cada fila, columna y caja 3×3 contenga los números del 1 al 9 sin repetirse.",
    ),
    _TutorialStep(
      emoji: "✏️",
      title: "Modo Notas",
      body:
          "Activa el lápiz para escribir notas pequeñas en una celda. Úsalas para recordar qué números son candidatos mientras deduces la solución.",
    ),
    _TutorialStep(
      emoji: "✨",
      title: "Ayuda",
      body:
          "Tienes 3 ayudas disponibles. Selecciona una celda vacía y pulsa Ayuda para revelar su número correcto. ¡Úsalas con sabiduría!",
    ),
    _TutorialStep(
      emoji: "🌸",
      title: "Modo Zen vs Reto",
      body:
          "En Modo Zen no hay tiempo ni penalizaciones: juega a tu ritmo.\nEn Modo Reto el reloj corre y tienes 3 vidas. ¡Acumula victorias Maestro para desbloquear el nivel Diabólico!",
    ),
    _TutorialStep(
      emoji: "⛩",
      title: "¡Listo!",
      body:
          "Tu progreso se guarda automáticamente. Si cierras la app, podrás continuar tu partida desde el menú principal.",
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await GameStorage.setTutorialSeen();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de página (dots)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? colors.primary
                          : colors.primary.withAlpha(60),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Contenido del paso
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final s = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Emoji/símbolo central
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.primary, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              s.emoji,
                              style: TextStyle(
                                fontSize: s.emoji.length == 1 && s.emoji.runes.first > 127
                                    ? 48
                                    : 40,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Título
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Cuerpo
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.primary.withAlpha(180),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Botones de navegación
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      "Saltar",
                      style: TextStyle(color: colors.primary.withAlpha(140)),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.surface,
                      minimumSize: const Size(120, 48),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: _next,
                    child: Text(
                      _currentPage == _steps.length - 1 ? "¡Empezar!" : "Siguiente",
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
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

class _TutorialStep {
  final String emoji;
  final String title;
  final String body;
  const _TutorialStep({
    required this.emoji,
    required this.title,
    required this.body,
  });
}
