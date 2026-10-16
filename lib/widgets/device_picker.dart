import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import 'tactile.dart';

/// Opens the sheet used to pick which TV to control.
///
/// Tapping anywhere on the connection card lands here, so connecting a TV no
/// longer depends on discovery happening to auto-select the first result.
Future<void> showDevicePicker(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15151B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext _) => const _DevicePickerSheet(),
  );
}

class _DevicePickerSheet extends StatefulWidget {
  const _DevicePickerSheet();

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  final TextEditingController _manualIp = TextEditingController();

  @override
  void dispose() {
    _manualIp.dispose();
    super.dispose();
  }

  void _connectManually() {
    final String raw = _manualIp.text.trim();
    if (raw.isEmpty) return;

    final TVService tv = context.read<TVService>();
    tv.connectToDevice(
      LgTvDevice(name: 'LG TV at $raw', ip: raw, mac: ''),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();
    const Color cyan = Color(0xFF00E5FF);
    final List<LgTvDevice> devices = tv.devices;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Choose a TV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TactileButton(
                    semanticLabel: 'Rescan for TVs',
                    onPressed: () {
                      triggerHaptic(HapticStrength.medium);
                      tv.startDiscovery();
                    },
                    borderRadius: BorderRadius.circular(12),
                    color: cyan.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (tv.isScanning)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cyan,
                            ),
                          )
                        else
                          const Icon(Icons.radar, color: cyan, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          tv.isScanning ? 'Scanning' : 'Rescan',
                          style: const TextStyle(color: cyan, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (devices.isEmpty)
                const Text(
                  'No TVs found yet. Make sure the television is on and shares '
                  'your Wi-Fi, then tap Rescan.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                )
              else
                for (final LgTvDevice device in devices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeviceTile(
                      device: device,
                      connected: tv.device?.ip == device.ip && tv.isConnected,
                      busy: tv.state == TvConnectionState.pairing &&
                          tv.device?.ip == device.ip,
                      onTap: () {
                        triggerHaptic(HapticStrength.medium);
                        tv.connectToDevice(device);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
              const SizedBox(height: 10),
              const Text(
                'Connect manually',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _manualIp,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '192.168.1.50',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1A20),
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.router_outlined,
                          color: cyan,
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cyan.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cyan.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _connectManually(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TactileButton(
                    semanticLabel: 'Connect to typed IP address',
                    strength: HapticStrength.medium,
                    onPressed: _connectManually,
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF7C4DFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.connected,
    required this.busy,
    required this.onTap,
  });

  final LgTvDevice device;
  final bool connected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color cyan = Color(0xFF00E5FF);
    final Color border = connected
        ? cyan
        : cyan.withValues(alpha: busy ? 0.6 : 0.25);

    return TactileButton(
      semanticLabel: 'Connect to ${device.name}',
      onPressed: onTap,
      borderRadius: BorderRadius.circular(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cyan.withValues(alpha: connected ? 0.14 : 0.06),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.cast_connected : Icons.tv_outlined,
            color: cyan,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  busy ? 'Pairing…' : device.ip,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (connected)
            const Icon(Icons.check_circle, color: cyan, size: 20),
        ],
      ),
    );
  }
}
