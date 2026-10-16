import 'package:flutter/material.dart';

import '../services/tv_service.dart';
import 'tactile.dart';

/// Runs [action] against the connected TV, or explains how to connect when no
/// television is attached yet.
///
/// Remote controls call this instead of handing `null` to `InkWell.onTap`,
/// which is what made every button feel dead: a null tap target swallows the
/// gesture without any feedback.
void dispatchToTv(
  BuildContext context,
  TVService tv,
  void Function(TVService tv) action,
) {
  if (tv.isConnected) {
    action(tv);
    return;
  }
  reportNotConnected(context, tv);
}

/// Shows the "no TV attached" message with a shortcut that starts a scan.
void reportNotConnected(BuildContext context, TVService tv, {String? hint}) {
  triggerHaptic(HapticStrength.medium);

  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          hint ?? 'No TV connected yet — scan to find one on your Wi-Fi',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          // SnackBarAction requires a callback, so a running scan gets a
          // no-op instead of a disabled-looking dead control.
          label: tv.isScanning ? 'Scanning' : 'Scan',
          onPressed: tv.isScanning ? () {} : () => tv.startDiscovery(),
        ),
      ),
    );
}

/// Single toast style shared by every screen.
void showRemoteToast(
  BuildContext context,
  String message, {
  bool error = false,
  SnackBarAction? action,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFF7F1D1D) : null,
        duration: const Duration(seconds: 3),
        action: action,
      ),
    );
}
