import 'package:flutter/material.dart';

// Widget bersama untuk halaman login, daftar, dan verifikasi email.

/// Palet auth: dark neutral + satu aksen emas (peringkat/trofi turnamen).
class AuthColors {
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

/// Kanvas = area layar di luar status bar dan tombol navigasi (MediaQuery).
/// Kanvas dibagi dengan perbandingan, misalnya rows([2, 5, 1]) berarti
/// tinggi x 2/8, x 5/8, dan x 1/8.
class AuthCanvas {
  const AuthCanvas._(this.width, this.height, this.isCompact);

  factory AuthCanvas.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // viewPadding tidak berubah saat keyboard muncul, jadi kanvas tetap stabil.
    final systemBars = MediaQuery.viewPaddingOf(context);
    // Font sistem yang diperbesar: kanvas diperlakukan seolah lebih pendek.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = screen.height - systemBars.vertical;
    return AuthCanvas._(
      screen.width - systemBars.horizontal,
      height,
      height / textScale < 760,
    );
  }

  final double width;
  final double height;

  /// Kanvas pendek: logo dan jarak di dalam kartu dirapatkan.
  final bool isCompact;

  List<double> rows(List<int> ratio) => _split(height, ratio);

  /// Kolom margin : isi : margin. Isi hampir selebar layar di HP, sekitar
  /// 360 sampai 600 dp di layar yang lebih lebar.
  List<double> get formColumns {
    final ratio = width < 600
        ? const [1, 18, 1]
        : width < 840
            ? const [1, 3, 1]
            : width < 1200
                ? const [1, 2, 1]
                : const [1, 1, 1];
    return _split(width, ratio);
  }

  // Dibulatkan ke bawah supaya jumlahnya tidak pernah melebihi layar.
  static List<double> _split(double total, List<int> ratio) {
    final parts = ratio.fold<int>(0, (sum, part) => sum + part);
    return [for (final part in ratio) (total * part / parts).floorToDouble()];
  }
}

/// Halaman auth: kanvas setinggi layar dengan 3 baris (header, form, footer).
/// Tanpa keyboard halaman tidak bisa digeser; saat keyboard muncul bisa discroll.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.canvas,
    required this.ratio,
    required this.children,
  });

  final AuthCanvas canvas;
  final List<int> ratio;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final heights = canvas.rows(ratio);
    final columns = canvas.formColumns;

    return Scaffold(
      backgroundColor: AuthColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++)
                // Tinggi baris = tinggi minimal, memanjang kalau isinya lebih tinggi.
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: heights[i]),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: columns[0]),
                      SizedBox(width: columns[1], child: children[i]),
                      SizedBox(width: columns[2]),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.padding, required this.child});

  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.border),
      ),
      child: child,
    );
  }
}

/// Field berlabel. Kalau [isPassword], field punya tombol tampil/sembunyi
/// sendiri (karena itu Stateful).
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.helperText,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? helperText;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AuthColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          style: const TextStyle(color: AuthColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AuthColors.textMuted, fontSize: 14),
            helperText: widget.helperText,
            helperMaxLines: 3,
            helperStyle: const TextStyle(color: AuthColors.textMuted, fontSize: 11.5),
            // Bawaan Flutter cuma 1 baris, jadi pesan panjang terpotong.
            errorMaxLines: 2,
            errorStyle: const TextStyle(color: AuthColors.error, fontSize: 12),
            prefixIcon: Icon(widget.icon, color: AuthColors.textMuted, size: 20),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AuthColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            filled: true,
            fillColor: AuthColors.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: _border(AuthColors.border),
            enabledBorder: _border(AuthColors.border),
            focusedBorder: _border(AuthColors.accent, 1.5),
            errorBorder: _border(AuthColors.error),
            focusedErrorBorder: _border(AuthColors.error, 1.5),
          ),
        ),
      ],
    );
  }
}

/// Tombol emas lebar penuh, jadi spinner saat [isLoading].
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;

  /// Null = tombol nonaktif.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // Tinggi minimal 48 dp, bertambah kalau font sistem diperbesar.
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AuthColors.accent,
        foregroundColor: AuthColors.bg,
        disabledBackgroundColor: AuthColors.accent.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }
}

/// Tombol teks kecil berwarna emas (Daftar, Masuk Sekarang, Lupa sandi?).
class AuthLinkButton extends StatelessWidget {
  const AuthLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fontSize = 14,
    this.bold = true,
  });

  final String label;
  final VoidCallback onPressed;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 44),
        foregroundColor: AuthColors.accent,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

extension AuthFeedbackX on BuildContext {
  /// SnackBar mengambang dengan ikon, untuk pesan hasil login/daftar.
  void showAuthFeedback({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuthColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: AuthColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
