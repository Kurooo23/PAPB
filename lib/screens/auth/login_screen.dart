import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/database_helper.dart';
import '../../services/auth_service.dart';
import '../../data/services/google_sign_in_service.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';

/// Palet layar login: dark neutral + satu aksen emas (peringkat/trofi
/// turnamen). Sengaja bukan gradient biru-ungu/glow berlapis (lihat audit).
class _LoginPalette {
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

/// Kanvas = area layar di luar status bar dan tombol navigasi, dihitung
/// dari MediaQuery. Kanvas dibagi dengan perbandingan yang disesuaikan
/// dengan isinya: tinggi untuk baris, lebar untuk kolom.
/// Contoh: perbandingan 2:5:1 berarti 2/8, 5/8, dan 1/8.
///
/// Kelas ini sama dengan yang ada di register_screen.dart, jadi bisa
/// dipindah ke satu file bersama bareng palet.
class _Canvas {
  const _Canvas._({
    required this.width,
    required this.height,
    required this.isCompact,
  });

  factory _Canvas.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // viewPadding tidak berubah saat keyboard muncul, jadi ukuran kanvas
    // tetap stabil dan baris tidak ikut menyusut.
    final systemBars = MediaQuery.viewPaddingOf(context);
    // Font sistem yang diperbesar bikin isi lebih tinggi, jadi kanvas
    // diperlakukan seolah lebih pendek.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final width = screen.width - systemBars.horizontal;
    final height = screen.height - systemBars.vertical;

    return _Canvas._(
      width: width,
      height: height,
      isCompact: height / textScale < 760,
    );
  }

  final double width;
  final double height;

  /// Kanvas pendek: logo dan jarak di dalam kartu dirapatkan.
  final bool isCompact;

  /// Tinggi tiap baris. rows([2, 5, 1]) = tinggi x 2/8, x 5/8, x 1/8.
  List<double> rows(List<int> ratio) => _split(height, ratio);

  /// Lebar tiap kolom. columns([1, 18, 1]) = lebar x 1/20, x 18/20, x 1/20.
  List<double> columns(List<int> ratio) => _split(width, ratio);

  /// Kolom untuk halaman form (margin : isi : margin). Perbandingannya
  /// dipilih dari lebar kanvas supaya kolom isi tetap selebar yang nyaman
  /// untuk form: hampir selebar layar di HP, sekitar 360 sampai 600 dp di
  /// layar yang lebih lebar.
  List<double> formColumns() {
    final List<int> ratio;
    if (width < 600) {
      ratio = const [1, 18, 1]; // HP: isi 90% lebar layar.
    } else if (width < 840) {
      ratio = const [1, 3, 1]; // Isi 360 sampai 503 dp.
    } else if (width < 1200) {
      ratio = const [1, 2, 1]; // Isi 420 sampai 599 dp.
    } else {
      ratio = const [1, 1, 1]; // Isi mulai 400 dp.
    }
    return columns(ratio);
  }

  // Dibulatkan ke bawah supaya jumlahnya tidak pernah melebihi layar.
  // Kelebihan 0,0001 dp saja sudah bikin halaman bisa digeser.
  static List<double> _split(double total, List<int> ratio) {
    final parts = ratio.fold<int>(0, (sum, part) => sum + part);
    return [for (final part in ratio) (total * part / parts).floorToDouble()];
  }
}

/// Satu baris kanvas: Row berisi tiga kolom (kiri, tengah, kanan) selebar
/// hasil perbandingan. Isi ditaruh di kolom tengah, di tengah baris.
///
/// [height] adalah tinggi minimal. Baris baru memanjang kalau isinya lebih
/// tinggi (misalnya font sistem sangat besar), jadi tidak pernah overflow.
class _CanvasRow extends StatelessWidget {
  const _CanvasRow({
    required this.height,
    required this.columns,
    required this.child,
  });

  final double height;
  final List<double> columns;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: columns[0]),
          SizedBox(width: columns[1], child: child),
          SizedBox(width: columns[2]),
        ],
      ),
    );
  }
}

/// Ukuran logo dan jarak di dalam kartu: normal atau rapat, tergantung
/// kanvas. Nilai normal sama dengan desain sebelumnya.
class _LoginSpacing {
  const _LoginSpacing._({
    required this.logoSize,
    required this.logoGap,
    required this.cardPadding,
    required this.fieldGap,
    required this.optionsGap,
    required this.buttonGap,
    required this.dividerGap,
    required this.altGap,
  });

  factory _LoginSpacing.of(_Canvas canvas) {
    final compact = canvas.isCompact;

    return _LoginSpacing._(
      logoSize: compact ? 52 : 64,
      logoGap: compact ? 12 : 16,
      cardPadding: compact ? 16 : 24,
      fieldGap: compact ? 12 : 16,
      optionsGap: compact ? 8 : 14,
      buttonGap: compact ? 14 : 20,
      dividerGap: compact ? 14 : 20,
      altGap: compact ? 12 : 16,
    );
  }

  final double logoSize;
  final double logoGap;
  final double cardPadding;
  final double fieldGap;
  final double optionsGap;
  final double buttonGap;
  final double dividerGap;
  final double altGap;
}

/// Metode login yang sedang berjalan.
enum _LoginMethod { email, google }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Selama ada login yang berjalan, kedua tombol login nonaktif supaya
  /// tidak ada dua proses login bersamaan.
  _LoginMethod? _activeMethod;

  Future<void> _handleLogin(
      String email,
      String password,
      bool rememberMe,
      ) {
    return _runLogin(
      _LoginMethod.email,
          () => AuthService.login(email: email, password: password),
    );
  }

  Future<void> _handleGoogleLogin() {
    return _runLogin(_LoginMethod.google, () async {
      final idToken = await GoogleSignInService.requestIdToken();
      // null berarti pemilih akun ditutup pengguna: bukan error, cukup berhenti.
      if (idToken == null) return null;
      return AuthService.loginWithGoogle(idToken: idToken);
    });
  }

  /// Alur yang sama untuk semua metode login: minta hasil ke server, simpan
  /// token dan sesi, lalu masuk ke beranda.
  Future<void> _runLogin(
      _LoginMethod method,
      Future<dynamic> Function() request,
      ) async {
    setState(() => _activeMethod = method);

    try {
      final result = await request();
      if (!mounted || result == null) return;

      final token = _extractToken(result);
      if (token == null || token.isEmpty) {
        throw Exception('Token login tidak diterima dari server.');
      }
      await const FlutterSecureStorage().write(key: 'user_token', value: token);

      final user = _extractUser(result);
      if (user == null) {
        throw Exception('Data pengguna tidak diterima dari server.');
      }

      await DatabaseHelper.instance.saveUserSession(user, token: token);
      if (!mounted) return;

      _showFeedback(
        icon: Icons.check_circle_rounded,
        message: 'Login berhasil. Selamat datang di Arena Turnamen.',
        color: _LoginPalette.success,
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      // Akun Google selalu sudah terverifikasi, jadi pesan verifikasi email
      // hanya berlaku untuk login email.
      final isUnverified = method == _LoginMethod.email &&
          message.toLowerCase().contains('verifikasi');

      _showFeedback(
        icon: isUnverified
            ? Icons.mark_email_unread_rounded
            : Icons.error_outline_rounded,
        message: isUnverified
            ? 'Verifikasi email Anda terlebih dahulu. Link verifikasi telah dikirim ulang.'
            : message,
        color: isUnverified ? _LoginPalette.accent : _LoginPalette.error,
      );
    } finally {
      if (mounted) setState(() => _activeMethod = null);
    }
  }

  String? _extractToken(dynamic result) {
    if (result['token'] is String) return result['token'] as String;
    if (result['data'] is Map && (result['data'] as Map)['token'] is String) {
      return (result['data'] as Map)['token'] as String;
    }
    return null;
  }

  Map<String, dynamic>? _extractUser(dynamic result) {
    if (result['user'] is Map) {
      return Map<String, dynamic>.from(result['user'] as Map);
    }
    if (result['data'] is Map) {
      final data = result['data'] as Map;
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
    }
    return null;
  }

  void _showFeedback({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _LoginPalette.surface,
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
                style: const TextStyle(color: _LoginPalette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openForgotPasswordDialog() {
    showDialog(context: context, builder: (_) => const _ForgotPasswordDialog());
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvas = _Canvas.of(context);
    final spacing = _LoginSpacing.of(canvas);
    // Baris kanvas: header : form : footer = 2 : 5 : 1, mengikuti isinya.
    // Logo dan judul sekitar 150 dp, form sekitar 450 dp, ajakan daftar
    // sekitar 50 dp. Dengan perbandingan ini sisa ruang di atas dan bawah
    // tiap baris kurang lebih sama.
    final [headerHeight, formHeight, footerHeight] =
    canvas.rows(const [2, 5, 1]);
    // Kolom kanvas: margin : isi : margin, dipilih dari lebar layar.
    final columns = canvas.formColumns();
    final canGoBack = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: _LoginPalette.bg,
      body: SafeArea(
        // Tinggi kanvas = tinggi layar, jadi tanpa keyboard halaman tidak
        // bisa digeser. Saat keyboard muncul, kanvas bisa discroll.
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              // Baris 1: identitas RivNet, plus tombol kembali kalau ada.
              _CanvasRow(
                height: headerHeight,
                columns: columns,
                child: _LoginHeader(
                  logoSize: spacing.logoSize,
                  logoGap: spacing.logoGap,
                  onBack: canGoBack ? () => Navigator.pop(context) : null,
                ),
              ),
              // Baris 2: form login.
              _CanvasRow(
                height: formHeight,
                columns: columns,
                child: _LoginForm(
                  spacing: spacing,
                  activeMethod: _activeMethod,
                  onSubmit: _handleLogin,
                  onGoogleLogin: _handleGoogleLogin,
                  onForgotPassword: _openForgotPasswordDialog,
                ),
              ),
              // Baris 3: ajakan daftar.
              _CanvasRow(
                height: footerHeight,
                columns: columns,
                child: _RegisterPrompt(onRegister: _openRegister),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({
    required this.logoSize,
    required this.logoGap,
    this.onBack,
  });

  final double logoSize;
  final double logoGap;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Row tiga bagian: slot tombol kembali, identitas, dan slot kosong
    // selebar tombol supaya identitas tetap persis di tengah.
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
              color: _LoginPalette.textPrimary,
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
                  color: _LoginPalette.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(width: 28, height: 2, color: _LoginPalette.accent),
              const SizedBox(height: 10),
              const Text(
                'Masuk ke akun turnamen Anda',
                textAlign: TextAlign.center,
                style: TextStyle(color: _LoginPalette.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({
    required this.spacing,
    required this.activeMethod,
    required this.onSubmit,
    required this.onGoogleLogin,
    required this.onForgotPassword,
  });

  final _LoginSpacing spacing;

  /// Metode login yang sedang berjalan, null kalau tidak ada.
  final _LoginMethod? activeMethod;
  final void Function(String email, String password, bool rememberMe) onSubmit;
  final VoidCallback onGoogleLogin;
  final VoidCallback onForgotPassword;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(
      _emailController.text.trim(),
      _passwordController.text,
      _rememberMe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spacing;
    final isBusy = widget.activeMethod != null;

    return Container(
      padding: EdgeInsets.all(s.cardPadding),
      decoration: BoxDecoration(
        color: _LoginPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LoginPalette.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormField(
              controller: _emailController,
              label: 'Email',
              hint: 'nama@email.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                if (!val.trim().contains('@')) return 'Masukkan alamat email yang valid';
                return null;
              },
            ),
            SizedBox(height: s.fieldGap),
            _FormField(
              controller: _passwordController,
              label: 'Kata Sandi',
              hint: 'Masukkan kata sandi',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _LoginPalette.textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Kata sandi wajib diisi';
                return null;
              },
            ),
            SizedBox(height: s.optionsGap),
            // Wrap berperilaku seperti Row dengan spaceBetween, tapi kalau
            // lebarnya tidak cukup (font sangat besar), "Lupa sandi?" turun
            // ke baris berikutnya alih-alih overflow.
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
                  TextButton(
                    onPressed: widget.onForgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      foregroundColor: _LoginPalette.accent,
                    ),
                    child: const Text(
                      'Lupa sandi?',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: s.buttonGap),
            ElevatedButton(
              onPressed: isBusy ? null : _submit,
              style: ElevatedButton.styleFrom(
                // Lebar penuh, tinggi minimal 48 dp, tapi boleh bertambah
                // kalau font sistem diperbesar.
                minimumSize: const Size.fromHeight(48),
                backgroundColor: _LoginPalette.accent,
                foregroundColor: _LoginPalette.bg,
                disabledBackgroundColor:
                _LoginPalette.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: widget.activeMethod == _LoginMethod.email
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black87,
                ),
              )
                  : const Text(
                'Masuk',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            SizedBox(height: s.dividerGap),
            const Row(
              children: [
                Expanded(child: Divider(color: _LoginPalette.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'atau',
                    style: TextStyle(color: _LoginPalette.textMuted, fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: _LoginPalette.border)),
              ],
            ),
            SizedBox(height: s.altGap),
            _GoogleLoginButton(
              isLoading: widget.activeMethod == _LoginMethod.google,
              onPressed: isBusy ? null : widget.onGoogleLogin,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak centang "Ingat saya" beserta teksnya sebagai satu area sentuh
/// setinggi minimal 44 dp. Sebelumnya hanya kotak 22 dp yang bisa ditekan.
class _RememberMeToggle extends StatelessWidget {
  const _RememberMeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics: pembaca layar membaca kotak dan teksnya sebagai satu
    // checkbox berlabel "Ingat saya".
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        focusColor: _LoginPalette.accent.withValues(alpha: 0.2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fokus keyboard cukup di InkWell, jadi Tab tidak berhenti
              // dua kali di kontrol yang sama.
              ExcludeFocus(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: Checkbox(
                    value: value,
                    activeColor: _LoginPalette.accent,
                    checkColor: _LoginPalette.bg,
                    side: const BorderSide(color: _LoginPalette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (checked) => onChanged(checked ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ingat saya',
                style: TextStyle(
                  color: _LoginPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _LoginPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          style: const TextStyle(color: _LoginPalette.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _LoginPalette.textMuted, fontSize: 14),
            // Bawaan Flutter cuma 1 baris, jadi pesan panjang terpotong.
            errorMaxLines: 2,
            prefixIcon: Icon(icon, color: _LoginPalette.textMuted, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _LoginPalette.bg,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LoginPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LoginPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LoginPalette.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LoginPalette.error),
            ),
            // Tanpa ini, field yang error dan sedang fokus memakai merah
            // bawaan tema, bukan merah palet.
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LoginPalette.error, width: 1.5),
            ),
            errorStyle: const TextStyle(color: _LoginPalette.error, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _GoogleLoginButton extends StatelessWidget {
  const _GoogleLoginButton({required this.onPressed, required this.isLoading});

  /// null berarti nonaktif karena ada login lain yang sedang berjalan.
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Teks redup hanya saat nonaktif. WCAG tidak mensyaratkan kontras untuk
    // kontrol yang sedang nonaktif.
    final labelColor = onPressed != null || isLoading
        ? _LoginPalette.textSecondary
        : _LoginPalette.textMuted;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: _LoginPalette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _LoginPalette.textSecondary,
              ),
            )
          else
            const Icon(
              Icons.person_outline_rounded,
              color: _LoginPalette.textMuted,
              size: 20,
            ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Masuk dengan Google',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Belum punya akun? ',
          style: TextStyle(color: _LoginPalette.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: onRegister,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 44),
            foregroundColor: _LoginPalette.accent,
          ),
          child: const Text(
            'Daftar',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

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
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur reset kata sandi belum tersedia saat ini.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _LoginPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _LoginPalette.border),
      ),
      title: const Text(
        'Reset Kata Sandi',
        style: TextStyle(
          color: _LoginPalette.textPrimary,
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
              style: TextStyle(color: _LoginPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _FormField(
              controller: _emailController,
              label: 'Email',
              hint: 'nama@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                if (!val.trim().contains('@')) return 'Masukkan alamat email yang valid';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: _LoginPalette.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _LoginPalette.accent,
            foregroundColor: _LoginPalette.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Kirim Link'),
        ),
      ],
    );
  }
}