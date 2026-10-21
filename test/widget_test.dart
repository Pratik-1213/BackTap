import 'package:flutter_test/flutter_test.dart';
import 'package:backtap/main.dart';

void main() {
  testWidgets('BackTap app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BackTapApp());
    await tester.pumpAndSettle();

    // Verify that BackTap title and the two gesture options are present
    expect(find.text('BackTap'), findsOneWidget);
    expect(find.text('GESTURE MAPPING'), findsOneWidget);
    expect(find.text('Tap 4 Times'), findsOneWidget);
    expect(find.text('Tap 8 Times'), findsOneWidget);
  });
}
