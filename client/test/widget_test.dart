import 'package:flutter_test/flutter_test.dart';
import 'package:client/main.dart';

void main() {
  testWidgets('Sanity widget test for LibraryCheckinApp', (WidgetTester tester) async {
    await tester.pumpWidget(const LibraryCheckinApp());
    expect(find.text('Library Check-in System'), findsOneWidget);
  });
}
