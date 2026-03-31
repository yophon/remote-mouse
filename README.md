# Remote Mouse (远程触控板)

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg) ![Swift](https://img.shields.io/badge/macOS-Swift-orange.svg) 

这是一个高性能、低延迟的远程触控板项目。通过手机端的 Flutter 应用，您可以远程控制 macOS 上的鼠标移动、点击、滚动以及拖拽。

A high-performance, low-latency remote touchpad project. Control your macOS mouse movement, clicking, scrolling, and dragging from a Flutter app on your phone.

---

## ✨ 功能亮点 (Features)

- **极低延迟 (Ultra-low Latency)**: 采用 **UDP + WebSocket 混合传输 (Hybrid Mode)**。光标移动走 UDP，关键逻辑（如点击）通过双通道确认。
- **多指手势 (Multi-touch Gestures)**:
  - **单指 (Single-finger)**: 移动光标、轻触单击。
  - **双指 (Two-fingers)**: 轻触右击、双指滑动模拟滚轮。
- **物理按键支持 (Physical Button Support)**: 底部配有大面积左右键，支持**长按拖拽 (Hold to Drag)**。
- **高度自定义 (Highly Customizable)**:
  - **移动灵敏度 (Sensitivity Control)**: 支持从细碎位移到大跨度移动的动态调节。
  - **自然滚动 (Natural Scrolling)**: 根据用户习向切换内容滚动方向。
  - **指针精准度增强 (Pointer Precision)**: 慢速时自动进入亚像素级对齐模式。
- **现代美学与多语言 (Aesthetics & Multi-lang)**:
  - 极简自适应 UI，支持深色模式。
  - 完整的中英文双语切换。
- **触感反馈 (Haptic Feedback)**: 细腻的线性震动反馈，支持在设置中开关。

---

## 🏗️ 技术架构 (Architecture)

- **Mobile**: Flutter 3 (Dart)
  - 监听器 (`Listener`) 捕捉原始触摸点位。
  - 动态计算位移向量与缩放。
  - 自动发现服务 (mDNS/Bonjour)。
- **Desktop (macOS)**: Swift (Native)
  - 底层 `CoreGraphics` 事件注入。
  - `Network.framework` 高效接收混合报文。
  - 消息去重机制 (Deduplicator)，确保 UDP/WS 双发包不重合。

---

## 🚀 快速上手 (Quick Start)

### 1. 服务端 (macOS Server)
进入 `desktop` 目录并运行：
```bash
swift run
```
*首次运行需授予“系统设置 -> 隐私与安全性 -> 辅助功能”权限。*

### 2. 移动端 (Mobile App)
确保手机和 Mac 在同一 Wi-Fi 下：
- 运行 Flutter：`flutter run --release`
- 应用会自动搜索局域网内的设备（mDNS），点击即可连接。

---

## 🎨 设置指南 (Settings)

- **自然滚动**: 开启后，内容随手指移动；关闭后内容反向。
- **震动反馈**: 可在设置中开启或关闭。
- **光标速度**: 支持浮点数输入，满足专业设计或游戏需求。

---

## 📜 协议 (License)

MIT License. Feel free to use and modify!
