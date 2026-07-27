import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:your_art_archive/main.dart';

void main() {
  testWidgets('splash exposes the two authentication paths', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Your Art\nArchive'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('create account opens registration', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your archive'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  for (final size in const [
    (width: 320.0, height: 700.0),
    (width: 1280.0, height: 800.0),
  ]) {
    testWidgets('splash lays out at ${size.width.toInt()} px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(size.width, size.height);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Your Art\nArchive'), findsOneWidget);
    });
  }
}
