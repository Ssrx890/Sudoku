import 'dart:math';
import 'dart:isolate';

// ─── Datos para el Isolate 9×9 ───────────────────────────────────────────────
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

void _generateInIsolate(_GenerateRequest request) {
  final engine = SudokuEngine();
  engine.generate(request.difficulty);
  request.sendPort.send(GeneratedPuzzle(
    List.from(engine.solution),
    List.from(engine.puzzle),
  ));
}

// ─── Datos para el Isolate 4×4 ───────────────────────────────────────────────
class _Generate4x4Request {
  final SendPort sendPort;
  _Generate4x4Request(this.sendPort);
}

void _generate4x4InIsolate(_Generate4x4Request request) {
  final engine = SudokuEngine4x4();
  engine.generate();
  request.sendPort.send(GeneratedPuzzle(
    List.from(engine.solution),
    List.from(engine.puzzle),
  ));
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MOTOR 9×9
// ═══════════════════════════════════════════════════════════════════════════════
class SudokuEngine {
  List<int> solution = List.filled(81, 0);
  List<int> puzzle = List.filled(81, 0);

  // --- API PÚBLICA ASÍNCRONA ---
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

  void _removeDigitsSymmetric(int holesToMake) {
    List<int> halfCells = List.generate(41, (i) => i);
    halfCells.shuffle();

    int holes = 0;

    for (int cellId in halfCells) {
      if (holes >= holesToMake) break;

      int mirrorId = 80 - cellId;

      if (cellId == mirrorId) {
        if (puzzle[cellId] == 0) continue;
        int temp = puzzle[cellId];
        puzzle[cellId] = 0;
        if (_countSolutions(List.from(puzzle)) == 1) {
          holes++;
        } else {
          puzzle[cellId] = temp;
        }
      } else {
        if (puzzle[cellId] == 0 || puzzle[mirrorId] == 0) continue;

        int increment = (holes + 2 <= holesToMake) ? 2 : 1;

        int tempA = puzzle[cellId];
        int tempB = puzzle[mirrorId];

        if (increment == 2) {
          puzzle[cellId] = 0;
          puzzle[mirrorId] = 0;
          if (_countSolutions(List.from(puzzle)) == 1) {
            holes += 2;
          } else {
            puzzle[cellId] = tempA;
            puzzle[mirrorId] = tempB;
          }
        } else {
          puzzle[cellId] = 0;
          if (_countSolutions(List.from(puzzle)) == 1) {
            holes++;
          } else {
            puzzle[cellId] = tempA;
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
        if (count > 1) return count;
        board[row * 9 + col] = 0;
      }
    }
    return count;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MOTOR 4×4  —  Modo Aprendiz
//  Tablero de 16 celdas · dígitos 1-4 · cajas 2×2
// ═══════════════════════════════════════════════════════════════════════════════
class SudokuEngine4x4 {
  static const int _size = 4;   // Dimensión del tablero
  static const int _box  = 2;   // Tamaño de cada caja

  List<int> solution = List.filled(_size * _size, 0);
  List<int> puzzle   = List.filled(_size * _size, 0);

  // --- API PÚBLICA ASÍNCRONA ---
  static Future<GeneratedPuzzle> generateAsync() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _generate4x4InIsolate,
      _Generate4x4Request(receivePort.sendPort),
    );
    final result = await receivePort.first as GeneratedPuzzle;
    receivePort.close();
    return result;
  }

  void generate() {
    // Rellenar tablero completo con backtracking
    solution = List.filled(_size * _size, 0);
    _fillBoard(0);

    // Crear puzzle quitando ~8 celdas (dejando ~8 pistas visibles)
    puzzle = List.from(solution);
    _removeDigits(8);
  }

  /// Backtracking aleatorio para rellenar el tablero 4×4
  bool _fillBoard(int pos) {
    if (pos == _size * _size) return true;

    int row = pos ~/ _size;
    int col = pos % _size;

    List<int> nums = [1, 2, 3, 4]..shuffle();
    for (int num in nums) {
      if (_isSafe(solution, row, col, num)) {
        solution[pos] = num;
        if (_fillBoard(pos + 1)) return true;
        solution[pos] = 0;
      }
    }
    return false;
  }

  bool _isSafe(List<int> board, int row, int col, int num) {
    // Fila
    for (int c = 0; c < _size; c++) {
      if (board[row * _size + c] == num) return false;
    }
    // Columna
    for (int r = 0; r < _size; r++) {
      if (board[r * _size + col] == num) return false;
    }
    // Caja 2×2
    int boxRow = (row ~/ _box) * _box;
    int boxCol = (col ~/ _box) * _box;
    for (int r = 0; r < _box; r++) {
      for (int c = 0; c < _box; c++) {
        if (board[(boxRow + r) * _size + (boxCol + c)] == num) return false;
      }
    }
    return true;
  }

  void _removeDigits(int holes) {
    // Intentar quitar celdas pares simétricas primero
    List<int> cells = List.generate(_size * _size, (i) => i)..shuffle();
    int removed = 0;

    for (int cellId in cells) {
      if (removed >= holes) break;
      if (puzzle[cellId] == 0) continue;

      int mirrorId = (_size * _size - 1) - cellId;

      if (cellId == mirrorId) {
        int temp = puzzle[cellId];
        puzzle[cellId] = 0;
        if (_countSolutions(List.from(puzzle)) == 1) {
          removed++;
        } else {
          puzzle[cellId] = temp;
        }
      } else if (puzzle[mirrorId] != 0 && removed + 2 <= holes) {
        int tempA = puzzle[cellId];
        int tempB = puzzle[mirrorId];
        puzzle[cellId] = 0;
        puzzle[mirrorId] = 0;
        if (_countSolutions(List.from(puzzle)) == 1) {
          removed += 2;
        } else {
          puzzle[cellId] = tempA;
          puzzle[mirrorId] = tempB;
          // Intentar solo una
          puzzle[cellId] = 0;
          if (_countSolutions(List.from(puzzle)) == 1) {
            removed++;
          } else {
            puzzle[cellId] = tempA;
          }
        }
      } else {
        int temp = puzzle[cellId];
        puzzle[cellId] = 0;
        if (_countSolutions(List.from(puzzle)) == 1) {
          removed++;
        } else {
          puzzle[cellId] = temp;
        }
      }
    }
  }

  int _countSolutions(List<int> board) {
    // Buscar primera celda vacía
    int pos = board.indexOf(0);
    if (pos == -1) return 1; // Tablero completo

    int row = pos ~/ _size;
    int col = pos % _size;
    int count = 0;

    for (int num = 1; num <= _size; num++) {
      if (_isSafe(board, row, col, num)) {
        board[pos] = num;
        count += _countSolutions(board);
        if (count > 1) return count; // Early exit
        board[pos] = 0;
      }
    }
    return count;
  }
}
