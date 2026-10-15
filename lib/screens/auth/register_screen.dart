import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.register(
        nickname: _nicknameController.text.trim(),
        email: email,
        password: _passwordController.text,
        avatarIndex: _selectedAvatarIndex,
      );
      if (!mounted) return;

      context.showAuthFeedback(
        icon: Icons.check_circle_rounded,
        message: result['message'] ?? 'Pendaftaran berhasil. Silakan verifikasi email Anda.',
        color: AuthColors.success,
      );

      // id user bisa ada di data.user.id_user atau data.user_id.
      final data = result['data'] is Map ? result['data'] as Map : const {};
      final user = data['user'] is Map ? data['user'] as Map : const {};
      final userId = [user['id_user'], data['user_id']].whereType<String>().firstOrNull;

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      // GetX: ganti halaman register dengan verify email + kirim data
      Get.offNamed(AppRoutes.verifyEmail, arguments: {'email': email, 'userId': userId});
    } catch (e) {
      if (!mounted) return;
      context.showAuthFeedback(
        icon: Icons.error_outline_rounded,
        message: e.toString().replaceFirst('Exception: ', ''),
        color: AuthColors.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================== VALIDASI =====================

  String? _validateNickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return 'Nickname wajib diisi';
    if (nickname.length < 3) return 'Nickname minimal 3 karakter';
    if (nickname.length > 20) return 'Nickname maksimal 20 karakter';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(nickname)) {
      return 'Nickname hanya boleh berisi huruf, angka, atau underscore';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Kata sandi wajib diisi';
    if (password.length < 8) return 'Kata sandi minimal 8 karakter';
    // Aturan: pola yang wajib ada -> pesan kalau tidak ada.
    const rules = {
      r'[A-Z]': 'Kata sandi harus memiliki minimal 1 huruf besar',
      r'[a-z]': 'Kata sandi harus memiliki minimal 1 huruf kecil',
      r'[0-9]': 'Kata sandi harus memiliki minimal 1 angka',
      r'[@#$!_-]': 'Kata sandi harus memiliki minimal 1 simbol (@ # \$ ! _ -)',
    };
    for (final rule in rules.entries) {
      if (!RegExp(rule.key).hasMatch(password)) return rule.value;
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
    if (value != _passwordController.text) return 'Kata sandi konfirmasi tidak cocok';
    return null;
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    final canvas = AuthCanvas.of(context);
    final compact = canvas.isCompact;
    final contentWidth = canvas.formColumns[1];
    final isNarrow = contentWidth < 340;
    final fieldGap = compact ? 10.0 : 14.0;

    final passwordField = AuthTextField(
      controller: _passwordController,
      label: 'Kata Sandi',
      hint: 'Masukkan kata sandi',
      helperText: '8+ karakter: huruf besar, huruf kecil, angka, simbol (@ # \$ ! _ -)',
      icon: Icons.lock_outline_rounded,
      isPassword: true,
      validator: _validatePassword,
    );
    final confirmField = AuthTextField(
      controller: _confirmPasswordController,
      label: 'Konfirmasi Kata Sandi',
      hint: 'Ulangi kata sandi',
      icon: Icons.lock_reset_rounded,
      isPassword: true,
      textInputAction: TextInputAction.done,
      validator: _validateConfirm,
    );

    return AuthPage(
      canvas: canvas,
      // Baris kanvas header : form : footer = 1 : 8 : 1. Header dan footer cuma
      // satu baris tombol (~50 dp), form butuh ~610 dp.
      ratio: const [1, 8, 1],
      children: [
        const _RegisterHeader(),
        AuthCard(
          padding: isNarrow || compact ? 16 : 20,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Avatar Gamer',
                  style: TextStyle(
                    color: AuthColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),
                _AvatarPicker(
                  icons: _avatarIcons,
                  selectedIndex: _selectedAvatarIndex,
                  gap: isNarrow ? 6 : 8,
                  onSelect: (index) => setState(() => _selectedAvatarIndex = index),
                ),
                SizedBox(height: compact ? 12 : 16),
                AuthTextField(
                  controller: _nicknameController,
                  label: 'Nickname Game',
                  hint: 'ShadowGamer',
                  helperText: '3-20 karakter: huruf, angka, atau _',
                  icon: Icons.badge_outlined,
                  validator: _validateNickname,
                ),
                SizedBox(height: fieldGap),
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'nama@email.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: fieldGap),
                // Kolom isi >= 520 dp: kata sandi dan konfirmasinya sebaris.
                // HP: ditumpuk supaya tiap field tetap cukup lebar.
                if (contentWidth >= 520)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: passwordField),
                      SizedBox(width: fieldGap),
                      Expanded(child: confirmField),
                    ],
                  )
                else ...[
                  passwordField,
                  SizedBox(height: fieldGap),
                  confirmField,
                ],
                SizedBox(height: compact ? 14 : 20),
                AuthButton(
                  label: 'Daftar Akun',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _register,
                ),
              ],
            ),
          ),
        ),
        // Wrap: kalau lebarnya tidak cukup, tombol turun ke baris kedua.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            const Text(
              'Sudah memiliki akun turnamen?',
              style: TextStyle(color: AuthColors.textSecondary, fontSize: 14),
            ),
            // Push/Pop: kembali ke halaman login
            AuthLinkButton(label: 'Masuk Sekarang', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ],
    );
  }
}

// ===================== WIDGET STATELESS =====================

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
            color: AuthColors.textPrimary,
            size: 20,
          ),
          style: IconButton.styleFrom(
            backgroundColor: AuthColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'Buat Akun Baru',
            style: TextStyle(
              color: AuthColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
            ((constraints.maxWidth - spacing * (count - 1)) / count).floorToDouble();

        // Coba jarak normal dulu. Kalau avatar jadi di bawah 44 dp, jaraknya
        // dirapatkan. Kalau masih kurang, avatar turun ke baris kedua.
        var spacing = gap;
        var fitted = fit(spacing);
        if (fitted < _minSize) {
          spacing = _minGap;
          fitted = fit(spacing);
        }
        final size = fitted.clamp(_minSize, _maxSize);

        final options = [
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
        color: isSelected ? AuthColors.accent.withValues(alpha: 0.15) : AuthColors.bg,
        shape: CircleBorder(
          side: BorderSide(
            color: isSelected ? AuthColors.accent : AuthColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          // Penanda fokus saat avatar dipilih lewat keyboard (Tab).
          focusColor: AuthColors.accent.withValues(alpha: 0.3),
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              color: isSelected ? AuthColors.accent : AuthColors.textMuted,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
