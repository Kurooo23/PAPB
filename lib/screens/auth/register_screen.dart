import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import 'widgets/custom_text_field.dart';
import 'widgets/glass_card.dart';
import 'widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _selectedAvatarIndex = 0;
  bool _isLoading = false;

  // Daftar ikon avatar gamer yang bisa dipilih
  final List<IconData> _avatarIcons = [
    Icons.sports_esports_rounded,
    Icons.shield_rounded,
    Icons.military_tech_rounded,
    Icons.bolt_rounded,
    Icons.psychology_rounded,
    Icons.local_fire_department_rounded,
  ];

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final nickname = _nicknameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final result = await AuthService.register(
        nickname: nickname,
        email: email,
        password: password,
        avatarIndex: _selectedAvatarIndex,
      );

      if (!mounted) return;

      final message = result['message'] ?? 'Pendaftaran berhasil! Silakan masuk.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        Navigator.pop(context); // Kembali ke halaman Login
      });
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Orbs background
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orbPurple.withValues(alpha: 0.25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orbPurple.withValues(alpha: 0.25),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orbCyan.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orbCyan.withValues(alpha: 0.2),
                    blurRadius: 110,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      // Tombol Back & Header
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Buat Akun Baru',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar Selector
                              const Text(
                                'Pilih Avatar Gamer',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 60,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _avatarIcons.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final isSelected = _selectedAvatarIndex == index;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedAvatarIndex = index;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: isSelected
                                              ? const LinearGradient(
                                            colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                              : null,
                                          color: isSelected ? null : const Color(0xFF252538),
                                          border: Border.all(
                                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            )
                                          ]
                                              : null,
                                        ),
                                        child: Icon(
                                          _avatarIcons[index],
                                          color: isSelected ? Colors.white : AppColors.textMuted,
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Nickname
                              CustomTextField(
                                controller: _nicknameController,
                                label: 'Nickname Game',
                                hint: 'ShadowGamer',
                                prefixIcon: Icons.badge_outlined,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Nickname wajib diisi';
                                  }
                                  if (val.trim().length < 3) {
                                    return 'Nickname minimal 3 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Email
                              CustomTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'gamer@komunitas.com',
                                prefixIcon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Email wajib diisi';
                                  }
                                  if (!val.trim().contains('@')) {
                                    return 'Masukkan alamat email yang valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Kata Sandi',
                                hint: 'Minimal 6 karakter',
                                prefixIcon: Icons.lock_outline_rounded,
                                isPassword: true,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Kata sandi wajib diisi';
                                  }
                                  if (val.length < 6) {
                                    return 'Kata sandi minimal 6 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password
                              CustomTextField(
                                controller: _confirmPasswordController,
                                label: 'Konfirmasi Kata Sandi',
                                hint: 'Ulangi kata sandi',
                                prefixIcon: Icons.lock_reset_rounded,
                                isPassword: true,
                                textInputAction: TextInputAction.done,
                                validator: (val) {
                                  if (val != _passwordController.text) {
                                    return 'Kata sandi konfirmasi tidak cocok';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Button Register
                              GradientButton(
                                text: 'Daftar Akun Turnamen',
                                icon: Icons.person_add_alt_1_rounded,
                                isLoading: _isLoading,
                                onPressed: _handleRegister,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Link Kembali ke Login
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Sudah memiliki akun turnamen? ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Masuk Sekarang',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
