# Remote Mouse

[English](README_EN.md) | 简体中文

![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter)
![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)

Remote Mouse 将手机变成 macOS 的无线触控板和键盘。手机端使用 Flutter 构建，macOS 服务端使用 Swift、Network.framework 和 CoreGraphics 实现。

> 当前版本没有配对、鉴权或加密机制。请只在可信局域网中使用，不要将 `9876` 或 `9877` 端口暴露到公网。

## 功能

- 单指移动光标，轻触左键单击
- 双指轻触右键单击，双指滑动滚动页面
- 独立左右鼠标按键，按住左键时可拖拽
- 手机键盘输入、方向键、功能键和常用 macOS 快捷键
- UDP + WebSocket 混合传输，或仅使用 WebSocket
- Bonjour/mDNS 自动发现，也支持手动输入 IP 和端口
- 光标速度、滚动速度、自然滚动和指针精度调节
- 横屏、竖屏和自动旋转
- 深色模式、触感反馈、中英文界面
- 最近连接记录

## 工作方式

```text
Flutter mobile app
  |-- WebSocket :9876  clicks, buttons, keyboard, reliable events
  `-- UDP       :9877  pointer movement, dragging, scrolling
                         |
                         v
Swift macOS server -> CoreGraphics -> mouse and keyboard events
```

高频事件使用 13 字节二进制报文；点击、按键等关键事件使用 JSON。在混合模式下，关键事件会通过 UDP 和 WebSocket 双发，服务端根据消息 ID 去重。

## 环境要求

### macOS 服务端

- macOS 13 或更高版本
- Swift 5.9 或更高版本
- Mac 与手机连接到同一个局域网
- 终端或服务端程序已获得 macOS“辅助功能”权限

### 手机端

- Flutter SDK，包含 Dart `3.10.7` 或更高版本
- Android 或 iOS 真机

## 快速开始

### 1. 启动 macOS 服务端

```bash
cd desktop
swift run
```

服务启动后会监听：

| 用途 | 协议 | 默认端口 |
| --- | --- | ---: |
| 控制连接与可靠事件 | WebSocket | `9876` |
| 高频指针事件 | UDP | `9877` |
| 自动发现 | Bonjour | `_remotemouse._tcp` |

首次运行时，打开“系统设置 > 隐私与安全性 > 辅助功能”，允许当前终端或服务端程序控制电脑。修改权限后可能需要重新启动服务。

### 2. 启动手机端

```bash
cd mobile
flutter pub get
flutter run --release
```

应用会搜索局域网中的 Remote Mouse 服务。点击发现的 Mac 即可连接，也可以手动输入 Mac 的局域网 IP，默认端口为 `9876`。

## iOS 本地网络权限

iOS 真机需要在 `mobile/ios/Runner/Info.plist` 中声明本地网络和 Bonjour 权限：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>用于发现并连接局域网中的 Remote Mouse 服务</string>
<key>NSBonjourServices</key>
<array>
    <string>_remotemouse._tcp</string>
</array>
```

安装后首次搜索设备时，请允许应用访问本地网络。

## 操作说明

| 手机端操作 | macOS 行为 |
| --- | --- |
| 单指滑动 | 移动光标 |
| 单指轻触 | 左键单击 |
| 快速轻触两次 | 左键双击 |
| 双指轻触 | 右键单击 |
| 双指滑动 | 水平或垂直滚动 |
| 按住底部左键并滑动触控区 | 拖拽 |
| 点击键盘按钮 | 打开远程键盘 |

键盘工具栏提供 `Esc`、`Tab`、方向键、翻页键、修饰键和常用 Command 快捷键。修饰键单击为单次生效，双击为锁定；上下滑动键盘区域可切换扩展按键和文本输入。

## 设置

- **通信方式**：`UDP + WebSocket` 延迟更低；网络限制 UDP 时可切换为 `WebSocket Only`。
- **光标速度**：控制单指移动的倍率。
- **指针精度**：慢速移动时降低增益，快速移动时提高增益。
- **自然滚动**：切换滚动方向。
- **方向**：锁定横屏、竖屏或跟随系统。

## 常见问题

### 找不到 Mac

确认两台设备在同一局域网，服务端正在运行，并且路由器没有启用客户端隔离。仍然无法发现时，可直接输入 Mac 的局域网 IP。

### 已连接但无法控制鼠标

检查“系统设置 > 隐私与安全性 > 辅助功能”中的权限，然后重启服务端。

### 光标或滚动没有响应

在手机端设置中将通信方式切换为 `WebSocket Only`。同时检查防火墙是否允许 TCP `9876` 和 UDP `9877`。

### iPhone 无法发现服务

检查 `Info.plist` 中是否存在 `NSLocalNetworkUsageDescription` 和 `NSBonjourServices`，并确认系统设置中已允许该应用访问本地网络。

## 项目结构

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

## 开发检查

```bash
# Flutter 静态检查
cd mobile
flutter analyze

# Swift 构建
cd ../desktop
swift build
```

## License

MIT
