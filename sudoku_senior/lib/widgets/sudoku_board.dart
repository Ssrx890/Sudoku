import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SudokuBoard extends StatelessWidget {
  final List<int> board;
  final List<int> initial;
  final Map<int, List<int>> notes;
  final int selectedIndex;
  final Function(int) onCellTap;

  const SudokuBoard({
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(3), // Efecto de doble borde tradicional japonés
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
            itemCount: 81,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
            ),
            itemBuilder: (context, index) {
              int row = index ~/ 9;
              int col = index % 9;

              BorderSide right = (col % 3 == 2 && col != 8)
                  ? BorderSide(color: colors.primary, width: 2)
                  : BorderSide(color: colors.primary.withAlpha(51), width: 0.5);
              BorderSide bottom = (row % 3 == 2 && row != 8)
                  ? BorderSide(color: colors.primary, width: 2)
                  : BorderSide(color: colors.primary.withAlpha(51), width: 0.5);

              bool isSelected = index == selectedIndex;
              bool isRelated = false;
              bool isSameNumber = false;
              
              if (selectedIndex != -1) {
                int r2 = selectedIndex ~/ 9;
                int c2 = selectedIndex % 9;
                if (row == r2 || col == c2 || (row ~/ 3 == r2 ~/ 3 && col ~/ 3 == c2 ~/ 3)) {
                  isRelated = true;
                }
                if (board[selectedIndex] != 0 && board[index] == board[selectedIndex]) {
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
                            "${board[index]}",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: initial[index] != 0 ? FontWeight.bold : FontWeight.normal,
                              color: initial[index] != 0 ? colors.primary : colors.secondary,
                            ),
                          ),
                        ),
                      if (board[index] == 0 && notes[index] != null)
                        Padding(
                          padding: const EdgeInsets.all(1),
                          child: Wrap(
                            children: (List<int>.from(notes[index]!)..sort()).map((n) => SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: Text(
                                    "$n",
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: colors.primary.withAlpha(153),
                                    ),
                                  ),
                                )).toList(),
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
