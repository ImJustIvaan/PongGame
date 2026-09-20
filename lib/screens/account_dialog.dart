import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../utils/user_utils.dart';

class AccountDialog extends StatefulWidget {
  final PongTheme theme;
  final int? initialTab;

  const AccountDialog({super.key, required this.theme, this.initialTab});

  static Future<void> show(BuildContext context, PongTheme theme, {int? initialTab}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AccountDialog(theme: theme, initialTab: initialTab),
    );
  }

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> with TickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabase = SupabaseService.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isResetPasswordMode = false;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  PlayerStats? _myStats;
  List<PlayerStats> _leaderboard = [];
  bool _isLoadingLeaderboard = false;

  static const List<String> _suggestedNames = [
    'CYBER_VIPER',
    'NEON_BLADE',
    'PADDLE_ZERO',
    'RETRO_GHOST',
    'PONG_TITAN',
    'QUANTUM_HIT',
    'HYPER_PULSE',
    'SHADOW_ACE',
    'TURBO_CORE',
    'VORTEX_KING',
  ];

  bool get _isLoggedIn => StorageService.instance.isLoggedIn() || _supabase.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _initTabController();

    final localName = StorageService.instance.getUsername();
    if (localName != null && localName.isNotEmpty) {
      _usernameController.text = localName;
    }

    _loadInitialData();
  }

  void _initTabController() {
    final count = _isLoggedIn ? 2 : 3;
    int index = 0;
    if (widget.initialTab != null) {
      index = widget.initialTab!.clamp(0, count - 1);
    }
    _tabController = TabController(
      length: count,
      vsync: this,
      initialIndex: index,
    );
  }

  void _rebuildTabController() {
    _tabController.dispose();
    _initTabController();
    setState(() {});
  }

  void _loadInitialData() async {
    if (_isLoggedIn) {
      final stats = await _supabase.fetchMyStats();
      if (mounted) setState(() => _myStats = stats);
    }
    _fetchLeaderboard();
  }

  void _fetchLeaderboard() async {
    if (!mounted) return;
    setState(() => _isLoadingLeaderboard = true);
    try {
      final list = await _supabase.fetchLeaderboard().timeout(const Duration(seconds: 8));
      if (mounted) {
        setState(() {
          _leaderboard = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaderboard in dialog: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLeaderboard = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _resetEmailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_supabase.isConfigured) {
      final savedEmail = StorageService.instance.getSavedEmail();
      if (savedEmail != null && savedEmail.toLowerCase() == email.toLowerCase()) {
        setState(() {
          _isLoading = false;
          _isResetPasswordMode = false;
          _successMessage = 'Local account found! You can sign up with a new password to overwrite.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No account found with that email address.';
        });
      }
      return;
    }

    final error = await _supabase.resetPassword(email);
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _isResetPasswordMode = false;
        _successMessage = 'Password reset link sent to $email! Check your inbox.';
      });
    }
  }

  void _showChangePasswordDialog() {
    _newPasswordController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        final cyan = widget.theme.paddle1Color;
        bool isSubmitting = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF090B1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cyan.withValues(alpha: 0.6)),
              ),
              title: const Text(
                'CHANGE PASSWORD',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter a new password (minimum 6 characters):',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: cyan,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF10132C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cyan.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cyan),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(dialogError!, style: const TextStyle(color: Color(0xFFFF1744), fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newPass = _newPasswordController.text.trim();
                          if (newPass.length < 6) {
                            setDialogState(() => dialogError = 'Password must be at least 6 characters');
                            return;
                          }
                          setDialogState(() => isSubmitting = true);

                          if (_supabase.isConfigured) {
                            final err = await _supabase.updatePassword(newPass);
                            if (err != null) {
                              setDialogState(() {
                                isSubmitting = false;
                                dialogError = err;
                              });
                              return;
                            }
                          }
                          await StorageService.instance.updateLocalPassword(newPass);
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (mounted) {
                            setState(() => _successMessage = 'Password updated successfully!');
                          }
                        },
                  child: const Text('SAVE PASSWORD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _rollRandomName() {
    final rand = _suggestedNames[Random().nextInt(_suggestedNames.length)];
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
      setState(() => _errorMessage = 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_supabase.isConfigured) {
      final isValid = StorageService.instance.validateLocalCredentials(
        email: email,
        password: password,
      );
      if (!isValid) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid email or password. Please create an account first.';
        });
        return;
      }

      await StorageService.instance.setLoggedIn(true);
      final username = StorageService.instance.getUsername() ?? email.split('@').first;
      setState(() {
        _isLoading = false;
        _successMessage = 'Welcome back, $username!';
      });
      _rebuildTabController();
      return;
    }

    final error = await _supabase.signIn(email: email, password: password);
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    } else {
      await StorageService.instance.setLoggedIn(true);
      await _supabase.syncLocalRecords(
        StorageService.instance.getHighScore(),
        StorageService.instance.getBestRally(),
      );
      final stats = await _supabase.fetchMyStats();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _myStats = stats;
          _successMessage = 'Welcome back, ${_supabase.currentUsername}!';
        });
        _rebuildTabController();
      }
    }
  }

  void _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'All fields are required');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await StorageService.instance.saveLocalAccount(
      username: username,
      email: email,
      password: password,
    );

    if (!_supabase.isConfigured) {
      setState(() {
        _isLoading = false;
        _successMessage = 'Account created for $username!';
      });
      _rebuildTabController();
      return;
    }

    final error = await _supabase.signUp(
      email: email,
      password: password,
      username: username,
    );

    if (error != null) {
      setState(() {
        _errorMessage = error;
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
          _successMessage = 'Welcome, $username!';
        });
        _rebuildTabController();
      }
    }
  }

  void _handleLogOut() async {
    setState(() => _isLoading = true);
    await StorageService.instance.logout();
    await _supabase.signOut();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _myStats = null;
        _successMessage = 'Logged out successfully';
        _errorMessage = null;
      });
      _rebuildTabController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.theme.paddle1Color;
    final accentPink = widget.theme.paddle2Color;
    final loggedIn = _isLoggedIn;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: const Color(0xFF090B1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glowColor.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 32,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: accentPink.withValues(alpha: 0.2),
              blurRadius: 50,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Subtle background ambient glow
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.2),
                        blurRadius: 60,
                        spreadRadius: 30,
                      )
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: loggedIn ? const Color(0x2200E5FF) : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: loggedIn ? glowColor.withValues(alpha: 0.7) : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: loggedIn ? const Color(0xFF00FF88) : Colors.white38,
                                  shape: BoxShape.circle,
                                  boxShadow: loggedIn
                                      ? [
                                          const BoxShadow(
                                            color: Color(0xFF00FF88),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                loggedIn ? 'LOGGED IN' : 'GUEST',
                                style: TextStyle(
                                  color: loggedIn ? glowColor : Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.close, color: Colors.white70, size: 16),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      loggedIn ? 'PLAYER PROFILE' : 'PLAYER ACCOUNT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: glowColor.withValues(alpha: 0.8), blurRadius: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Bar
                    _buildSegmentedTabBar(glowColor),
                    const SizedBox(height: 16),

                    // Status Messages
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF1744),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF1744)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44FF1744), blurRadius: 10)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_successMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0x3300FF88),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00FF88)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x4400FF88), blurRadius: 10)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF00FF88), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Tab View
                    Flexible(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          height: 350,
                          child: TabBarView(
                            controller: _tabController,
                            children: loggedIn
                                ? [
                                    _buildProfileView(glowColor),
                                    _buildLeaderboardView(glowColor),
                                  ]
                                : [
                                    _buildLeaderboardView(glowColor),
                                    _isResetPasswordMode ? _buildResetPasswordView(glowColor) : _buildSignInView(glowColor),
                                    _buildSignUpView(glowColor, accentPink),
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
        final tabs = _isLoggedIn
            ? ['PROFILE & STATS', 'LEADERBOARD']
            : ['LEADERBOARD', 'SIGN IN', 'SIGN UP'];

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF10132C),
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
                        letterSpacing: 1.1,
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
          label: 'USERNAME',
          controller: _usernameController,
          hint: 'e.g. imjustivaan',
          icon: Icons.person_outline,
          glowColor: pink,
          trailing: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _rollRandomName,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: pink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: pink.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.casino_outlined, size: 14, color: pink),
                  const SizedBox(width: 4),
                  Text(
                    'RANDOM',
                    style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildNeonField(
          label: 'EMAIL ADDRESS',
          controller: _emailController,
          hint: 'user@example.com',
          icon: Icons.alternate_email,
          glowColor: cyan,
        ),
        const SizedBox(height: 12),
        _buildNeonField(
          label: 'PASSWORD (6+ CHARACTERS)',
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscureText: true,
          glowColor: cyan,
        ),
        const Spacer(),
        _buildGlowButton(
          title: 'CREATE ACCOUNT',
          gradientColors: [pink, const Color(0xFF9C27B0)],
          glowColor: pink,
          isLoading: _isLoading,
          onTap: _handleSignUp,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: const Text(
              'Already have an account? SIGN IN',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordView(Color cyan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: cyan, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _isResetPasswordMode = false),
            ),
            const SizedBox(width: 8),
            const Text(
              'RESET PASSWORD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Enter your email address to receive a secure password reset link:',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        _buildNeonField(
          label: 'EMAIL ADDRESS',
          controller: _resetEmailController,
          hint: 'user@example.com',
          icon: Icons.alternate_email,
          glowColor: cyan,
        ),
        const Spacer(),
        _buildGlowButton(
          title: 'SEND RESET LINK',
          gradientColors: [cyan, const Color(0xFF0072FF)],
          glowColor: cyan,
          isLoading: _isLoading,
          onTap: _handleResetPassword,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _isResetPasswordMode = false),
            child: const Text(
              'Remember your password? SIGN IN',
              style: TextStyle(color: Colors.white60, fontSize: 12),
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
        const SizedBox(height: 10),
        _buildNeonField(
          label: 'EMAIL ADDRESS',
          controller: _emailController,
          hint: 'user@example.com',
          icon: Icons.alternate_email,
          glowColor: cyan,
        ),
        const SizedBox(height: 16),
        _buildNeonField(
          label: 'PASSWORD',
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscureText: true,
          glowColor: cyan,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _isResetPasswordMode = true;
                _errorMessage = null;
                _successMessage = null;
                if (_emailController.text.trim().isNotEmpty) {
                  _resetEmailController.text = _emailController.text.trim();
                }
              });
            },
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: cyan.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const Spacer(),
        _buildGlowButton(
          title: 'SIGN IN',
          gradientColors: [cyan, const Color(0xFF0072FF)],
          glowColor: cyan,
          isLoading: _isLoading,
          onTap: _handleSignIn,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _tabController.animateTo(2),
            child: const Text(
              'Need an account? SIGN UP',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView(Color cyan) {
    final rawName = _supabase.currentUsername;
    final isVerified = UserUtils.isVerified(rawName);
    final highScore = _myStats?.highScore ?? StorageService.instance.getHighScore();
    final bestRally = _myStats?.bestRally ?? StorageService.instance.getBestRally();
    final games = _myStats?.gamesPlayed ?? 0;
    final wins = _myStats?.wins ?? 0;

    return Column(
      children: [
        const SizedBox(height: 4),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cyan.withValues(alpha: 0.15),
            border: Border.all(color: cyan, width: 2),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(alpha: 0.4),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              rawName.isNotEmpty ? rawName[0].toUpperCase() : 'P',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: cyan, blurRadius: 12)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Username + Verified Checkmark
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              rawName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            if (isVerified) UserUtils.verifiedBadge(size: 20),
          ],
        ),

        if (isVerified)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x2200E5FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 12, color: Color(0xFF00E5FF)),
                SizedBox(width: 4),
                Text(
                  'VERIFIED PLAYER',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

        Text(
          _supabase.currentUser?.email ?? StorageService.instance.getSavedEmail() ?? 'Active Player Profile',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 14),

        // Stats Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard('HIGH SCORE', '$highScore', cyan),
            _buildStatCard('BEST RALLY', '$bestRally', const Color(0xFFFF71CE)),
            _buildStatCard('GAMES', '$games', Colors.amberAccent),
            _buildStatCard('WINS', '$wins', const Color(0xFF00FF88)),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            icon: Icon(Icons.lock_reset, size: 16, color: cyan.withValues(alpha: 0.9)),
            label: Text(
              'CHANGE PASSWORD',
              style: TextStyle(
                color: cyan.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            onPressed: _showChangePasswordDialog,
          ),
        ),
        const Spacer(),

        // Bottom Actions: Sync & Log Out
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
                label: Text('SYNC STATS', style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 12)),
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
                      _successMessage = 'Stats synchronized';
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x33FF1744),
                  foregroundColor: const Color(0xFFFF1744),
                  side: const BorderSide(color: Color(0xFFFF1744)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _isLoading ? null : _handleLogOut,
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
              'YOUR RECORD',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2),
            ),
            const SizedBox(height: 6),
            Text(
              'HIGH SCORE: $localHigh   •   BEST RALLY: $localBestRally',
              style: TextStyle(color: cyan, fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: cyan,
                side: BorderSide(color: cyan.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('RELOAD LEADERBOARD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _fetchLeaderboard,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (!_isLoggedIn)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Want to rank on the board?',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => _tabController.animateTo(2),
                  child: Text(
                    'SIGN UP ➔',
                    style: TextStyle(color: cyan, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _leaderboard.length,
            itemBuilder: (context, idx) {
        final item = _leaderboard[idx];
        final rankMedal = idx == 0 ? '🥇' : (idx == 1 ? '🥈' : (idx == 2 ? '🥉' : '#${idx + 1}'));
        final isTop3 = idx < 3;
        final isVerified = UserUtils.isVerified(item.username);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isTop3 ? cyan.withValues(alpha: 0.1) : const Color(0xFF10132C),
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
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isVerified) UserUtils.verifiedBadge(size: 14),
                  ],
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
          ),
        ),
      ],
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
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10132C),
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
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
            blurRadius: 16,
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
                  letterSpacing: 1.5,
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
        color: const Color(0xFF10132C),
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
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}
