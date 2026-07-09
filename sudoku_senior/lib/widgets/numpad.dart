import 'package:flutter/material.dart';

class NumPad extends StatelessWidget {
  final bool isPencilMode;
  final Function() onTogglePencil;
  final Function(int) onNumberInput;
  final Function() onErase;
  final Function() onHelp;
  final Function() onUndo;

  const NumPad({
    super.key,
    required this.isPencilMode,
    required this.onTogglePencil,
    required this.onNumberInput,
    required this.onErase,
    required this.onHelp,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final numBtnSize = (screenWidth / 9).clamp(36.0, 56.0);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        left: 8,
        right: 8,
        top: 4,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.primary.withAlpha(30), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila de herramientas — estilo cuadriculado
          IntrinsicHeight(
            child: Row(
              children: [
                _toolBtn(context, Icons.undo_rounded, "Deshacer", onUndo),
                _vDivider(colors),
                _toolBtn(context, Icons.edit_outlined, "Notas", onTogglePencil,
                    isActive: isPencilMode),
                _vDivider(colors),
                _toolBtn(context, Icons.backspace_outlined, "Borrar", onErase),
                _vDivider(colors),
                _toolBtn(context, Icons.auto_awesome, "Ayuda", onHelp),
              ],
            ),
          ),
          // Separador horizontal tipo cuadrícula
          Container(
            height: 1,
            color: colors.primary.withAlpha(25),
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          // Fila de números — sin bordes redondeados
          Row(
            children: List.generate(
              9,
              (i) => _numBtn(context, i + 1, numBtnSize),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _vDivider(ColorScheme colors) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.primary.withAlpha(25),
    );
  }

  Widget _toolBtn(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? colors.secondary.withAlpha(220)
                      : colors.primary.withAlpha(12),
                  border: Border.all(
                    color: isActive
                        ? colors.secondary
                        : colors.primary.withAlpha(35),
                    width: 1,
                  ),
                  // Sin border radius — estilo cuadriculado
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isActive ? Colors.white : colors.primary.withAlpha(210),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? colors.secondary
                      : colors.primary.withAlpha(180),
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numBtn(BuildContext context, int num, double size) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => onNumberInput(num),
        child: Container(
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(10),
            border: Border.all(color: colors.primary.withAlpha(35), width: 1),
            // Sin borderRadius — cuadriculado
          ),
          child: Center(
            child: Text(
              "$num",
              style: TextStyle(
                fontSize: 22,
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
