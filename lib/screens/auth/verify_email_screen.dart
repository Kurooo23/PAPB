import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'widgets/auth_widgets.dart';

/// Ditampilkan setelah pendaftaran berhasil. Polling status verifikasi ke
/// backend secara berkala sampai pengguna mengklik link di email.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, required this.userId});

  final String email;

  /// Null kalau backend tidak mengembalikan id. Tanpa id, polling otomatis
  /// dilewati dan pengguna kembali sendiri ke halaman Masuk.
  final String? userId;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
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
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
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
      context.showAuthFeedback(
        icon: Icons.check_circle_rounded,
        message: 'Email terverifikasi. Silakan masuk.',
        color: AuthColors.success,
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

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      final result = await AuthService.resendVerification(email: widget.email);
      if (!mounted) return;
      context.showAuthFeedback(
        icon: Icons.mark_email_read_rounded,
        message: result['message'] ?? 'Email verifikasi telah dikirim ulang.',
        color: AuthColors.success,
      );
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      context.showAuthFeedback(
        icon: Icons.error_outline_rounded,
        message: e.toString().replaceFirst('Exception: ', ''),
        color: AuthColors.error,
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// Tombol kirim ulang dikunci 30 detik.
  void _startCooldown() {
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _cooldownSeconds--);
      if (!mounted || _cooldownSeconds <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ukuran dari MediaQuery: padding luar 6% lebar / 4% tinggi layar,
    // padding kartu 6% lebar (16–28 dp), ikon 16% lebar (56–80 dp).
    final screen = MediaQuery.sizeOf(context);
    final iconSize = (screen.width * 0.16).clamp(56.0, 80.0);
    final statusColor = _isVerified ? AuthColors.success : AuthColors.accent;
    final canResend = !_isResending && _cooldownSeconds <= 0 && !_isVerified;

    return Scaffold(
      backgroundColor: AuthColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screen.width * 0.06,
              vertical: screen.height * 0.04,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AuthCard(
                padding: (screen.width * 0.06).clamp(16.0, 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isVerified
                            ? Icons.check_circle_rounded
                            : Icons.mark_email_unread_rounded,
                        color: statusColor,
                        size: iconSize * 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isVerified ? 'Email Terverifikasi' : 'Cek Email Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AuthColors.textPrimary,
                        fontSize: screen.width < 360 ? 18 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isVerified
                          ? 'Mengalihkan ke halaman Masuk...'
                          : 'Kami telah mengirim link verifikasi ke:',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AuthColors.textSecondary, fontSize: 14),
                    ),
                    if (!_isVerified) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AuthColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Buka email tersebut dan klik link verifikasi. Halaman ini otomatis '
                        'lanjut ke halaman Masuk setelah terverifikasi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AuthColors.textMuted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: canResend ? _resend : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AuthColors.accent,
                          disabledForegroundColor: AuthColors.textMuted,
                          minimumSize: const Size(0, 44),
                        ),
                        child: _isResending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _cooldownSeconds > 0
                                    ? 'Kirim ulang (${_cooldownSeconds}s)'
                                    : 'Kirim ulang email verifikasi',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      // Push/Pop: kembali ke halaman Masuk
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AuthColors.textSecondary,
                          minimumSize: const Size(0, 44),
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
