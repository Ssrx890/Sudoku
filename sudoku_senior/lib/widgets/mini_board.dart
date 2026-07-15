import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tablero 4×4 para el Modo Aprendiz.
/// Reutiliza los mismos colores y patrones visuales que [SudokuBoard] pero
/// adaptado a una grilla de 4 columnas con cajas 2×2.
class MiniBoard extends StatelessWidget {
  final List<int> board;
  final List<int> initial;
  final Map<int, List<int>> notes;
  final int selectedIndex;
  final Function(int) onCellTap;

  const MiniBoard({
    super.key,
    required this.board,
    required this.initial,
    required this.notes,
    required this.selectedIndex,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final myTheme = myThemes.firstWhere(
      (t) => t.primary.toARGB32() == colors.primary.toARGB32(),
      orElse: () => myThemes[0],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: myTheme.surface,
        border: Border.all(color: colors.primary.withAlpha(128), width: 1.2),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.primary, width: 2.8),
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 16,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
            itemBuilder: (context, index) {
              int row = index ~/ 4;
              int col = index % 4;

              // Borde derecho grueso entre cajas 2×2
              BorderSide right = (col % 2 == 1 && col != 3)
                  ? BorderSide(color: colors.primary, width: 2)
                  : BorderSide(color: colors.primary.withAlpha(51), width: 0.5);

              // Borde inferior grueso entre cajas 2×2
              BorderSide bottom = (row % 2 == 1 && row != 3)
                  ? BorderSide(color: colors.primary, width: 2)
                  : BorderSide(color: colors.primary.withAlpha(51), width: 0.5);

              bool isSelected = index == selectedIndex;
              bool isRelated = false;
              bool isSameNumber = false;

              if (selectedIndex != -1) {
                int r2 = selectedIndex ~/ 4;
                int c2 = selectedIndex % 4;
                // Relacionadas: misma fila, columna o caja 2×2
                if (row == r2 ||
                    col == c2 ||
                    (row ~/ 2 == r2 ~/ 2 && col ~/ 2 == c2 ~/ 2)) {
                  isRelated = true;
                }
                if (board[selectedIndex] != 0 &&
                    board[index] == board[selectedIndex]) {
                  isSameNumber = true;
                }
              }

              Color cellBg = myTheme.surface;
              if (isSelected) {
                cellBg = myTheme.highlight;
              } else if (isSameNumber) {
                cellBg = myTheme.highlight.withAlpha(153);
              } else if (isRelated) {
                cellBg = myTheme.highlight.withAlpha(51);
              }

              return GestureDetector(
                onTap: () => onCellTap(index),
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
                            '${board[index]}',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: initial[index] != 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: initial[index] != 0
                                  ? colors.primary
                                  : colors.secondary,
                            ),
                          ),
                        ),
                      // Notas: hasta 4 mini-dígitos
                      if (board[index] == 0 && notes[index] != null)
                        Padding(
                          padding: const EdgeInsets.all(2),
                          child: GridView.count(
                            crossAxisCount: 2,
                            physics: const NeverScrollableScrollPhysics(),
                            children: List.generate(4, (n) {
                              final num = n + 1;
                              final hasNote =
                                  notes[index]!.contains(num);
                              return Center(
                                child: Text(
                                  hasNote ? '$num' : '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        colors.primary.withAlpha(160),
                                  ),
                                ),
                              );
                            }),
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
    );
  }
}
