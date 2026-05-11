import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baby_guard/app.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: BabyGuardApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
