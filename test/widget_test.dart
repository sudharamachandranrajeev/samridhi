import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/main.dart';

void main() {
  testWidgets('shows the P0 scaffold screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SamridhiApp());

    expect(find.text('Samridhi'), findsWidgets);
    expect(find.text('Samridhi — P0 scaffold'), findsOneWidget);
    expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
  });
}
