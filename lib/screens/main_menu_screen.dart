import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game/game_theme.dart';
import '../game/pong_engine.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../widgets/pong_canvas.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  late PongThemeType _selectedThemeType;
  late AiDifficulty _difficulty;
  late int _targetScore;
  bool _soundEnabled = true;

  late final PongEngine _attractEngine;
  late final Ticker _attractTicker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _selectedThemeType = StorageService.instance.getTheme();
    _difficulty = StorageService.instance.getDifficulty();
    _targetScore = StorageService.instance.getTargetScore();
    _soundEnabled = StorageService.instance.getSoundEnabled();
    SoundService.instance.isMuted = !_soundEnabled;

    // Attract mode background demo (AI vs AI playing)
    _attractEngine = PongEngine(mode: GameMode.attractMode);
    _attractTicker = createTicker((elapsed) {
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
        return;
      }
      final dt = ((elapsed - _lastTick).inMicroseconds / 1000000.0).clamp(0.0, 0.04);
      _lastTick = elapsed;
      _attractEngine.update(dt);
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _attractTicker.dispose();
    super.dispose();
  }

  PongTheme get _theme => PongTheme.fromType(_selectedThemeType);

  void _startGame(GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: mode,
          difficulty: _difficulty,
          targetScore: _targetScore,
          theme: _theme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highScore = StorageService.instance.getHighScore();
    final bestRally = StorageService.instance.getBestRally();

    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      body: Stack(
        children: [
          // Background attract game (semi-transparent)
          Opacity(
            opacity: 0.35,
            child: PongCanvas(
              engine: _attractEngine,
              theme: _theme,
            ),
          ),

          // Menu Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title Logo
                    Text(
                      'P O N G',
                      style: TextStyle(
                        color: _theme.ballColor,
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                        shadows: _theme.hasGlow
                            ? [
                                Shadow(
                                  color: _theme.paddle1Color,
                                  blurRadius: 28,
                                )
                              ]
                            : null,
                      ),
                    ),
                    Text(
                      'CROSS-PLATFORM ARCADE',
                      style: TextStyle(
                        color: _theme.paddle1Color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Play Buttons
                    _buildPlayButton(
                      title: '1 PLAYER  (VS AI)',
                      subtitle: 'Difficulty: ${_difficulty.name.toUpperCase()}',
                      icon: Icons.person,
                      color: _theme.paddle1Color,
                      onTap: () => _startGame(GameMode.singlePlayer),
                    ),
                    const SizedBox(height: 14),

                    _buildPlayButton(
                      title: '2 PLAYERS  (LOCAL)',
                      subtitle: 'Shared Screen / Dual Keys',
                      icon: Icons.people,
                      color: _theme.paddle2Color,
                      onTap: () => _startGame(GameMode.twoPlayer),
                    ),
                    const SizedBox(height: 14),

                    _buildPlayButton(
                      title: 'PRACTICE RALLY',
                      subtitle: 'Solo Rebound Wall',
                      icon: Icons.fitness_center,
                      color: _theme.ballColor,
                      onTap: () => _startGame(GameMode.practice),
                    ),
                    const SizedBox(height: 28),

                    // Difficulty & Target Score Selectors
                    _buildOptionsRow(),

                    const SizedBox(height: 24),

                    // Bottom Bar: Theme switcher, sound toggle, stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIconButton(
                          icon: Icons.palette_outlined,
                          label: _theme.name,
                          onPressed: _showThemePicker,
                        ),
                        const SizedBox(width: 16),
                        _buildIconButton(
                          icon: _soundEnabled ? Icons.volume_up : Icons.volume_off,
                          label: _soundEnabled ? 'SOUND ON' : 'MUTED',
                          onPressed: () {
                            setState(() {
                              _soundEnabled = !_soundEnabled;
                              SoundService.instance.isMuted = !_soundEnabled;
                              StorageService.instance.saveSoundEnabled(_soundEnabled);
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Stats summary
                    if (highScore > 0 || bestRally > 0)
                      Text(
                        'HIGH SCORE: $highScore   •   BEST RALLY: $bestRally',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _theme.hasGlow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsRow() {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AI LEVEL:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              DropdownButton<AiDifficulty>(
                value: _difficulty,
                dropdownColor: const Color(0xFF151520),
                style: TextStyle(color: _theme.paddle1Color, fontWeight: FontWeight.bold, fontSize: 13),
                underline: const SizedBox(),
                items: AiDifficulty.values.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _difficulty = val);
                    StorageService.instance.saveDifficulty(val);
                  }
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FIRST TO:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _targetScore,
                dropdownColor: const Color(0xFF151520),
                style: TextStyle(color: _theme.paddle1Color, fontWeight: FontWeight.bold, fontSize: 13),
                underline: const SizedBox(),
                items: [5, 7, 11].map((pts) {
                  return DropdownMenuItem<int>(
                    value: pts,
                    child: Text('$pts POINTS'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _targetScore = val);
                    StorageService.instance.saveTargetScore(val);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141524),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT THEME',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              ...PongThemeType.values.map((type) {
                final t = PongTheme.fromType(type);
                final isSelected = _selectedThemeType == type;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.paddle1Color,
                    radius: 12,
                  ),
                  title: Text(
                    t.name,
                    style: TextStyle(
                      color: isSelected ? t.paddle1Color : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: t.paddle1Color) : null,
                  onTap: () {
                    setState(() => _selectedThemeType = type);
                    StorageService.instance.saveTheme(type);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
