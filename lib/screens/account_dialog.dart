import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class AccountDialog extends StatefulWidget {
  final PongTheme theme;

  const AccountDialog({super.key, required this.theme});

  static Future<void> show(BuildContext context, PongTheme theme) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AccountDialog(theme: theme),
    );
  }

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SupabaseService _supabase = SupabaseService.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  PlayerStats? _myStats;
  List<PlayerStats> _leaderboard = [];
  bool _isLoadingLeaderboard = false;

  static const List<String> _coolGamerTags = [
    'CYBER_VIPER',
    'NEON_BLADE',
    'PADDLE_ZERO',
    'RETRO_GHOST',
    'PONG_TITAN',
    'QUANTUM_HIT',
    'HYPER_PULSE',
    'SHADOW_ACE',
    'TURBO_CORE',
    'ARCADE_GOD',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _supabase.isLoggedIn ? 2 : 3,
      vsync: this,
      initialIndex: _supabase.isLoggedIn ? 0 : 1, // Default to CREATE TAG / SIGN UP
    );

    final localName = StorageService.instance.getUsername();
    if (localName != null && localName.isNotEmpty) {
      _usernameController.text = localName;
    }

    _loadInitialData();
  }

  void _loadInitialData() async {
    if (_supabase.isLoggedIn) {
      final stats = await _supabase.fetchMyStats();
      if (mounted) setState(() => _myStats = stats);
    }
    _fetchLeaderboard();
  }

  void _fetchLeaderboard() async {
    if (!_supabase.isConfigured) return;
    setState(() => _isLoadingLeaderboard = true);
    final list = await _supabase.fetchLeaderboard();
    if (mounted) {
      setState(() {
        _leaderboard = list;
        _isLoadingLeaderboard = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _rollRandomGamerTag() {
    final rand = _coolGamerTags[Random().nextInt(_coolGamerTags.length)];
    final num = Random().nextInt(99) + 1;
    setState(() {
      _usernameController.text = '$rand$num';
      _errorMessage = null;
    });
  }

  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'PLEASE ENTER EMAIL & PASSWORD');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_supabase.isConfigured) {
      final username = email.split('@').first;
      await StorageService.instance.saveUsername(username);
      setState(() {
        _isLoading = false;
        _successMessage = 'PILOT IDENTIFIED: $username';
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    final error = await _supabase.signIn(email: email, password: password);
    if (error != null) {
      setState(() {
        _errorMessage = error.toUpperCase();
        _isLoading = false;
      });
    } else {
      await _supabase.syncLocalRecords(
        StorageService.instance.getHighScore(),
        StorageService.instance.getBestRally(),
      );
      final stats = await _supabase.fetchMyStats();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _myStats = stats;
          _successMessage = 'WELCOME BACK, ${_supabase.currentUsername.toUpperCase()}!';
        });
        Navigator.of(context).pop();
      }
    }
  }

  void _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'ALL TERMINAL FIELDS REQUIRED');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'CIPHER KEY MUST BE 6+ CHARACTERS');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await StorageService.instance.saveUsername(username);

    if (!_supabase.isConfigured) {
      setState(() {
        _isLoading = false;
        _successMessage = 'PILOT $username REGISTERED!';
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    final error = await _supabase.signUp(
      email: email,
      password: password,
      username: username,
    );

    if (error != null) {
      setState(() {
        _errorMessage = error.toUpperCase();
        _isLoading = false;
      });
    } else {
      await _supabase.syncLocalRecords(
        StorageService.instance.getHighScore(),
        StorageService.instance.getBestRally(),
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'PILOT $username INITIALIZED!';
        });
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.theme.paddle1Color;
    final accentPink = widget.theme.paddle2Color;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: const Color(0xFF060714),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glowColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.45),
              blurRadius: 36,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: accentPink.withValues(alpha: 0.25),
              blurRadius: 60,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // CRT Scanline Overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CyberGridPainter(color: glowColor.withValues(alpha: 0.04)),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Arcade Top Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: glowColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: glowColor.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: glowColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: glowColor,
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _supabase.isLoggedIn ? 'PILOT ONLINE' : 'NEW CHALLENGER',
                                style: TextStyle(
                                  color: glowColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.close, color: Colors.white70, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Main Title with Glow
                    Text(
                      _supabase.isLoggedIn ? 'PILOT DOSSIER' : 'ENTER THE GRID',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(color: glowColor, blurRadius: 20),
                          Shadow(color: accentPink, blurRadius: 30),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Segmented Arcade Tabs
                    _buildSegmentedTabBar(glowColor),
                    const SizedBox(height: 16),

                    // Error & Success Neon Banners
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF0055),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF0055)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44FF0055), blurRadius: 12)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFFF0055), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_successMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x3300FF99),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00FF99)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x4400FF99), blurRadius: 12)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF00FF99), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Scrollable Tab View
                    Flexible(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          height: 330,
                          child: TabBarView(
                            controller: _tabController,
                            children: _supabase.isLoggedIn
                                ? [
                                    _buildProfileView(glowColor),
                                    _buildLeaderboardView(glowColor),
                                  ]
                                : [
                                    _buildSignInView(glowColor),
                                    _buildSignUpView(glowColor, accentPink),
                                    _buildLeaderboardView(glowColor),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabBar(Color glowColor) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final tabs = _supabase.isLoggedIn
            ? ['MY STATS', 'HALL OF FAME']
            : ['SIGN IN', 'CREATE TAG', 'TOP SCORES'];

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: List.generate(tabs.length, (idx) {
              final isSelected = _tabController.index == idx;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? glowColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.5),
                                blurRadius: 14,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      tabs[idx],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildSignUpView(Color cyan, Color pink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNeonField(
          label: '// ARCADE GAMER TAG',
          controller: _usernameController,
          hint: 'e.g. CYBER_PADDLE',
          icon: Icons.sports_esports_outlined,
          glowColor: pink,
          trailing: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _rollRandomGamerTag,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: pink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: pink.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.casino_outlined, size: 15, color: pink),
                  const SizedBox(width: 4),
                  Text(
                    'ROLL',
                    style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildNeonField(
          label: '// PILOT EMAIL',
          controller: _emailController,
          hint: 'pilot@grid.io',
          icon: Icons.alternate_email,
          glowColor: cyan,
        ),
        const SizedBox(height: 12),
        _buildNeonField(
          label: '// CIPHER KEY (6+ CHARS)',
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscureText: true,
          glowColor: cyan,
        ),
        const Spacer(),
        _buildGlowButton(
          title: 'INITIALIZE ACCOUNT ➔',
          gradientColors: [pink, const Color(0xFF8A2387)],
          glowColor: pink,
          isLoading: _isLoading,
          onTap: _handleSignUp,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _tabController.animateTo(0),
            child: const Text(
              'Already registered? SIGN IN ➔',
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInView(Color cyan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _buildNeonField(
          label: '// REGISTERED EMAIL',
          controller: _emailController,
          hint: 'pilot@grid.io',
          icon: Icons.alternate_email,
          glowColor: cyan,
        ),
        const SizedBox(height: 14),
        _buildNeonField(
          label: '// CIPHER KEY',
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.vpn_key_outlined,
          obscureText: true,
          glowColor: cyan,
        ),
        const Spacer(),
        _buildGlowButton(
          title: 'ACCESS TERMINAL ➔',
          gradientColors: [cyan, const Color(0xFF0072FF)],
          glowColor: cyan,
          isLoading: _isLoading,
          onTap: _handleSignIn,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: const Text(
              'Need a gamertag? CREATE TAG ➔',
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView(Color cyan) {
    final name = _supabase.currentUsername.toUpperCase();
    final highScore = _myStats?.highScore ?? StorageService.instance.getHighScore();
    final bestRally = _myStats?.bestRally ?? StorageService.instance.getBestRally();
    final games = _myStats?.gamesPlayed ?? 0;
    final wins = _myStats?.wins ?? 0;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cyan.withValues(alpha: 0.15),
            border: Border.all(color: cyan, width: 2),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0] : 'P',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: cyan, blurRadius: 12)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [Shadow(color: cyan, blurRadius: 16)],
          ),
        ),
        Text(
          _supabase.currentUser?.email ?? 'OFFLINE PILOT PROFILE',
          style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard('HIGH SCORE', '$highScore', cyan),
            _buildStatCard('BEST RALLY', '$bestRally', const Color(0xFFFF71CE)),
            _buildStatCard('GAMES', '$games', Colors.amberAccent),
            _buildStatCard('WINS', '$wins', const Color(0xFF00FF99)),
          ],
        ),
        const Spacer(),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cyan),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.sync, color: cyan, size: 18),
                label: Text('SYNC CLOUD', style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _supabase.syncLocalRecords(
                    StorageService.instance.getHighScore(),
                    StorageService.instance.getBestRally(),
                  );
                  final s = await _supabase.fetchMyStats();
                  if (mounted) {
                    setState(() {
                      _myStats = s;
                      _isLoading = false;
                      _successMessage = 'DATA SYNCHRONIZED';
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x33FF0055),
                  foregroundColor: const Color(0xFFFF0055),
                  side: const BorderSide(color: Color(0xFFFF0055)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: const Text('DISCONNECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () async {
                  await _supabase.signOut();
                  if (mounted) {
                    setState(() {});
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaderboardView(Color cyan) {
    if (_isLoadingLeaderboard) {
      return Center(child: CircularProgressIndicator(color: cyan));
    }
    final localHigh = StorageService.instance.getHighScore();
    final localBestRally = StorageService.instance.getBestRally();

    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cyan.withValues(alpha: 0.1),
                border: Border.all(color: cyan.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.emoji_events_outlined, size: 48, color: cyan),
            ),
            const SizedBox(height: 14),
            const Text(
              'YOUR RECORD ON FILE',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2),
            ),
            const SizedBox(height: 6),
            Text(
              'HIGH SCORE: $localHigh   •   BEST RALLY: $localBestRally',
              style: TextStyle(color: cyan, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _leaderboard.length,
      itemBuilder: (context, idx) {
        final item = _leaderboard[idx];
        final rankMedal = idx == 0 ? '🥇' : (idx == 1 ? '🥈' : (idx == 2 ? '🥉' : '#${idx + 1}'));
        final isTop3 = idx < 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isTop3 ? cyan.withValues(alpha: 0.1) : const Color(0xFF0C0E24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTop3 ? cyan : Colors.white12,
            ),
            boxShadow: isTop3
                ? [
                    BoxShadow(
                      color: cyan.withValues(alpha: 0.2),
                      blurRadius: 10,
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(rankMedal, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(
                  item.username.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                '${item.highScore} PTS',
                style: TextStyle(
                  color: cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: cyan, blurRadius: 10)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNeonField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color glowColor,
    bool obscureText = false,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: glowColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0D21),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: glowColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.12),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(icon, color: glowColor, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  cursorColor: glowColor,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlowButton({
    required String title,
    required List<Color> gradientColors,
    required Color glowColor,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: gradientColors),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              shadows: [Shadow(color: color, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  final Color color;
  _CyberGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
