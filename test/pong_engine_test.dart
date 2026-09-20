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

    test('Owner Auto-Play: auto-serves ball seamlessly', () {
      final engine = PongEngine(mode: GameMode.singlePlayer);
      engine.ownerAutoPlay = true;
      expect(engine.state, GameState.ready);

      // In ownerAutoPlay, the delay timer counts down fast and serves
      engine.update(0.2);
      expect(engine.state, GameState.playing);
    });

    test('Owner Auto-Play: auto-blocks incoming ball for Paddle 1', () {
      final engine = PongEngine(mode: GameMode.singlePlayer);
      engine.ownerAutoPlay = true;
      engine.state = GameState.playing;

      // Ball is coming toward Paddle 1 (ballVx < 0) from the upper quadrant
      engine.ballX = 0.4;
      engine.ballY = 0.8;
      engine.ballVx = -0.7;
      engine.ballVy = 0.0;
      engine.paddle1Y = 0.2; // Currently far from ball

      // Update engine
      engine.update(0.05);

      // Paddle 1 must have steered towards 0.8 (downwards) to intercept and block
      expect(engine.paddle1Y > 0.2, isTrue);
    });
  });
}
