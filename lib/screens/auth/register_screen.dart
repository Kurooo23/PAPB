import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

/// Palet yang sama dengan login_screen.dart, agar identitas visual RivNet
/// konsisten di seluruh alur auth. Sebaiknya dipindah ke satu file tema
/// bersama begitu tampilan ini disetujui.
class _RegisterPalette {
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
/// Contoh: perbandingan 1:8:1 berarti 1/10, 8/10, dan 1/10.
///
/// Kelas ini sama dengan yang ada di login_screen.dart, jadi bisa dipindah
/// ke satu file bersama bareng palet.
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

  /// Kanvas pendek: jarak di dalam kartu dirapatkan.
  final bool isCompact;

  /// Tinggi tiap baris. rows([1, 8, 1]) = tinggi x 1/10, x 8/10, x 1/10.
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

/// Jarak di dalam kartu form: normal atau rapat, tergantung kanvas.
class _RegisterSpacing {
  const _RegisterSpacing._({
    required this.passwordSideBySide,
    required this.cardPadding,
    required this.labelGap,
    required this.sectionGap,
    required this.fieldGap,
    required this.buttonGap,
    required this.avatarGap,
  });

  factory _RegisterSpacing.of(_Canvas canvas, {required double contentWidth}) {
    final isNarrow = contentWidth < 340;
    final compact = canvas.isCompact;

    return _RegisterSpacing._(
      // Kata sandi dan konfirmasinya baru sebaris kalau kolom isi cukup
      // untuk dua field (masing-masing sekitar 230 dp).
      passwordSideBySide: contentWidth >= 520,
      cardPadding: isNarrow || compact ? 16 : 20,
      labelGap: compact ? 8 : 10,
      sectionGap: compact ? 12 : 16,
      fieldGap: compact ? 10 : 14,
      buttonGap: compact ? 14 : 20,
      avatarGap: isNarrow ? 6 : 8,
    );
  }

  /// Kolom isi lebar: kata sandi dan konfirmasinya ditaruh sebaris.
  final bool passwordSideBySide;
  final double cardPadding;
  final double labelGap;
  final double sectionGap;
  final double fieldGap;
  final double buttonGap;
  final double avatarGap;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;

  Future<void> _handleRegister(
      String nickname,
      String email,
      String password,
      int avatarIndex,
      ) async {
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.register(
        nickname: nickname,
        email: email,
        password: password,
        avatarIndex: avatarIndex,
      );
      if (!mounted) return;

      final message = result['message'] ?? 'Pendaftaran berhasil. Silakan verifikasi email Anda.';
      _showFeedback(
        icon: Icons.check_circle_rounded,
        message: message,
        color: _RegisterPalette.success,
      );

      final userId = _extractUserId(result);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      // GetX: ganti halaman register dengan verify email + kirim data
      Get.offNamed(
        AppRoutes.verifyEmail,
        arguments: {'email': email, 'userId': userId},
      );
    } catch (e) {
      if (!mounted) return;
      _showFeedback(
        icon: Icons.error_outline_rounded,
        message: e.toString().replaceFirst('Exception: ', ''),
        color: _RegisterPalette.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _extractUserId(Map<String, dynamic> result) {
    final data = result['data'];
    if (data is! Map) return null;
    final user = data['user'];
    if (user is Map && user['id_user'] is String) {
      return user['id_user'] as String;
    }
    if (data['user_id'] is String) return data['user_id'] as String;
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
        backgroundColor: _RegisterPalette.surface,
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
                style: const TextStyle(color: _RegisterPalette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvas = _Canvas.of(context);
    // Baris kanvas: header : form : footer = 1 : 8 : 1, mengikuti isinya.
    // Header dan footer cuma satu baris tombol (sekitar 50 dp), sedangkan
    // form butuh sekitar 610 dp, jadi baris tengah dapat porsi terbesar.
    final [headerHeight, formHeight, footerHeight] =
    canvas.rows(const [1, 8, 1]);
    // Kolom kanvas: margin : isi : margin, dipilih dari lebar layar.
    final columns = canvas.formColumns();

    return Scaffold(
      backgroundColor: _RegisterPalette.bg,
      body: SafeArea(
        // Tinggi kanvas = tinggi layar, jadi tanpa keyboard halaman tidak
        // bisa digeser. Saat keyboard muncul, kanvas bisa discroll.
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              // Baris 1: tombol kembali dan judul.
              _CanvasRow(
                height: headerHeight,
                columns: columns,
                child: const _RegisterHeader(),
              ),
              // Baris 2: form.
              _CanvasRow(
                height: formHeight,
                columns: columns,
                child: _RegisterForm(
                  spacing: _RegisterSpacing.of(canvas, contentWidth: columns[1]),
                  isLoading: _isLoading,
                  onSubmit: _handleRegister,
                ),
              ),
              // Baris 3: ajakan masuk.
              _CanvasRow(
                height: footerHeight,
                columns: columns,
                child: const _LoginPrompt(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _RegisterPalette.textPrimary,
            size: 20,
          ),
          style: IconButton.styleFrom(
            backgroundColor: _RegisterPalette.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'Buat Akun Baru',
            style: TextStyle(
              color: _RegisterPalette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    // Wrap berperilaku seperti Row, tapi kalau lebarnya tidak cukup, tombol
    // turun ke baris kedua alih-alih terpotong di luar layar.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        const Text(
          'Sudah memiliki akun turnamen?',
          style: TextStyle(color: _RegisterPalette.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 44),
            foregroundColor: _RegisterPalette.accent,
          ),
          child: const Text(
            'Masuk Sekarang',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({
    required this.spacing,
    required this.isLoading,
    required this.onSubmit,
  });

  final _RegisterSpacing spacing;
  final bool isLoading;
  final void Function(
      String nickname,
      String email,
      String password,
      int avatarIndex,
      ) onSubmit;

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  static const _avatarIcons = [
    Icons.sports_esports_rounded,
    Icons.shield_rounded,
    Icons.military_tech_rounded,
    Icons.bolt_rounded,
    Icons.psychology_rounded,
    Icons.local_fire_department_rounded,
  ];

  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _selectedAvatarIndex = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(
      _nicknameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _selectedAvatarIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spacing;

    final passwordField = _FormField(
      controller: _passwordController,
      label: 'Kata Sandi',
      hint: 'Masukkan kata sandi',
      helperText: '8+ karakter: huruf besar, huruf kecil, angka, simbol (@ # \$ ! _ -)',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        tooltip: _obscurePassword ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _RegisterPalette.textMuted,
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) return 'Kata sandi wajib diisi';
        if (password.length < 8) return 'Kata sandi minimal 8 karakter';
        if (!RegExp(r'[A-Z]').hasMatch(password)) {
          return 'Kata sandi harus memiliki minimal 1 huruf besar';
        }
        if (!RegExp(r'[a-z]').hasMatch(password)) {
          return 'Kata sandi harus memiliki minimal 1 huruf kecil';
        }
        if (!RegExp(r'[0-9]').hasMatch(password)) {
          return 'Kata sandi harus memiliki minimal 1 angka';
        }
        if (!RegExp(r'[@#$!_-]').hasMatch(password)) {
          return 'Kata sandi harus memiliki minimal 1 simbol (@ # \$ ! _ -)';
        }
        return null;
      },
    );

    final confirmField = _FormField(
      controller: _confirmPasswordController,
      label: 'Konfirmasi Kata Sandi',
      hint: 'Ulangi kata sandi',
      icon: Icons.lock_reset_rounded,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      suffixIcon: IconButton(
        tooltip: _obscureConfirmPassword
            ? 'Tampilkan kata sandi'
            : 'Sembunyikan kata sandi',
        icon: Icon(
          _obscureConfirmPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _RegisterPalette.textMuted,
          size: 20,
        ),
        onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Konfirmasi kata sandi wajib diisi';
        }
        if (value != _passwordController.text) {
          return 'Kata sandi konfirmasi tidak cocok';
        }
        return null;
      },
    );

    return Container(
      padding: EdgeInsets.all(s.cardPadding),
      decoration: BoxDecoration(
        color: _RegisterPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _RegisterPalette.border),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Avatar Gamer',
              style: TextStyle(
                color: _RegisterPalette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: s.labelGap),
            _AvatarPicker(
              icons: _avatarIcons,
              selectedIndex: _selectedAvatarIndex,
              gap: s.avatarGap,
              onSelect: (index) => setState(() => _selectedAvatarIndex = index),
            ),
            SizedBox(height: s.sectionGap),
            _FormField(
              controller: _nicknameController,
              label: 'Nickname Game',
              hint: 'ShadowGamer',
              helperText: '3-20 karakter: huruf, angka, atau _',
              icon: Icons.badge_outlined,
              validator: (value) {
                final nickname = value?.trim() ?? '';
                if (nickname.isEmpty) return 'Nickname wajib diisi';
                if (nickname.length < 3) return 'Nickname minimal 3 karakter';
                if (nickname.length > 20) return 'Nickname maksimal 20 karakter';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(nickname)) {
                  return 'Nickname hanya boleh berisi huruf, angka, atau underscore';
                }
                return null;
              },
            ),
            SizedBox(height: s.fieldGap),
            _FormField(
              controller: _emailController,
              label: 'Email',
              hint: 'nama@email.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email wajib diisi';
                if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
                  return 'Masukkan alamat email yang valid';
                }
                return null;
              },
            ),
            SizedBox(height: s.fieldGap),
            // Layar lebar: kata sandi dan konfirmasinya sebaris (Row).
            // HP: ditumpuk supaya tiap field tetap cukup lebar.
            if (s.passwordSideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: passwordField),
                  SizedBox(width: s.fieldGap),
                  Expanded(child: confirmField),
                ],
              )
            else ...[
              passwordField,
              SizedBox(height: s.fieldGap),
              confirmField,
            ],
            SizedBox(height: s.buttonGap),
            ElevatedButton(
              onPressed: widget.isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                // Lebar penuh, tinggi minimal 48 dp, tapi boleh bertambah
                // kalau font sistem diperbesar.
                minimumSize: const Size.fromHeight(48),
                backgroundColor: _RegisterPalette.accent,
                foregroundColor: _RegisterPalette.bg,
                disabledBackgroundColor:
                _RegisterPalette.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black87,
                ),
              )
                  : const Text(
                'Daftar Akun',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.icons,
    required this.selectedIndex,
    required this.gap,
    required this.onSelect,
  });

  /// Batas bawah area sentuh, ukuran asli di desain, dan jarak terkecil.
  static const _minSize = 44.0;
  static const _maxSize = 54.0;
  static const _minGap = 4.0;

  final List<IconData> icons;
  final int selectedIndex;
  final double gap;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = icons.length;
        double fit(double spacing) =>
            ((constraints.maxWidth - spacing * (count - 1)) / count)
                .floorToDouble();

        // Coba jarak normal dulu. Kalau avatar jadi di bawah 44 dp, jaraknya
        // dirapatkan. Kalau masih kurang, avatar turun ke baris kedua.
        var spacing = gap;
        var fitted = fit(spacing);
        if (fitted < _minSize) {
          spacing = _minGap;
          fitted = fit(spacing);
        }
        final size = fitted.clamp(_minSize, _maxSize).toDouble();

        final options = <Widget>[
          for (var i = 0; i < count; i++)
            _AvatarOption(
              icon: icons[i],
              label: 'Avatar ${i + 1} dari $count',
              size: size,
              isSelected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
        ];

        if (fitted < _minSize) {
          return Wrap(spacing: gap, runSpacing: gap, children: options);
        }

        return Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              options[i],
            ],
          ],
        );
      },
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.icon,
    required this.label,
    required this.size,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double size;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: isSelected
            ? _RegisterPalette.accent.withValues(alpha: 0.15)
            : _RegisterPalette.bg,
        shape: CircleBorder(
          side: BorderSide(
            color: isSelected ? _RegisterPalette.accent : _RegisterPalette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          // Penanda fokus saat avatar dipilih lewat keyboard (Tab).
          focusColor: _RegisterPalette.accent.withValues(alpha: 0.3),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: isSelected
                  ? _RegisterPalette.accent
                  : _RegisterPalette.textMuted,
              size: 24,
            ),
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
    this.helperText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helperText;
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
            color: _RegisterPalette.textSecondary,
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
          style: const TextStyle(color: _RegisterPalette.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperMaxLines: 3,
            // Bawaan Flutter cuma 1 baris, jadi pesan panjang terpotong.
            errorMaxLines: 2,
            helperStyle: const TextStyle(color: _RegisterPalette.textMuted, fontSize: 11.5),
            hintStyle: const TextStyle(color: _RegisterPalette.textMuted, fontSize: 14),
            prefixIcon: Icon(icon, color: _RegisterPalette.textMuted, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _RegisterPalette.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterPalette.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterPalette.error),
            ),
            // Tanpa ini, field yang error dan sedang fokus memakai merah
            // bawaan tema, bukan merah palet.
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterPalette.error, width: 1.5),
            ),
            errorStyle: const TextStyle(color: _RegisterPalette.error, fontSize: 12),
          ),
        ),
      ],
    );
  }
}