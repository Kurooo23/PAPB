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

/// Ukuran dari MediaQuery: padding luar 6% lebar layar, padding kartu
/// 6% lebar (16–28 dp), ikon 16% lebar (56–80 dp), kartu maks 420 dp.
class _VerifySize {
  const _VerifySize._({
    required this.outerHorizontal,
    required this.outerVertical,
    required this.cardPadding,
    required this.iconSize,
    required this.titleFontSize,
  });

  factory _VerifySize.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return _VerifySize._(
      outerHorizontal: screen.width * 0.06,
      outerVertical: screen.height * 0.04,
      cardPadding: (screen.width * 0.06).clamp(16.0, 28.0),
      iconSize: (screen.width * 0.16).clamp(56.0, 80.0),
      titleFontSize: screen.width < 360 ? 18 : 20,
    );
  }

  final double outerHorizontal;
  final double outerVertical;
  final double cardPadding;
  final double iconSize;
  final double titleFontSize;
}

/// Ditampilkan setelah pendaftaran berhasil. Polling status verifikasi ke
/// backend secara berkala sampai pengguna mengklik link di email.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.userId,
  });

  final String email;

  /// Null kalau backend tidak mengembalikan id. Tanpa id, polling otomatis
  /// dilewati dan pengguna kembali sendiri ke halaman Masuk.
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
      final result = await AuthService.checkVerificationStatus(userId: widget.userId!);
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
      // Push/Pop: kembali ke halaman Masuk
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Gagal cek status diabaikan; polling berikutnya coba lagi.
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
              child: Text(message, style: const TextStyle(color: _VerifyPalette.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _VerifySize.of(context);
    final canResend = !_isResending && _cooldownSeconds <= 0 && !_isVerified;

    return Scaffold(
      backgroundColor: _VerifyPalette.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.outerHorizontal,
              vertical: size.outerVertical,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.all(size.cardPadding),
                decoration: BoxDecoration(
                  color: _VerifyPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _VerifyPalette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusIcon(isVerified: _isVerified, size: size.iconSize),
                    const SizedBox(height: 20),
                    _VerifyMessage(
                      isVerified: _isVerified,
                      email: widget.email,
                      titleFontSize: size.titleFontSize,
                    ),
                    if (!_isVerified) ...[
                      const SizedBox(height: 24),
                      _ResendButton(
                        isResending: _isResending,
                        cooldownSeconds: _cooldownSeconds,
                        onPressed: canResend ? _handleResend : null,
                      ),
                      _BackToLoginButton(onPressed: () => Navigator.pop(context)),
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

// ===================== WIDGET STATELESS =====================

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.isVerified, required this.size});

  final bool isVerified;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? _VerifyPalette.success : _VerifyPalette.accent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isVerified ? Icons.check_circle_rounded : Icons.mark_email_unread_rounded,
        color: color,
        size: size * 0.5,
      ),
    );
  }
}

class _VerifyMessage extends StatelessWidget {
  const _VerifyMessage({
    required this.isVerified,
    required this.email,
    required this.titleFontSize,
  });

  final bool isVerified;
  final String email;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isVerified ? 'Email Terverifikasi' : 'Cek Email Anda',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _VerifyPalette.textPrimary,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isVerified
              ? 'Mengalihkan ke halaman Masuk...'
              : 'Kami telah mengirim link verifikasi ke:',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _VerifyPalette.textSecondary, fontSize: 14),
        ),
        if (!isVerified) ...[
          const SizedBox(height: 6),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _VerifyPalette.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Buka email tersebut dan klik link verifikasi. Halaman ini otomatis '
            'lanjut ke halaman Masuk setelah terverifikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _VerifyPalette.textMuted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _ResendButton extends StatelessWidget {
  const _ResendButton({
    required this.isResending,
    required this.cooldownSeconds,
    required this.onPressed,
  });

  final bool isResending;
  final int cooldownSeconds;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _VerifyPalette.accent,
        disabledForegroundColor: _VerifyPalette.textMuted,
        minimumSize: const Size(0, 44),
      ),
      child: isResending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              cooldownSeconds > 0
                  ? 'Kirim ulang (${cooldownSeconds}s)'
                  : 'Kirim ulang email verifikasi',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _BackToLoginButton extends StatelessWidget {
  const _BackToLoginButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _VerifyPalette.textSecondary,
        minimumSize: const Size(0, 44),
      ),
      child: const Text('Kembali ke halaman Masuk', style: TextStyle(fontSize: 13)),
    );
  }
}