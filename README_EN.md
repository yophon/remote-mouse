# Remote Mouse

English | [简体中文](README.md)

![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter)
![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)

Remote Mouse turns your phone into a wireless touchpad and keyboard for macOS. The mobile app is built with Flutter, while the macOS server uses Swift, Network.framework, and CoreGraphics.

> The current version does not provide pairing, authentication, or encryption. Use it only on a trusted local network. Do not expose ports `9876` or `9877` to the internet.

## Features

- Move the pointer with one finger and tap to left-click
- Two-finger tap for right-click and two-finger scrolling
- Dedicated left and right mouse buttons with drag support
- Phone keyboard input, navigation keys, function keys, and macOS shortcuts
- Hybrid UDP + WebSocket transport or WebSocket-only mode
- Bonjour/mDNS discovery with manual IP connection as a fallback
- Adjustable pointer speed, scrolling speed, natural scrolling, and precision
- Portrait, landscape, and automatic orientation modes
- Dark mode, haptic feedback, and Chinese/English UI
- Recent connection history

## How It Works

```text
Flutter mobile app
  |-- WebSocket :9876  clicks, buttons, keyboard, reliable events
  `-- UDP       :9877  pointer movement, dragging, scrolling
                         |
                         v
Swift macOS server -> CoreGraphics -> mouse and keyboard events
```

High-frequency events use a compact 13-byte binary message. Clicks, keyboard input, and other important events use JSON. In hybrid mode, reliable events are sent over both UDP and WebSocket and deduplicated by message ID on the server.

## Requirements

### macOS server

- macOS 13 or later
- Swift 5.9 or later
- The Mac and phone connected to the same local network
- Accessibility permission granted to the terminal or server executable

### Mobile app

- A Flutter SDK that includes Dart `3.10.7` or later
- A physical Android or iOS device

## Quick Start

### 1. Start the macOS server

```bash
cd desktop
swift run
```

The server listens on the following endpoints:

| Purpose | Protocol | Default port |
| --- | --- | ---: |
| Control connection and reliable events | WebSocket | `9876` |
| High-frequency pointer events | UDP | `9877` |
| Service discovery | Bonjour | `_remotemouse._tcp` |

On first launch, open **System Settings > Privacy & Security > Accessibility** and allow your terminal or the server executable to control the Mac. Restart the server after changing this permission if necessary.

### 2. Start the mobile app

```bash
cd mobile
flutter pub get
flutter run --release
```

The app searches for Remote Mouse servers on the local network. Select a discovered Mac, or enter the Mac's local IP address manually. The default WebSocket port is `9876`.

## iOS Local Network Permission

For an iOS device, add the local-network and Bonjour declarations to `mobile/ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Required to discover and connect to Remote Mouse on the local network</string>
<key>NSBonjourServices</key>
<array>
    <string>_remotemouse._tcp</string>
</array>
```

Allow local-network access when iOS prompts on the first discovery attempt.

## Controls

| Mobile gesture | macOS action |
| --- | --- |
| One-finger swipe | Move the pointer |
| One-finger tap | Left-click |
| Two quick taps | Double-click |
| Two-finger tap | Right-click |
| Two-finger swipe | Scroll horizontally or vertically |
| Hold the bottom left button and move on the touchpad | Drag |
| Tap the keyboard button | Open the remote keyboard |

The keyboard bar includes `Esc`, `Tab`, arrow keys, paging keys, modifiers, and common Command shortcuts. Tap a modifier for one-shot use or double-tap it to lock. Swipe vertically on the keyboard area to switch between extra keys and text input.

## Settings

- **Transport**: `UDP + WebSocket` provides lower latency. Use `WebSocket Only` when UDP is restricted.
- **Pointer speed**: Controls the multiplier applied to one-finger movement.
- **Pointer precision**: Reduces gain during slow movement and increases it during faster movement.
- **Natural scrolling**: Reverses the scrolling direction.
- **Orientation**: Lock portrait or landscape mode, or follow the system orientation.

## Troubleshooting

### The Mac is not discovered

Confirm that both devices are on the same local network, the server is running, and client isolation is disabled on the router. You can also connect directly using the Mac's local IP address.

### Connected, but the pointer does not move

Check **System Settings > Privacy & Security > Accessibility**, grant the required permission, and restart the server.

### Pointer movement or scrolling does not respond

Switch the mobile app to `WebSocket Only` mode. Also confirm that the firewall allows TCP `9876` and UDP `9877`.

### An iPhone cannot discover the server

Verify that `NSLocalNetworkUsageDescription` and `NSBonjourServices` are present in `Info.plist`, and that local-network access is enabled for the app in iOS Settings.

## Project Structure

```text
remote-mouse/
|-- desktop/                 Swift macOS server
|   |-- Package.swift
|   `-- Sources/
|       |-- WebSocketServer.swift
|       |-- UDPServer.swift
|       |-- Message.swift
|       |-- MouseController.swift
|       `-- KeyboardController.swift
`-- mobile/                  Flutter mobile app
    `-- lib/
        |-- pages/
        `-- services/
```

## Development Checks

```bash
# Flutter static analysis
cd mobile
flutter analyze

# Swift build
cd ../desktop
swift build
```

## License

MIT
