import 'package:flutter_test/flutter_test.dart';
import 'package:z_arrows/game/board_logic.dart';
import 'package:z_arrows/models/arrow_line.dart';
import 'package:z_arrows/models/direction.dart';
import 'package:z_arrows/models/level.dart';
import 'package:z_arrows/models/level_generator.dart';
import 'package:z_arrows/models/levels.dart';

Level level(int rows, int cols, List<String> specs) =>
    Level.parse(rows: rows, cols: cols, lineSpecs: specs);

void main() {
  group('ArrowLine.parse', () {
    test('traces cells from tail to head', () {
      final line = ArrowLine.parse(0, '1,2:RRD');
      expect(line.cells, [(1, 2), (1, 3), (1, 4), (2, 4)]);
      expect(line.head, (2, 4));
      expect(line.headDir, Direction.down);
    });
  });

  group('BoardLogic.tap', () {
    test('clear exit ray escapes with free-cell count', () {
      final board = BoardLogic.fromLevel(level(3, 5, ['0,0:RR']));
      final result = board.tap(0);
      expect(result, isA<MoveEscaped>());
      expect((result as MoveEscaped).steps, 2);
    });

    test('another line on the ray blocks with distance and blocker id', () {
      final board = BoardLogic.fromLevel(level(3, 5, ['0,0:R', '0,3:D']));
      final result = board.tap(0);
      expect(result, isA<MoveBlocked>());
      final blocked = result as MoveBlocked;
      expect(blocked.freeSteps, 1);
      expect(blocked.blockerId, 1);
    });

    test('own body on the exit ray does not block (spiral escapes)', () {
      // Spiral: head at (1,1) pointing up, ray passes own cell (0,1).
      final board = BoardLogic.fromLevel(level(3, 3, ['0,0:RRDDLU']));
      expect(board.tap(0), isA<MoveEscaped>());
    });

    test('removing the blocker frees the ray', () {
      final board = BoardLogic.fromLevel(level(3, 5, ['0,0:R', '0,3:D']));
      board.removeLine(1);
      expect(board.tap(0), isA<MoveEscaped>());
    });
  });

  group('BoardLogic.isSolvable', () {
    test('head-on pair is a deadlock', () {
      expect(
        BoardLogic.isSolvable(level(1, 4, ['0,0:R', '0,3:L'])),
        isFalse,
      );
    });

    test('windmill of mutually blocking lines is a deadlock', () {
      expect(
        BoardLogic.isSolvable(
            level(3, 3, ['0,0:R', '0,2:D', '2,2:L', '2,0:U'])),
        isFalse,
      );
    });
  });

  group('generateLevel', () {
    test('bundled levels are dense, in-mask, and solvable', () {
      final levels = bundledLevels;
      expect(levels, hasLength(50));
      for (var i = 0; i < levels.length; i++) {
        final lvl = levels[i];
        final cellCount =
            lvl.lines.fold<int>(0, (sum, l) => sum + l.cells.length);
        expect(cellCount, greaterThan(lvl.mask.length ~/ 2),
            reason: 'level ${i + 1} is too sparse');
        expect(lvl.lines.length, greaterThanOrEqualTo(12),
            reason: 'level ${i + 1} has too few lines for a 1min+ solve');
        for (final line in lvl.lines) {
          for (final cell in line.cells) {
            expect(lvl.mask.contains(cell), isTrue,
                reason: 'level ${i + 1} line outside mask');
          }
        }
        expect(BoardLogic.isSolvable(lvl), isTrue,
            reason: 'bundled level ${i + 1} is not solvable');
      }
    });

    test('random seeds and masks always produce solvable levels', () {
      for (var seed = 1; seed <= 30; seed++) {
        final mask = switch (seed % 4) {
          0 => BoardMasks.rect(13, 10),
          1 => BoardMasks.ellipse(13, 10),
          2 => BoardMasks.diamond(13, 10),
          _ => BoardMasks.blob(13, 10, seed),
        };
        final lvl = generateLevel(
          rows: 13,
          cols: 10,
          mask: mask,
          seed: seed,
          fill: 0.9,
        );
        expect(BoardLogic.isSolvable(lvl), isTrue,
            reason: 'seed $seed produced an unsolvable level');
      }
    });
  });
}
