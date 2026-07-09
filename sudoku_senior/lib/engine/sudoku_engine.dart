import 'dart:math';
import 'dart:isolate';

// Datos necesarios para el Isolate (deben ser primitivos o clases simples)
class _GenerateRequest {
  final int difficulty;
  final SendPort sendPort;
  _GenerateRequest(this.difficulty, this.sendPort);
}

class GeneratedPuzzle {
  final List<int> solution;
  final List<int> puzzle;
  GeneratedPuzzle(this.solution, this.puzzle);
}

// Función de nivel superior (requerida por Isolate.spawn)
void _generateInIsolate(_GenerateRequest request) {
  final engine = SudokuEngine();
  engine.generate(request.difficulty);
  request.sendPort.send(GeneratedPuzzle(
    List.from(engine.solution),
    List.from(engine.puzzle),
  ));
}

class SudokuEngine {
  List<int> solution = List.filled(81, 0);
  List<int> puzzle = List.filled(81, 0);

  // --- API PÚBLICA ASÍNCRONA ---
  // Lanza la generación en un hilo secundario para no bloquear la UI
  static Future<GeneratedPuzzle> generateAsync(int difficulty) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _generateInIsolate,
      _GenerateRequest(difficulty, receivePort.sendPort),
    );
    final result = await receivePort.first as GeneratedPuzzle;
    receivePort.close();
    return result;
  }

  // --- Dificultad: Agujeros por nivel ---
  // 1 = Principiante:  40 agujeros (~41 pistas)
  // 2 = Normal:        49 agujeros (~32 pistas)
  // 3 = Maestro:       57 agujeros (~24 pistas)
  // 4 = Diabólico:     64 agujeros (~17 pistas, límite teórico mínimo)
  static int holesForDifficulty(int difficulty) {
    switch (difficulty) {
      case 1: return 40;
      case 2: return 49;
      case 3: return 57;
      case 4: return 64;
      default: return 49;
    }
  }

  void generate(int difficulty) {
    solution = List.filled(81, 0);
    _fillDiagonal();
    _fillRemaining(0, 3);

    int holes = holesForDifficulty(difficulty);
    puzzle = List.from(solution);
    _removeDigitsSymmetric(holes);
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
        } while (!_isSafeInBox(solution, row, col, num));
        solution[(row + i) * 9 + (col + j)] = num;
      }
    }
  }

  bool _isSafeInBox(List<int> board, int rowStart, int colStart, int num) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[(rowStart + i) * 9 + (colStart + j)] == num) return false;
      }
    }
    return true;
  }

  bool _checkIfSafe(List<int> board, int i, int j, int num) {
    return (_unUsedInRow(board, i, num) &&
        _unUsedInCol(board, j, num) &&
        _isSafeInBox(board, i - i % 3, j - j % 3, num));
  }

  bool _unUsedInRow(List<int> board, int i, int num) {
    for (int j = 0; j < 9; j++) {
      if (board[i * 9 + j] == num) return false;
    }
    return true;
  }

  bool _unUsedInCol(List<int> board, int j, int num) {
    for (int i = 0; i < 9; i++) {
      if (board[i * 9 + j] == num) return false;
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
      if (_checkIfSafe(solution, i, j, num)) {
        solution[i * 9 + j] = num;
        if (_fillRemaining(i, j + 1)) return true;
        solution[i * 9 + j] = 0;
      }
    }
    return false;
  }

  /// Elimina dígitos garantizando:
  /// 1. Simetría de 180°: si se borra (r, c), también se intenta borrar (8-r, 8-c)
  /// 2. Unicidad: cada par borrado es verificado con el solver
  /// 3. Si la simetría + unicidad impide alcanzar el objetivo (especialmente en
  ///    niveles altos como Diabólico), se completa con un paso suplementario
  ///    no-simétrico para garantizar que llegamos al número de agujeros pedido.
  void _removeDigitsSymmetric(int holesToMake) {
    // Generamos los índices de la mitad del tablero (posiciones 0..40)
    // El índice 40 es el centro del tablero (celda [4,4])
    List<int> halfCells = List.generate(41, (i) => i);
    halfCells.shuffle();

    int holes = 0;

    for (int cellId in halfCells) {
      if (holes >= holesToMake) break;

      int mirrorId = 80 - cellId; // Posición opuesta 180°

      if (cellId == mirrorId) {
        // Centro del tablero: no tiene par
        if (puzzle[cellId] == 0) continue;
        int temp = puzzle[cellId];
        puzzle[cellId] = 0;
        if (_countSolutions(List.from(puzzle)) == 1) {
          holes++;
        } else {
          puzzle[cellId] = temp;
        }
      } else {
        // Par de celdas simétricas
        if (puzzle[cellId] == 0 || puzzle[mirrorId] == 0) continue;

        // FIX Error 2: no añadir el par si supera el objetivo
        int increment = (holes + 2 <= holesToMake) ? 2 : 1;

        int tempA = puzzle[cellId];
        int tempB = puzzle[mirrorId];

        if (increment == 2) {
          // Intentar borrar ambas celdas del par
          puzzle[cellId] = 0;
          puzzle[mirrorId] = 0;
          if (_countSolutions(List.from(puzzle)) == 1) {
            holes += 2;
          } else {
            puzzle[cellId] = tempA;
            puzzle[mirrorId] = tempB;
          }
        } else {
          // Solo necesitamos 1 más: intentar solo una del par
          puzzle[cellId] = 0;
          if (_countSolutions(List.from(puzzle)) == 1) {
            holes++;
          } else {
            puzzle[cellId] = tempA;
            // Intentar la otra del par
            puzzle[mirrorId] = 0;
            if (_countSolutions(List.from(puzzle)) == 1) {
              holes++;
            } else {
              puzzle[mirrorId] = tempB;
            }
          }
        }
      }
    }

    // FIX Error 3: si la simetría no alcanzó el objetivo (típico en Diabólico),
    // rellenar el déficit con una pasada suplementaria no-simétrica.
    if (holes < holesToMake) {
      List<int> remaining = [];
      for (int i = 0; i < 81; i++) {
        if (puzzle[i] != 0) remaining.add(i);
      }
      remaining.shuffle();

      for (int cellId in remaining) {
        if (holes >= holesToMake) break;
        if (puzzle[cellId] == 0) continue;

        int temp = puzzle[cellId];
        puzzle[cellId] = 0;
        if (_countSolutions(List.from(puzzle)) == 1) {
          holes++;
        } else {
          puzzle[cellId] = temp;
        }
      }
    }
  }

  int _countSolutions(List<int> board) {
    int row = -1;
    int col = -1;
    bool isEmpty = false;
    for (int i = 0; i < 81; i++) {
      if (board[i] == 0) {
        row = i ~/ 9;
        col = i % 9;
        isEmpty = true;
        break;
      }
    }

    if (!isEmpty) return 1;

    int count = 0;
    for (int num = 1; num <= 9; num++) {
      if (_checkIfSafe(board, row, col, num)) {
        board[row * 9 + col] = num;
        count += _countSolutions(board);
        if (count > 1) return count; // Early exit: solo importa si es >1
        board[row * 9 + col] = 0;
      }
    }
    return count;
  }
}
