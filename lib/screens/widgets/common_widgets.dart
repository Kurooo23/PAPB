import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';

// Widget dan helper yang dipakai bersama oleh semua halaman di folder screens.

/// Warna turnamen privat (disimpan lokal di HP).
const privateColor = AppColors.success;
const privateColorDark = Color(0xFF059669);

/// Warna status turnamen / laga.
Color statusColor(String status, {Color fallback = AppColors.primary}) {
  switch (status) {
    case 'Berlangsung':
      return AppColors.secondary;
    case 'Selesai':
      return AppColors.success;
    default:
      return fallback;
  }
}

/// Poin catur dalam satuan ½ jadi teks pecahan: 3 → "1½", 1 → "½", 2 → "1".
String formatHalfPoints(int halves) {
  final whole = halves ~/ 2;
  if (halves.isEven) return '$whole';
  return whole == 0 ? '½' : '$whole½';
}

/// Poin catur (satuan ½) dari jumlah menang yang tersimpan di database.
/// Pertandingan selesai: game utama (BO - 1) yang tidak dimenangkan siapa pun
/// dihitung remis, ½ poin untuk masing-masing pemain.
(int, int) chessHalfPoints({
  required int wins1,
  required int wins2,
  required int bestOf,
  required bool isFinished,
}) {
  final draws = isFinished ? max(0, bestOf - 1 - wins1 - wins2) : 0;
  return (wins1 * 2 + draws, wins2 * 2 + draws);
}

/// Pesan error tanpa awalan "Exception: ".
String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

extension SnackBarX on BuildContext {
  void showSnack(String message, {Color color = AppColors.primary}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}

// ===================== LAYOUT (MediaQuery) =====================

/// Ukuran halaman dari MediaQuery. Isi dibatasi [maxWidth] dan diletakkan
/// di tengah, padding samping = [paddingRatio] x lebar isi.
class PageLayout {
  const PageLayout._(this.screen, this.contentWidth, this.sidePadding);

  factory PageLayout.of(
    BuildContext context, {
    double maxWidth = 1100,
    double paddingRatio = 0.04,
  }) {
    final screen = MediaQuery.sizeOf(context);
    final contentWidth = min(screen.width, maxWidth);
    final extraSpace = (screen.width - contentWidth) / 2;
    return PageLayout._(screen, contentWidth, extraSpace + contentWidth * paddingRatio);
  }

  final Size screen;
  final double contentWidth;
  final double sidePadding;

  double get gap => contentWidth * 0.03;
  bool get isWide => contentWidth >= 600;
  bool get isNarrow => screen.width < 360;
  bool get isShort => screen.height < 640;
}

/// Susun widget jadi grid N kolom yang lebarnya dibagi rata (Row + Expanded).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int start = 0; start < children.length; start += columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columns; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: start + i < children.length
                      ? children[start + i]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Dua widget: berdampingan 1:1 di layar lebar, ditumpuk di HP.
class ResponsivePair extends StatelessWidget {
  const ResponsivePair({
    super.key,
    required this.isWide,
    required this.gap,
    required this.verticalGap,
    required this.left,
    required this.right,
  });

  final bool isWide;
  final double gap;
  final double verticalGap;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: gap),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [left, SizedBox(height: verticalGap), right],
    );
  }
}

// ===================== FORM =====================

/// Judul section form + isinya.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: MediaQuery.sizeOf(context).width < 360 ? 15 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
        filled: true,
        fillColor: AppColors.bgCard,
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// Tombol utama lebar penuh yang berubah jadi spinner saat [isLoading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.height = 52,
    this.radius = 14,
    this.fontSize = 16,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          : Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

/// Kotak pilihan (seperti tombol radio) yang berwarna saat dipilih.
class SelectBox extends StatelessWidget {
  const SelectBox({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
    this.background = AppColors.bgCard,
    this.borderColor,
    this.unselectedBorder = Colors.white12,
    this.textColor = Colors.white,
    this.minHeight = 40,
    this.fontSize = 12,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Color background;

  /// Null = tanpa garis tepi.
  final Color? borderColor;
  final Color unselectedBorder;
  final Color textColor;
  final double minHeight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: borderColor == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? borderColor! : unselectedBorder),
                ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? textColor : AppColors.textSecondary,
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== BADGE & STATE =====================

/// Label kecil berwarna: latar transparan, garis tepi, dan teks warna sama.
class ColorBadge extends StatelessWidget {
  const ColorBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.dot = false,
    this.radius = 8,
    this.fontSize = 11,
    this.borderAlpha = 0.3,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  final String text;
  final Color color;
  final IconData? icon;

  /// Titik bulat di depan teks (penanda status).
  final bool dot;
  final double radius;
  final double fontSize;
  final double borderAlpha;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge "Privat (Lokal HP)" / "Publik".
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key, required this.isPrivate, this.small = false});

  final bool isPrivate;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return ColorBadge(
      text: isPrivate ? 'Privat (Lokal HP)' : 'Publik',
      color: isPrivate ? privateColor : AppColors.secondary,
      icon: isPrivate ? Icons.lock_rounded : Icons.public_rounded,
      fontSize: small ? 10 : 11,
      radius: small ? 6 : 20,
      borderAlpha: small ? 0.3 : 0.4,
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

/// Tampilan tengah layar untuk kondisi kosong / error.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.iconColor = AppColors.textMuted,
    this.actions = const [],
  });

  final IconData icon;
  final String? title;
  final String message;
  final Color iconColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(width * 0.08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: (width * 0.14).clamp(44.0, 64.0)),
              const SizedBox(height: 16),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                // Wrap: tombol sebaris, turun ke bawah kalau layar sempit.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== DIALOG (GetX) =====================

/// AlertDialog bergaya gelap untuk semua dialog. Dibuka dengan
/// `Get.dialog(AppDialog(...))` dan ditutup dengan `Get.back()`.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.actions,
    this.leading,
    this.message,
    this.content,
    this.titleSize = 16,
  });

  final String title;
  final Widget? leading;

  /// Isi berupa teks biasa. Pakai [content] untuk isi lain.
  final String? message;
  final Widget? content;
  final List<Widget> actions;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgDarkSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: content ??
          Text(
            message ?? '',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
      actions: actions,
    );
  }
}

/// Tombol teks di dialog. Tanpa [onPressed], dialog langsung ditutup.
class DialogTextButton extends StatelessWidget {
  const DialogTextButton(
    this.label, {
    super.key,
    this.onPressed,
    this.color = AppColors.textSecondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed ?? () => Get.back(),
      child: Text(label, style: TextStyle(color: color)),
    );
  }
}

/// Tombol aksi utama di dialog.
class DialogFilledButton extends StatelessWidget {
  const DialogFilledButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
    );
  }
}

/// Dialog konfirmasi. Hasilnya true kalau pengguna menekan [confirmLabel].
Future<bool> showConfirmDialog({
  required IconData icon,
  required Color color,
  required String title,
  required String message,
  required String confirmLabel,
  Color confirmTextColor = Colors.white,
}) async {
  final result = await Get.dialog<bool>(
    AppDialog(
      leading: Icon(icon, color: color),
      title: title,
      titleSize: 18,
      message: message,
      actions: [
        DialogTextButton('Batal', onPressed: () => Get.back(result: false)),
        DialogFilledButton(
          confirmLabel,
          color: color,
          textColor: confirmTextColor,
          onPressed: () => Get.back(result: true),
        ),
      ],
    ),
  );
  return result == true;
}

/// Dialog "Login Diperlukan" dengan tombol Login Sekarang.
void showLoginRequiredDialog({
  required String message,
  required VoidCallback onLogin,
  String cancelLabel = 'Batal',
}) {
  Get.dialog(
    AppDialog(
      leading: const Icon(Icons.lock_outline_rounded, color: AppColors.secondary, size: 22),
      title: 'Login Diperlukan',
      message: message,
      actions: [
        DialogTextButton(cancelLabel, color: AppColors.textMuted),
        DialogFilledButton(
          'Login Sekarang',
          onPressed: () {
            Get.back();
            onLogin();
          },
        ),
      ],
    ),
  );
}
