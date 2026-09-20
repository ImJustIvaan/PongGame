import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../game/game_theme.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class AccountDialog extends StatefulWidget {
  final PongTheme theme;

  const AccountDialog({super.key, required this.theme});

  static Future<void> show(BuildContext context, PongTheme theme) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AccountDialog(theme: theme),
    );
  }

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SupabaseService _supabase = SupabaseService.instance;

  // Form Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _urlController = TextEditingController(text: SupabaseConfig.url);
  final _anonKeyController = TextEditingController(text: SupabaseConfig.anonKey);

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  PlayerStats? _myStats;
  List<PlayerStats> _leaderboard = [];
  bool _isLoadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _supabase.isLoggedIn ? 2 : 3, vsync: this);
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
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _supabase.signIn(email: email, password: password);
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    } else {
      // Sync local records on login
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
        Navigator.of(context).pop();
      }
    }
  }

  void _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'Please fill out all fields.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
          _successMessage = 'Account created! Welcome, $username!';
        });
        Navigator.of(context).pop();
      }
    }
  }

  void _handleSaveConfig() async {
    final url = _urlController.text.trim();
    final key = _anonKeyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() => _errorMessage = 'URL and Anon Key cannot be empty.');
      return;
    }

    setState(() => _isLoading = true);
    await SupabaseConfig.saveCustomConfig(url, key);
    final success = await _supabase.initialize();

    setState(() {
      _isLoading = false;
      if (success) {
        _successMessage = 'Connected to Supabase!';
        _errorMessage = null;
      } else {
        _errorMessage = 'Could not connect. Please check URL and Key.';
      }
    });
    if (success) _fetchLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: const Color(0xFF111222),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: widget.theme.paddle1Color.withValues(alpha: 0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.theme.paddle1Color.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 24, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _supabase.isLoggedIn ? 'PLAYER PROFILE' : 'ACCOUNT & CLOUD',
                    style: TextStyle(
                      color: widget.theme.ballColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: widget.theme.paddle1Color,
              labelColor: widget.theme.paddle1Color,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: _supabase.isLoggedIn
                  ? const [
                      Tab(text: 'MY STATS'),
                      Tab(text: 'LEADERBOARD'),
                    ]
                  : const [
                      Tab(text: 'SIGN IN'),
                      Tab(text: 'SIGN UP'),
                      Tab(text: 'SUPABASE SETUP'),
                    ],
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),

            if (_successMessage != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Text(_successMessage!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ),

            // Tab Views
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: 340,
                  child: TabBarView(
                    controller: _tabController,
                    children: _supabase.isLoggedIn
                        ? [
                            _buildProfileView(),
                            _buildLeaderboardView(),
                          ]
                        : [
                            _buildSignInView(),
                            _buildSignUpView(),
                            _buildConfigView(),
                          ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: widget.theme.paddle1Color.withValues(alpha: 0.2),
          child: Text(
            _supabase.currentUsername.isNotEmpty ? _supabase.currentUsername[0].toUpperCase() : 'P',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: widget.theme.paddle1Color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _supabase.currentUsername,
          style: TextStyle(color: widget.theme.ballColor, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          _supabase.currentUser?.email ?? '',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statTile('HIGH SCORE', '${_myStats?.highScore ?? StorageService.instance.getHighScore()}'),
            _statTile('BEST RALLY', '${_myStats?.bestRally ?? StorageService.instance.getBestRally()}'),
            _statTile('GAMES', '${_myStats?.gamesPlayed ?? 0}'),
            _statTile('WINS', '${_myStats?.wins ?? 0}'),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: widget.theme.paddle1Color),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.sync, color: widget.theme.paddle1Color, size: 18),
                label: Text('SYNC NOW', style: TextStyle(color: widget.theme.paddle1Color, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _supabase.syncLocalRecords(
                    StorageService.instance.getHighScore(),
                    StorageService.instance.getBestRally(),
                  );
                  final s = await _supabase.fetchMyStats();
                  setState(() {
                    _myStats = s;
                    _isLoading = false;
                    _successMessage = 'Synced with Supabase cloud!';
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildLeaderboardView() {
    if (_isLoadingLeaderboard) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_leaderboard.isEmpty) {
      return const Center(
        child: Text(
          'No scores recorded yet.\nBe the first to hit the leaderboard!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: _leaderboard.length,
      itemBuilder: (context, idx) {
        final item = _leaderboard[idx];
        final rankIcon = idx == 0 ? '🥇' : (idx == 1 ? '🥈' : (idx == 2 ? '🥉' : '#${idx + 1}'));
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: idx == 0 ? widget.theme.paddle1Color : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(rankIcon, style: const TextStyle(fontSize: 16)),
              ),
              Expanded(
                child: Text(
                  item.username,
                  style: TextStyle(
                    color: widget.theme.ballColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                'HIGH: ${item.highScore}  •  RALLY: ${item.bestRally}',
                style: TextStyle(color: widget.theme.paddle1Color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSignInView() {
    return Column(
      children: [
        _inputField(controller: _emailController, label: 'Email', icon: Icons.email),
        const SizedBox(height: 12),
        _inputField(controller: _passwordController, label: 'Password', icon: Icons.lock, obscureText: true),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.paddle1Color,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _handleSignIn,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpView() {
    return Column(
      children: [
        _inputField(controller: _usernameController, label: 'Arcade Username', icon: Icons.person),
        const SizedBox(height: 12),
        _inputField(controller: _emailController, label: 'Email', icon: Icons.email),
        const SizedBox(height: 12),
        _inputField(controller: _passwordController, label: 'Password (min 6 chars)', icon: Icons.lock, obscureText: true),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.paddle2Color,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _handleSignUp,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONNECT SUPABASE',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste your project credentials from Supabase Dashboard -> Project Settings -> API',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 12),
        _inputField(controller: _urlController, label: 'Project URL (https://xyz.supabase.co)', icon: Icons.link),
        const SizedBox(height: 12),
        _inputField(controller: _anonKeyController, label: 'Anon Public Key', icon: Icons.key),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.paddle1Color,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _handleSaveConfig,
            child: const Text('SAVE & CONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        prefixIcon: Icon(icon, color: widget.theme.paddle1Color, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.theme.paddle1Color),
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: widget.theme.ballColor, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
