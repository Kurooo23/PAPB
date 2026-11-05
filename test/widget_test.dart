import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivnet/main.dart';

void main() {
  testWidgets('Home offline dapat membuat turnamen lokal', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const RivnetApp());

    expect(find.text('Turnamen'), findsWidgets);

    await tester.tap(find.text('Buat Turnamen').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Turnamen Kampus');
    await tester.enterText(find.byType(TextFormField).at(1), 'Gedung A');
    await tester.tap(find.widgetWithText(FilledButton, 'Buat Turnamen'));
    await tester.pumpAndSettle();

    expect(find.text('Turnamen Kampus'), findsOneWidget);
  });

  testWidgets('Daftar turnamen menyesuaikan lebar layar', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const RivnetApp());

    await tester.tap(find.text('Buat Turnamen').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Responsive Cup');
    await tester.enterText(find.byType(TextFormField).at(1), 'Online');
    await tester.tap(find.widgetWithText(FilledButton, 'Buat Turnamen'));
    await tester.pumpAndSettle();

    expect(find.text('Responsive Cup'), findsOneWidget);

    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();
    expect(find.text('Responsive Cup'), findsOneWidget);

    tester.view.physicalSize = const Size(1100, 1000);
    await tester.pumpAndSettle();
    expect(find.text('Responsive Cup'), findsOneWidget);
  });
}
