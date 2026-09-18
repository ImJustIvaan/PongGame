import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/pong_engine.dart';

void main() {
  group('PongEngine Tests', () {
    test('Initialization values', () {
      final engine = PongEngine(mode: GameMode.singlePlayer, targetScore: 5);
      expect(engine.score1, 0);
      expect(engine.score2, 0);
      expect(engine.ballX, 0.5);
      expect(engine.ballY, 0.5);
      expect(engine.targetScore, 5);
    });

    test('Paddle movement constraints', () {
      final engine = PongEngine();
      engine.movePaddle(1, 1.5);
      expect(engine.paddle1Y <= 1.0, true);

      engine.movePaddle(1, -0.5);
      expect(engine.paddle1Y >= 0.0, true);
    });

    test('Ball movement and wall collision', () {
      final engine = PongEngine();
      engine.startOrServe();
      engine.ballY = 0.005;
      engine.ballVy = -0.5;
      engine.update(0.02);

      // Should bounce downwards
      expect(engine.ballVy > 0, true);
    });

    test('Scoring and GameOver condition', () {
      final engine = PongEngine(targetScore: 2);
      engine.startOrServe();

      // Ball moves past left boundary -> Player 2 scores
      engine.ballX = -0.1;
      engine.update(0.01);
      expect(engine.score2, 1);
      expect(engine.state, GameState.ready);

      // Fast forward serve delay timer so state becomes playing
      engine.update(1.0);
      expect(engine.state, GameState.playing);

      // Ball moves past left boundary again -> Player 2 reaches targetScore 2
      engine.ballX = -0.1;
      engine.update(0.01);
      expect(engine.score2, 2);
      expect(engine.state, GameState.gameOver);
      expect(engine.winner, 2);
    });
  });
}
