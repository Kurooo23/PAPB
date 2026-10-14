import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Palet yang sama dengan login_screen.dart dan register_screen.dart.
class _VerifyPalette {
  static const bg = Color(0xFF12141A);
  static const surface = Color(0xFF1B1E26);
  static const border = Color(0xFF2A2E38);
  static const textPrimary = Color(0xFFEDEFF3);
  static const textSecondary = Color(0xFFA0A5B1);
  static const textMuted = Color(0xFF6C7280);
  static const accent = Color(0xFFD4A24C);
  static const error = Color(0xFFE5484D);
  static const success = Color(0xFF3DA76A);
}

/// Ditampilkan setelah pendaftaran berhasil. Menunggu sampai pengguna
/// mengklik link verifikasi yang dikirim ke email, dengan polling status
/// verifikasi ke backend secara berkala. Pengguna tidak masuk ke halaman
/// Masuk sebelum email-nya terverifikasi.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.userId,
  });

  final String email;

  /// Null kalau backend tidak mengembalikan id (mis. format respons berubah).
  /// Tanpa id, polling otomatis dilewati dan pengguna hanya bisa menunggu
  /// manual lalu kembali sendiri ke halaman Masuk.
  final String? userId;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _pollInterval = Duration(seconds: 4);
  static const _resendCooldown = Duration(seconds: 30);

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _isChecking = false;
  bool _isResending = false;
  bool _isVerified = false;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_isChecking || _isVerified || widget.userId == null) return;
    _isChecking = true;

    try {
      final result = await AuthService.checkVerificationStatus(
        userId: widget.userId!,
      );
      final verified = (result['data'] as Map?)?['verified'] == true;
      if (!mounted || !verified) return;

      _pollTimer?.cancel();
      setState(() => _isVerified = true);

      _showFeedback(
        icon: Icons.check_circle_rounded,
        message: 'Email terverifikasi. Silakan masuk.',
        color: _VerifyPalette.success,
      );

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Kegagalan cek status diam-diam diabaikan; polling berikutnya coba lagi.
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      final result = await AuthService.resendVerification(email: widget.email);
      if (!mounted) return;
      _showFeedback(
        icon: Icons.mark_email_read_rounded,
        message: result['message'] ?? 'Email verifikasi telah dikirim ulang.',
        color: _VerifyPalette.success,
      );
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      _showFeedback(
        icon: Icons.error_outline_rounded,
        message: e.toString().replaceFirst('Exception: ', ''),
        color: _VerifyPalette.error,
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = _resendCooldown.inSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds -= 1;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  void _showFeedback({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _VerifyPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: _VerifyPalette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = !_isResending && _cooldownSeconds <= 0 && !_isVerified;

    return Scaffold(
      backgroundColor: _VerifyPalette.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _VerifyPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _VerifyPalette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusIcon(isVerified: _isVerified),
                    const SizedBox(height: 20),
                    Text(
                      _isVerified ? 'Email Terverifikasi' : 'Cek Email Anda',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VerifyPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isVerified
                          ? 'Mengalihkan ke halaman Masuk...'
                          : 'Kami telah mengirim link verifikasi ke:',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VerifyPalette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (!_isVerified) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _VerifyPalette.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Buka email tersebut dan klik link verifikasi. Halaman '
                        'ini otomatis lanjut ke halaman Masuk setelah '
                        'terverifikasi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _VerifyPalette.textMuted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: canResend ? _handleResend : null,
                        style: TextButton.styleFrom(
                          foregroundColor: _VerifyPalette.accent,
                          disabledForegroundColor: _VerifyPalette.textMuted,
                        ),
                        child: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _cooldownSeconds > 0
                                    ? 'Kirim ulang (${_cooldownSeconds}s)'
                                    : 'Kirim ulang email verifikasi',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: _VerifyPalette.textSecondary,
                        ),
                        child: const Text(
                          'Kembali ke halaman Masuk',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: (isVerified ? _VerifyPalette.success : _VerifyPalette.accent)
            .withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: isVerified
          ? const Icon(
              Icons.check_circle_rounded,
              color: _VerifyPalette.success,
              size: 32,
            )
          : const Icon(
              Icons.mark_email_unread_rounded,
              color: _VerifyPalette.accent,
              size: 32,
            ),
    );
  }
}
