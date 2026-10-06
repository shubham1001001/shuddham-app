import 'package:flutter_test/flutter_test.dart';
import 'package:shuddham_water_solutions/main.dart';

void main() {
  testWidgets('ShuddhamApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShuddhamApp());
    expect(find.byType(ShuddhamApp), findsOneWidget);
    // Advance timer to trigger splash navigation
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
