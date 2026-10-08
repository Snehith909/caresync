import 'package:flutter/material.dart';

import 'auth_gateway.dart';
import 'auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.gateway,
    required this.authenticatedBuilder,
    super.key,
  });

  final AuthGateway gateway;
  final WidgetBuilder authenticatedBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CareUser?>(
      stream: gateway.authStateChanges,
      initialData: gateway.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return AuthScreen(gateway: gateway);
        }
        return authenticatedBuilder(context);
      },
    );
  }
}
