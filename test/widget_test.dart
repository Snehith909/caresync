import 'package:flutter_test/flutter_test.dart';

import 'package:caresync/main.dart';

void main() {
  testWidgets('CareSync home page renders the dashboard shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareSyncApp());

    expect(find.text('CareSync'), findsOneWidget);
    expect(find.text('Your care, in sync.'), findsOneWidget);
    expect(find.text('Upload document'), findsOneWidget);
    expect(find.text('Medication reminders'), findsOneWidget);
  });
}
