import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/database/database_helper.dart';
import 'package:rivnet/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    TurnamenController.instance.resetUntukTest();
    await DatabaseHelper.instance.setTestDatabase(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
  });

  testWidgets('Awal aplikasi kosong tanpa data dummy dan dapat buat turnamen', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(() => TurnamenController.instance.muatDariDatabase());
    await tester.pumpWidget(const RivnetApp());
    await tester.pumpAndSettle();

    expect(find.text('Belum ada turnamen.'), findsOneWidget);
    expect(find.text('UEFA Champions Mini Cup'), findsNothing);

    await tester.tap(find.text('Buat Turnamen').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Turnamen Kampus');
    await tester.enterText(find.byType(TextFormField).at(1), 'Gedung A');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Buat Turnamen'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Turnamen Kampus'), findsOneWidget);

    // Pastikan data benar-benar tersimpan di SQLite saat dimuat ulang.
    TurnamenController.instance.resetUntukTest();
    await tester.runAsync(() => TurnamenController.instance.muatDariDatabase());
    await tester.pump();
    expect(find.text('Turnamen Kampus'), findsOneWidget);
  });

  testWidgets('Kelola detail turnamen, skor, klasemen, dan akhiri turnamen', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(() async {
      await TurnamenController.instance.muatDariDatabase();
      await TurnamenController.instance.buatTurnamen(
        nama: 'Liga Kampus',
        leg: 1,
        namaPeserta: ['Tim Alpha', 'Tim Beta', 'Tim Gamma', 'Tim Delta'],
      );
    });

    await tester.pumpWidget(const RivnetApp());
    await tester.pumpAndSettle();

    expect(find.text('Liga Kampus'), findsOneWidget);
    expect(find.text('Akan Datang'), findsOneWidget);

    await tester.tap(find.text('Liga Kampus'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Turnamen'), findsOneWidget);
    // Tombol akhiri belum muncul sebelum semua laga diisi skor
    expect(find.text('Akhiri turnamen & kunci skor'), findsNothing);

    // Buka tab Pertandingan (6) dan isi skor pertandingan pertama
    await tester.tap(find.text('Pertandingan (6)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('vs').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('2 - 1'), findsOneWidget);
    expect(find.text('Berlangsung'), findsOneWidget);
    expect(find.text('Akhiri turnamen & kunci skor'), findsNothing);

    // Isi sisa 5 pertandingan agar semua laga selesai
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('vs').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '1');
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
    }

    expect(find.text('Akhiri turnamen & kunci skor'), findsOneWidget);

    // Akhiri turnamen
    await tester.tap(find.text('Akhiri turnamen & kunci skor'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Akhiri'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Selesai'), findsOneWidget);
    expect(find.byTooltip('Edit turnamen'), findsNothing);

    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Peserta'), findsNothing);
    expect(find.byTooltip('Edit peserta'), findsNothing);
    expect(find.byTooltip('Hapus peserta'), findsNothing);
  });

  testWidgets('Daftar turnamen menyesuaikan lebar layar', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(() => TurnamenController.instance.muatDariDatabase());
    await tester.pumpWidget(const RivnetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat Turnamen').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Responsive Cup');
    await tester.enterText(find.byType(TextFormField).at(1), 'Online');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Buat Turnamen'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Responsive Cup'), findsOneWidget);

    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();
    expect(find.text('Responsive Cup'), findsOneWidget);

    tester.view.physicalSize = const Size(1100, 1000);
    await tester.pumpAndSettle();
    expect(find.text('Responsive Cup'), findsOneWidget);
  });

  testWidgets('Edit turnamen, kelola peserta, dan hapus turnamen via SQLite', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(() async {
      await TurnamenController.instance.muatDariDatabase();
      await TurnamenController.instance.buatTurnamen(
        nama: 'Cup Awal',
        leg: 1,
        namaPeserta: ['Tim 1', 'Tim 2', 'Tim 3', 'Tim 4'],
      );
    });

    await tester.pumpWidget(const RivnetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cup Awal'));
    await tester.pumpAndSettle();

    // Edit turnamen via Named Route
    await tester.tap(find.byTooltip('Edit turnamen'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Turnamen'), findsOneWidget);
    expect(find.text('Tim 1'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Cup Revisi');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan Perubahan'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Cup Revisi'), findsOneWidget);

    // Tambah peserta di tab Peserta
    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah Peserta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Tim 5');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Tim 5'), findsOneWidget);

    // Hapus turnamen dan kembali ke Home
    await tester.tap(find.byTooltip('Hapus turnamen'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Belum ada turnamen.'), findsOneWidget);
  });

  testWidgets('Buat dan jalankan turnamen Single Elimination dengan bracket', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(() => TurnamenController.instance.muatDariDatabase());
    await tester.pumpWidget(const RivnetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat Turnamen').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Cup Gugur');
    await tester.tap(find.text('Single Elimination'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'Elang FC');
    await tester.enterText(find.byType(TextFormField).at(2), 'Garuda FC');
    await tester.enterText(find.byType(TextFormField).at(3), 'Rajawali FC');
    await tester.enterText(find.byType(TextFormField).at(4), 'Singa FC');

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Buat Turnamen'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Cup Gugur'), findsOneWidget);
    await tester.tap(find.text('Cup Gugur'));
    await tester.pumpAndSettle();

    expect(find.text('Bracket'), findsOneWidget);
    expect(find.text('Semifinal'), findsOneWidget);
    expect(find.text('Perebutan Juara 3'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('TBD'), findsNWidgets(4));

    // Sebelum ada skor, Single Elimination boleh tambah & hapus peserta
    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Peserta'), findsOneWidget);
    expect(find.byTooltip('Hapus peserta'), findsNWidgets(4));

    // Pindah ke tab Pertandingan (4) untuk isi skor semifinal
    await tester.tap(find.text('Pertandingan (4)'));
    await tester.pumpAndSettle();

    // Perebutan Juara 3 tampil lebih dulu daripada Final
    expect(
      tester.getTopLeft(find.text('Perebutan Juara 3')).dy <
          tester.getTopLeft(find.text('Final')).dy,
      isTrue,
    );

    // Uji validasi skor tidak boleh seri pada sistem gugur
    await tester.tap(find.text('vs').at(0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '1');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Sistem gugur tidak boleh seri. Jika lanjut adu penalti, tambahkan skor penalti ke skor akhir.',
      ),
      findsOneWidget,
    );

    // Semifinal 1: Elang FC 2 - 0 Rajawali FC
    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Setelah ada skor pada Single Elimination, tambah & hapus peserta dikunci
    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Peserta'), findsNothing);
    expect(find.byTooltip('Hapus peserta'), findsNothing);
    expect(find.byTooltip('Edit peserta'), findsNWidgets(4));
    await tester.tap(find.text('Pertandingan (4)'));
    await tester.pumpAndSettle();

    // Semifinal 2: Garuda FC 1 - 3 Singa FC
    await tester.tap(find.text('vs').at(0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '1');
    await tester.enterText(find.byType(TextFormField).at(1), '3');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Perebutan Juara 3 dimainkan lebih dulu sebelum Final
    await tester.tap(find.text('vs').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Final sekarang siap
    await tester.tap(find.text('vs').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Kembali ke tab Bracket dan cek juara 1 & juara 3
    await tester.tap(find.text('Bracket'));
    await tester.pumpAndSettle();

    expect(find.text('TBD'), findsNothing);
    expect(find.text('Juara Turnamen'), findsOneWidget);
    expect(find.text('Juara 3'), findsOneWidget);
    expect(find.text('Elang FC'), findsWidgets);
  });
}
