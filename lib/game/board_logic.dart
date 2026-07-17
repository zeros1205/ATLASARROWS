import '../models/arrow_line.dart';
import '../models/level.dart';

/// Result of tapping a line.
sealed class MoveResult {
  const MoveResult();
}

/// The head's straight exit ray is clear (own body never blocks):
/// the whole line slides out along its path. [steps] is the number of
/// free cells between the head and the board edge.
class MoveEscaped extends MoveResult {
  const MoveEscaped(this.steps);
  final int steps;
}

/// Another line sits on the exit ray after [freeSteps] clear cells.
/// The line bumps into it and returns; the player loses a heart.
class MoveBlocked extends MoveResult {
  const MoveBlocked(this.freeSteps, this.blockerId);
  final int freeSteps;
  final int blockerId;
}

/// Pure board state + rules. No rendering, no animation, no hearts —
/// mistakes are a presentation/session concern.
class BoardLogic {
  BoardLogic.fromLevel(Level level)
      : rows = level.rows,
        cols = level.cols,
        lines = {for (final l in level.lines) l.id: l},
        _owner = {
          for (final l in level.lines)
            for (final cell in l.cells) cell: l.id,
        };

  final int rows;
  final int cols;
  final Map<int, ArrowLine> lines;
  final Map<(int, int), int> _owner;

  bool get isCleared => lines.isEmpty;

  /// Rule check only — does not mutate. Call [removeLine] once an escape
  /// is committed.
  MoveResult tap(int lineId) {
    final line = lines[lineId]!;
    final dir = line.headDir;
    var (r, c) = line.head;
    r += dir.dy;
    c += dir.dx;
    var steps = 0;
    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      final owner = _owner[(r, c)];
      if (owner != null && owner != lineId) {
        return MoveBlocked(steps, owner);
      }
      steps++;
      r += dir.dy;
      c += dir.dx;
    }
    return MoveEscaped(steps);
  }

  void removeLine(int lineId) {
    final line = lines.remove(lineId)!;
    for (final cell in line.cells) {
      _owner.remove(cell);
    }
  }

  /// Solvable iff greedily removing any free line empties the board:
  /// removals never block another line, so the greedy fixpoint is exact.
  static bool isSolvable(Level level) {
    final board = BoardLogic.fromLevel(level);
    var progressed = true;
    while (progressed && !board.isCleared) {
      progressed = false;
      for (final id in board.lines.keys.toList()) {
        if (board.tap(id) is MoveEscaped) {
          board.removeLine(id);
          progressed = true;
        }
      }
    }
    return board.isCleared;
  }
}
