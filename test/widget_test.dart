// Smoke tests for the LG TV remote shell plus the interaction guarantees the
// remote and media cast screens rely on.
//
// The default widget-test surface (800x600) only builds what fits on screen,
// so the surface is grown to phone height: every control is then laid out and
// can be tapped.

import 'package:flutter/material.dart' show CircularProgressIndicator, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lg_tv_remote/main.dart';

/// Pumps the app on a tall surface and restores the view afterwards.
Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const LGTVRemoteApp());
  await tester.pump();
}

/// Switches to the Media Cast tab.
Future<void> openMediaCast(WidgetTester tester) async {
  await tester.tap(find.text('Media Cast'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shell renders all four tabs and switches between them',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // The bottom bar exposes every destination.
    expect(find.text('Remote'), findsOneWidget);
    expect(find.text('Media Cast'), findsOneWidget);
    expect(find.text('Screen Mirror'), findsOneWidget);
    expect(find.text('Web Caster'), findsOneWidget);

    await openMediaCast(tester);

    expect(find.text('Cast Photos'), findsOneWidget);
    expect(find.text('Cast Videos'), findsOneWidget);
    expect(find.text('Cast Music'), findsOneWidget);
  });

  testWidgets('remote tab starts disconnected and offers a scan action',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('No LG TV connected'), findsOneWidget);
    expect(find.text('Quick Launch'.toUpperCase()), findsOneWidget);
    expect(find.text('Power'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('remote buttons answer taps even with no TV connected',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // Power, Mute and Back used to hand `null` to onTap, so the tap vanished.
    for (final String label in <String>['Power', 'Mute', 'Back']) {
      await tester.tap(find.text(label));
      await tester.pump();
      expect(
        find.textContaining('No TV connected'),
        findsOneWidget,
        reason: '$label gave no feedback',
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('d-pad keys answer taps even with no TV connected',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // The D-pad cluster is mounted once as a const widget, so it must rebuild
    // from state instead of reading the service once at build time. The keys
    // are icon-only, so they are addressed by icon.
    final List<IconData> arrows = <IconData>[
      Icons.keyboard_arrow_up,
      Icons.keyboard_arrow_down,
      Icons.keyboard_arrow_left,
      Icons.keyboard_arrow_right,
    ];

    for (final IconData icon in arrows) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
      expect(
        find.textContaining('No TV connected'),
        findsOneWidget,
        reason: '$icon gave no feedback',
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.textContaining('No TV connected'), findsOneWidget);
  });

  testWidgets('quick launch apps answer taps even with no TV connected',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Netflix'));
    await tester.pump();

    expect(find.textContaining('No TV connected'), findsOneWidget);
  });

  testWidgets('media cast tiles open their picker', (WidgetTester tester) async {
    await pumpApp(tester);
    await openMediaCast(tester);

    await tester.tap(find.text('Cast Photos'));
    await tester.pump();

    // The tile reacts: the status line reports that the picker was opened and
    // the icon turns into a spinner.
    expect(find.text('Waiting for the picker…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // There is no platform picker in a widget test, so unmount instead of
    // settling: the spinner would animate forever.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping the connection card opens the device picker',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('No LG TV connected'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a TV'), findsOneWidget);
    expect(find.text('Connect manually'), findsOneWidget);
  });

  testWidgets('touchpad reports a tap instead of ignoring it',
      (WidgetTester tester) async {
    await pumpApp(tester);

    final Finder touchpad = find.textContaining('Not connected');
    expect(touchpad, findsOneWidget);

    await tester.tap(touchpad);
    await tester.pumpAndSettle();

    expect(find.text('Choose a TV'), findsOneWidget);
  });
}
