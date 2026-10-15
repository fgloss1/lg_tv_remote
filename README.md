# lg_tv_remote

High-end LG webOS TV remote, media caster and screen mirroring app built with Flutter.

## Design system

| Token | Value |
| --- | --- |
| Background | `#0F0F12` (deep charcoal) |
| Surface | `#1A1A20` |
| Primary accent | `#00E5FF` (neon cyan) |
| Secondary accent | `#7C4DFF` (violet) |
| Success / error | green / red |

Every screen uses rounded glass cards, subtle gradient washes and `InkWell`
ripple feedback for tactile button presses.

## Tabs

1. **Remote Control** — pulsing connection dot, power/mute/back, air-mouse
   touchpad, D-pad with OK, volume slider, channel stepper, quick-launch app
   grid and an on-screen keyboard.
2. **Media Cast** — pick photos / video / audio from the device and hand them to
   the TV's system media player.
3. **Screen Mirror** — start/stop toggle, resolution selector (720p / 1080p / 4K)
   and latency presets (gaming, movie, balanced) with a connection helper.
4. **Web Caster** — embedded browser with URL bar, streaming-site shortcuts,
   embedded-video detection and a floating "Cast to TV" button.

## LG webOS backend (`lib/services/tv_service.dart`)

| Step | Detail |
| --- | --- |
| Discovery | SSDP `M-SEARCH` for `urn:lg-iot:service:discovery:1` over UDP 1900 |
| Pairing | `GET http://<tv>:3000/pair` then `POST /register` |
| Control | WebSocket `ws://<tv>:3001` with `register` + `request` frames |
| Keys | webOS key codes via `msc.request` button frames |
| Pointer | `msc.request` `move` / `wheel` / `button` frames for the air mouse |
| Text | `POST /keyboard/input` for the on-screen keyboard |
| Launch | `POST /webapp/launch` with the bundled app ids |

State is exposed through `ChangeNotifier` + `provider`.

## Running

```powershell
flutter pub get
flutter run
```

## Required platform permissions

**Android** (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
```

`CHANGE_WIFI_MULTICAST_STATE` is required so the SSDP datagram reaches the TV.

**iOS** (`ios/Runner/Info.plist`)

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Used to discover and control your LG TV on the local network.</string>
<key>NSBonjourServices</key>
<array><string>_lg-iot._tcp</string></array>
```

## Notes / limitations

- webOS cannot pull files off the phone, so local media must be served over the
  network (for example by a local HTTP server) before it can be cast.
- Screen mirroring performance depends on the phone encoder; use *Gaming mode*
  for the lowest latency and *Movie mode* for smoother playback.