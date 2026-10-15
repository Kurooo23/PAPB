import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../data/database_helper.dart';
import '../../data/services/google_sign_in_service.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_widgets.dart';

/// Metode login yang sedang berjalan.
enum _LoginMethod { email, google }

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email wajib diisi';
  if (!email.contains('@')) return 'Masukkan alamat email yang valid';
  return null;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  /// Selama ada login yang berjalan, kedua tombol login nonaktif.
  _LoginMethod? _activeMethod;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loginWithEmail() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _runLogin(
      _LoginMethod.email,
      () => AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _loginWithGoogle() {
    _runLogin(_LoginMethod.google, () async {
      final idToken = await GoogleSignInService.requestIdToken();
      // null = pemilih akun ditutup pengguna: bukan error, cukup berhenti.
      if (idToken == null) return null;
      return AuthService.loginWithGoogle(idToken: idToken);
    });
  }

  /// Alur yang sama untuk semua metode login: minta hasil ke server, simpan
  /// token dan sesi, lalu masuk ke beranda.
  Future<void> _runLogin(_LoginMethod method, Future<dynamic> Function() request) async {
    setState(() => _activeMethod = method);

    try {
      final result = await request();
      if (!mounted || result == null) return;

      // Data bisa ada di result langsung atau di result['data'].
      final data = result['data'] is Map ? result['data'] as Map : const {};
      T? pick<T>(String key) => [result[key], data[key]].whereType<T>().firstOrNull;

      final token = pick<String>('token');
      if (token == null || token.isEmpty) {
        throw Exception('Token login tidak diterima dari server.');
      }
      final user = pick<Map>('user');
      if (user == null) throw Exception('Data pengguna tidak diterima dari server.');
      final userMap = Map<String, dynamic>.from(user);

      const storage = FlutterSecureStorage();
      await storage.write(key: 'user_token', value: token);
      final refreshToken = pick<String>('refresh_token');
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await storage.write(key: 'refresh_token', value: refreshToken);
      } else {
        await storage.delete(key: 'refresh_token');
      }

      await DatabaseHelper.instance.saveUserSession(userMap, token: token);
      if (!mounted) return;

      // Provider: simpan user ke state global
      context.read<AuthProvider>().setUser(userMap);
      context.showAuthFeedback(
        icon: Icons.check_circle_rounded,
        message: 'Login berhasil. Selamat datang di Arena Turnamen.',
        color: AuthColors.success,
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // GetX: hapus semua halaman sebelumnya, lalu ke Home
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      // Akun Google selalu sudah terverifikasi, jadi pesan verifikasi email
      // hanya berlaku untuk login email.
      final isUnverified =
          method == _LoginMethod.email && message.toLowerCase().contains('verifikasi');

      context.showAuthFeedback(
        icon: isUnverified ? Icons.mark_email_unread_rounded : Icons.error_outline_rounded,
        message: isUnverified
            ? 'Verifikasi email Anda terlebih dahulu. Link verifikasi telah dikirim ulang.'
            : message,
        color: isUnverified ? AuthColors.accent : AuthColors.error,
      );
    } finally {
      if (mounted) setState(() => _activeMethod = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvas = AuthCanvas.of(context);
    final compact = canvas.isCompact;
    final isBusy = _activeMethod != null;

    return AuthPage(
      canvas: canvas,
      // Baris kanvas header : form : footer = 2 : 5 : 1, mengikuti tinggi isinya
      // (logo dan judul ~150 dp, form ~450 dp, ajakan daftar ~50 dp).
      ratio: const [2, 5, 1],
      children: [
        _LoginHeader(
          logoSize: compact ? 52 : 64,
          logoGap: compact ? 12 : 16,
          // Push/Pop: tombol kembali hanya ada kalau ada halaman sebelumnya.
          onBack: Navigator.canPop(context) ? () => Navigator.pop(context) : null,
        ),
        AuthCard(
          padding: compact ? 16 : 24,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'nama@email.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: compact ? 12 : 16),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Kata Sandi',
                  hint: 'Masukkan kata sandi',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Kata sandi wajib diisi' : null,
                ),
                SizedBox(height: compact ? 8 : 14),
                // Seperti Row spaceBetween, tapi "Lupa sandi?" turun ke baris
                // berikutnya kalau lebarnya tidak cukup.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _RememberMeToggle(
                        value: _rememberMe,
                        onChanged: (value) => setState(() => _rememberMe = value),
                      ),
                      AuthLinkButton(
                        label: 'Lupa sandi?',
                        fontSize: 13,
                        bold: false,
                        // GetX: buka dialog tanpa context
                        onPressed: () => Get.dialog(const _ForgotPasswordDialog()),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 14 : 20),
                AuthButton(
                  label: 'Masuk',
                  isLoading: _activeMethod == _LoginMethod.email,
                  onPressed: isBusy ? null : _loginWithEmail,
                ),
                SizedBox(height: compact ? 14 : 20),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AuthColors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'atau',
                        style: TextStyle(color: AuthColors.textMuted, fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: AuthColors.border)),
                  ],
                ),
                SizedBox(height: compact ? 12 : 16),
                _GoogleLoginButton(
                  isLoading: _activeMethod == _LoginMethod.google,
                  onPressed: isBusy ? null : _loginWithGoogle,
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Belum punya akun? ',
              style: TextStyle(color: AuthColors.textSecondary, fontSize: 14),
            ),
            // GetX: buka halaman daftar
            AuthLinkButton(label: 'Daftar', onPressed: () => Get.toNamed(AppRoutes.register)),
          ],
        ),
      ],
    );
  }
}

// ===================== WIDGET STATELESS =====================

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.logoSize, required this.logoGap, this.onBack});

  final double logoSize;
  final double logoGap;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Slot tombol kembali | identitas | slot kosong selebar tombol, supaya
    // identitas tetap persis di tengah.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: onBack == null
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AuthColors.textPrimary,
                  ),
                  tooltip: 'Kembali',
                  onPressed: onBack,
                ),
        ),
        Expanded(
          child: Column(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/icons/rivnet_logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: logoGap),
              const Text(
                'RivNet',
                style: TextStyle(
                  color: AuthColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(width: 28, height: 2, color: AuthColors.accent),
              const SizedBox(height: 10),
              const Text(
                'Masuk ke akun turnamen Anda',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuthColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

/// Kotak centang "Ingat saya" beserta teksnya sebagai satu area sentuh
/// setinggi minimal 44 dp.
class _RememberMeToggle extends StatelessWidget {
  const _RememberMeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // Pembaca layar membaca kotak dan teksnya sebagai satu checkbox.
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        focusColor: AuthColors.accent.withValues(alpha: 0.2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fokus keyboard cukup di InkWell, jadi Tab tidak berhenti dua kali.
              ExcludeFocus(
                child: SizedBox.square(
                  dimension: 22,
                  child: Checkbox(
                    value: value,
                    activeColor: AuthColors.accent,
                    checkColor: AuthColors.bg,
                    side: const BorderSide(color: AuthColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (checked) => onChanged(checked ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ingat saya',
                style: TextStyle(color: AuthColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLoginButton extends StatelessWidget {
  const _GoogleLoginButton({required this.onPressed, required this.isLoading});

  /// Spinner seukuran logo supaya tombol tidak bergeser saat loading.
  static const _logoSize = 18.0;

  /// Null = nonaktif karena ada login lain yang sedang berjalan.
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final labelColor = onPressed != null || isLoading
        ? AuthColors.textSecondary
        : AuthColors.textMuted;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: AuthColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox.square(
              dimension: _logoSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AuthColors.textSecondary,
              ),
            )
          else
            // Logo "G" resmi Google: warnanya tidak boleh diubah, jadi tidak
            // ikut diredupkan saat tombol nonaktif.
            Image.asset(
              'assets/icons/google(1).png',
              width: _logoSize,
              height: _logoSize,
              excludeFromSemantics: true,
              // Kalau file logo belum ada, sisakan ruang kosong seukuran logo.
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Logo Google tidak bisa dimuat: $error');
                return const SizedBox.square(dimension: _logoSize);
              },
            ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Masuk dengan Google',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== DIALOG (Stateful) =====================

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // TODO: panggil endpoint reset password sesungguhnya, mis.
    // AuthService.requestPasswordReset(_emailController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur reset kata sandi belum tersedia saat ini.')),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AuthColors.border),
      ),
      title: const Text(
        'Reset Kata Sandi',
        style: TextStyle(
          color: AuthColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email akun Anda. Kami akan mengirimkan tautan reset kata sandi.',
              style: TextStyle(color: AuthColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'nama@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Batal', style: TextStyle(color: AuthColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AuthColors.accent,
            foregroundColor: AuthColors.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Kirim Link'),
        ),
      ],
    );
  }
}
