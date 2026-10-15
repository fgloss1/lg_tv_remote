// Smoke tests for the LG TV remote shell.

import 'package:flutter_test/flutter_test.dart';
import 'package:lg_tv_remote/main.dart';

void main() {
  testWidgets('shell renders all four tabs and switches between them',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LGTVRemoteApp());
    await tester.pump();

    // The bottom bar exposes every destination.
    expect(find.text('Remote'), findsOneWidget);
    expect(find.text('Media Cast'), findsOneWidget);
    expect(find.text('Screen Mirror'), findsOneWidget);
    expect(find.text('Web Caster'), findsOneWidget);

    // Tapping a destination swaps the visible screen.
    await tester.tap(find.text('Media Cast'));
    await tester.pumpAndSettle();

    expect(find.text('Cast Photos'), findsOneWidget);
    expect(find.text('Cast Videos'), findsOneWidget);
    expect(find.text('Cast Music'), findsOneWidget);
  });

  testWidgets('remote tab starts disconnected and offers a scan action',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LGTVRemoteApp());
    await tester.pump();

    expect(find.text('No LG TV connected'), findsOneWidget);
    expect(find.text('Quick Launch'.toUpperCase()), findsOneWidget);
  });
}