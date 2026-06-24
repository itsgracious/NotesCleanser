import 'package:flutter_test/flutter_test.dart';
import 'package:notes_cleanser/main.dart';

void main() {
  testWidgets('NotesCleanserApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NotesCleanserApp());

    // Verify that our app name is displayed.
    expect(find.text('NotesCleanser'), findsOneWidget);
  });
}
