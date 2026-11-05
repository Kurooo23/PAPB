import 'package:flutter/material.dart';

import 'package:rivnet/themes/color.dart';

/// GlobalKey navigator supaya bisa akses context tanpa BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Snackbar pesan (bukan GetX).
void tampilPesan(String pesan, {bool error = false}) {
  // Delay sebentar supaya snackbar muncul setelah dialog pop selesai
  // dan tidak tertutup bottom bar / system UI.
  Future.delayed(const Duration(milliseconds: 150), () {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final warnaLatar = error ? AppColors.error : Colors.white;
    final warnaTeks = error ? Colors.white : Colors.black87;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          pesan,
          style: TextStyle(color: warnaTeks, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: warnaLatar,
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  });
}

/// Dialog konfirmasi (bukan GetX). Mengembalikan true kalau user konfirmasi.
Future<bool> konfirmasi(
  String judul,
  String isi, {
  String tombol = 'Hapus',
}) async {
  final context = navigatorKey.currentContext;
  if (context == null) return false;
  final hasilDialog = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(judul),
      content: Text(isi),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: Text(tombol),
        ),
      ],
    ),
  );
  return hasilDialog ?? false;
}
