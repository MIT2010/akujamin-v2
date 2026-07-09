import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

void main() {
  testWidgets('NotFoundPage shows a message and a way back home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('home-page')),
        ),
      ],
      errorBuilder: (context, state) => const NotFoundPage(),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/nowhere');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();

    expect(find.text('home-page'), findsOneWidget);
  });
}
