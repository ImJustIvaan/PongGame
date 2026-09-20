import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class SetNewPasswordDialog extends StatefulWidget {
  final PongTheme theme;

  const SetNewPasswordDialog({super.key, required this.theme});

  static Future<void> show(BuildContext context, PongTheme theme) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => SetNewPasswordDialog(theme: theme),
    );
  }

  @override
  State<SetNewPasswordDialog> createState() => _SetNewPasswordDialogState();
}

class _SetNewPasswordDialogState extends State<SetNewPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (SupabaseService.instance.isConfigured) {
      final err = await SupabaseService.instance.updatePassword(password);
      if (err != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = err;
        });
        return;
      }
    }

    await StorageService.instance.updateLocalPassword(password);
    await StorageService.instance.setLoggedIn(true);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _successMessage = 'Password updated successfully! Welcome back.';
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.theme.paddle1Color;
    final accentPink = widget.theme.paddle2Color;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF090B1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glowColor.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: accentPink.withValues(alpha: 0.2),
              blurRadius: 45,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.lock_reset, color: glowColor, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'SET NEW PASSWORD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'You opened the password recovery link. Please choose a new password for your account:',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x33FF1744),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF1744)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),

            if (_successMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x3300FF88),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00FF88)),
                ),
                child: Text(_successMessage!, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),

            _buildField(
              label: 'NEW PASSWORD (6+ CHARACTERS)',
              controller: _passwordController,
              glowColor: glowColor,
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'CONFIRM NEW PASSWORD',
              controller: _confirmController,
              glowColor: glowColor,
            ),
            const SizedBox(height: 20),

            Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [glowColor, const Color(0xFF0072FF)]),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.4),
                    blurRadius: 14,
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
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'SAVE NEW PASSWORD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required Color glowColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: glowColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10132C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: glowColor.withValues(alpha: 0.5)),
          ),
          child: TextField(
            controller: controller,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            cursorColor: glowColor,
            decoration: const InputDecoration(
              hintText: '••••••••',
              hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
