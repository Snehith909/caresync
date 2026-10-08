import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:caresync/auth/auth_gateway.dart';
import 'package:caresync/main.dart';
import 'package:caresync/state/care_sync_state.dart';

void main() {
  testWidgets('CareSync patient app renders an empty daily care dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CareSyncState(),
        child: CareSyncApp(
          authGateway: FakeAuthGateway(
            initialUser: const CareUser(
              id: 'test-user',
              email: 'patient@example.com',
            ),
          ),
        ),
      ),
    );

    expect(find.text('CareSync'), findsOneWidget);
    expect(find.text('Your care, in sync.'), findsOneWidget);
    expect(find.text('Medication progress'), findsOneWidget);
    expect(find.text('Update your condition'), findsOneWidget);
  });

  testWidgets('patient can open weekly progress and voice tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CareSyncState(),
        child: CareSyncApp(
          authGateway: FakeAuthGateway(
            initialUser: const CareUser(
              id: 'test-user',
              email: 'patient@example.com',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly medication progress'), findsOneWidget);

    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    expect(find.text('Ask about your care'), findsOneWidget);
  });
}
