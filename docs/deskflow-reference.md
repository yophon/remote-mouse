# 借鉴 Deskflow

> [Deskflow](https://github.com/deskflow/deskflow) 能让几台电脑共用一套键盘鼠标(Synergy 的开源上游,C++20 + Qt 6,GPL-2.0)。它和 Remote Mouse 的输入来源不同:Deskflow 是另一台电脑的实体键鼠,Remote Mouse 是手机触屏。后半段是一样的:都要在电脑上模拟出鼠标键盘事件。所以 Deskflow 不能直接拿来用,但有三处值得借鉴,按收益排序如下。
>
> 记录于 2026-10-29,对照的是 Deskflow `master` 当时的代码。

| | 输入从哪来 | 在哪里生效 |
|---|---|---|
| Deskflow | 一台电脑的实体键盘鼠标 | 另一台电脑(Windows / macOS / Linux,含 Wayland) |
| Remote Mouse | 手机触屏手势 | 只有 macOS(Swift + CoreGraphics) |

## 一、配对和加密(先做)

**现状**:没有任何鉴权,也不加密(README 里写了)。局域网里谁连上 `9876` / `9877` 端口都能往 Mac 发按键,等于能在这台电脑上打开终端敲命令。

**Deskflow 的做法**:连接走 TLS,第一次连上时在电脑上显示对方的证书指纹,确认后记进指纹库,以后自动信任。

- `src/lib/net/Fingerprint.cpp`、`src/lib/net/FingerprintDatabase.cpp`:算指纹、存指纹、比对
- `src/lib/gui/dialogs/FingerprintDialog.cpp`:首次连接时的确认弹窗

**照做的思路**:

- Mac 端:第一次启动时生成自签证书,WebSocket 改走 TLS(Network.framework 的 `NWProtocolTLS`)。
- 配对:手机第一次连接时,Mac 弹窗(或菜单栏提示)显示手机的名称和一个短码,两边核对后确认;手机记住 Mac 的证书指纹,Mac 记住已配对的手机。之后指纹对不上就拒绝连接。
- UDP 通道(`9877`):TLS 管不到这一路。可以用握手后协商出来的会话密钥给每个包加 MAC,并带上递增序号防重放;或者只接受已经建立 WebSocket 会话的那个来源地址,收没有校验的包直接丢弃。这两种做法哪种好,要在改动方案里再定。

## 二、把服务端扩到 Windows / Linux 时的参考

Deskflow 按平台把"模拟输入"分得很清楚(都在 `src/lib/platform/` 下):

| 平台 | 文件 | 要点 |
|---|---|---|
| Windows | `MSWindowsComputer.cpp`、`MSWindowsKeyState.cpp`、`MSWindowsHook.cpp` | 用 SendInput 模拟输入,处理键盘布局 |
| macOS | `OSXComputer.mm`、`OSXKeyState.cpp`、`OSXKeyLayoutResource.cpp` | 可以和现在的 `MouseController.swift` / `KeyboardController.swift` 对照 |
| Linux X11 | `XWindowsComputer.cpp`、`XWindowsKeyState.cpp` | 用 XTest |
| Linux Wayland | `EiComputer.cpp`、`EiKeyState.cpp`、`PortalRemoteDesktop.cpp` | 用 libei,通过 XDG RemoteDesktop portal 申请授权(系统会弹窗)。这是最难的一块,Deskflow 是目前最好的参考 |

**许可证**:Deskflow 是 GPL-2.0,本仓库目前没有 LICENSE 文件。参考思路、自己重写没问题;直接复制代码过来,整个项目就得按 GPL 发布。

## 三、手机端加一个"Deskflow 模式"(可选)

**设想**:让手机实现 Deskflow 协议、扮演"主机"(Deskflow 里叫 server),电脑上装 Deskflow 当客户端。这样不用写任何电脑端程序,就能控制三个平台,包括 Wayland。

**协议**:`src/lib/deskflow/ProtocolTypes.h` 里有完整说明,当前版本是 1.8。

| 消息 | 作用 |
|---|---|
| 握手 `"Barrier"` + 主版本号 + 次版本号 | 也兼容 `"Synergy"` 这个名字 |
| `CINN` | 光标进入这台电脑的屏幕(带坐标、序号、修饰键状态) |
| `DMMV` / `DMRM` | 鼠标绝对移动 / 相对移动(触控板用相对移动) |
| `DMDN` / `DMUP` | 鼠标按键按下 / 抬起 |
| `DMWM` | 滚轮 |
| `DKDN` / `DKUP` / `DKRP` | 键盘按下 / 抬起 / 重复 |
| `CALV` | 心跳 |
| `QINF` / `DINF` | 查询 / 上报客户端屏幕信息 |

**硬伤**(所以只适合当附加功能,不能替代现在的架构):

- **连接方向是反的**:Deskflow 是客户端去连主机,所以要电脑去连手机(手机监听 `24800`),在电脑上填手机的 IP;手机 IP 一变就得重新改。
- **Deskflow 默认开 TLS**:手机要当 TLS 服务端,生成自签证书,电脑第一次连接时确认指纹。
- **只能走 TCP**,没有现在用来降延迟的 UDP 通道,延迟抖动要实测。
- **要用户先装好并配置 Deskflow**,客户端的屏幕名要和主机这边的配置对上,对普通用户门槛偏高。
- **多指手势**(缩放、三指切换)只能翻译成滚轮或快捷键。
- **中文等非拉丁字符**能不能通过 `DKDN` 正确输入,要实测。

## 四、建议顺序

1. 先做第一节的配对和加密。现在这样暴露在局域网里是实打实的风险,改动也不大。
2. 要不要跨平台,看目标:
   - 想要一个手感统一的完整产品 → 走第二节,自己写 Windows / Linux 服务端,参考 Deskflow 但不抄代码。
   - 只是想低成本照顾已经在用 Deskflow 的人 → 第三节作为一个附加的连接方式。
