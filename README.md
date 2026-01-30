# 📋 Clip 魔改版 - iOS 跨设备剪贴板同步

> 基于 [rileytestut/Clip](https://github.com/rileytestut/Clip) 深度改造的 iOS 剪贴板管理器，实现与 PC 端的双向实时剪贴板同步。

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://www.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Unlicense-green.svg)](./UNLICENSE)

## 🎯 项目简介

本项目是一套完整的 **iOS ↔ PC 剪贴板双向同步方案**，通过 WebDAV 作为中转，实现跨设备的剪贴板内容实时同步。

### 配套项目

| 端 | 项目 | 说明 |
|:--:|------|------|
| � iOS | **Clip 魔改版**（本项目） | 剪贴板监控 + 云同步客户端 |
| � PC | [HuChuan](https://github.com/daxia25881/huchuan) | Windows/macOS 剪贴板同步工具 |

---

## 🔄 同步架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         WebDAV 服务器                            │
│                    (坚果云/Nextcloud/Infini)                      │
│                                                                 │
│   ┌──────────────────┐         ┌──────────────────┐            │
│   │ SyncClipboard.json│         │   Bark 通知文件   │            │
│   │   (剪贴板内容)    │         │   (同步触发信号)  │            │
│   └────────┬─────────┘         └────────┬─────────┘            │
└────────────┼───────────────────────────┼───────────────────────┘
             │                           │
      ┌──────┴──────┐             ┌──────┴──────┐
      │   上传/下载  │             │  写入/监听   │
      └──────┬──────┘             └──────┬──────┘
             │                           │
┌────────────┴───────────────────────────┴────────────────────────┐
│                                                                 │
│  ┌─────────────────┐                    ┌─────────────────┐     │
│  │   📱 iOS 端      │                    │   💻 PC 端      │     │
│  │   Clip 魔改版    │◀──────────────────▶│   HuChuan       │     │
│  └─────────────────┘                    └─────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## � 上传流程（iOS → PC）

```
iOS 复制内容
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 1️⃣ Darwin 通知检测到剪贴板变化                        │
│    (使用私有 Pasteboard.framework)                   │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 2️⃣ 借助 CopyLog 后台静默获取剪贴板内容                 │
│    (提取指定文件夹中最新的剪贴板文件)                   │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 3️⃣ 将内容保存到 Clip 的 SQLite 数据库                 │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 4️⃣ 上传到 WebDAV 服务器 (SyncClipboard.json)         │
└─────────────────────────────────────────────────────┘
     │
     ▼
PC 端 HuChuan 检测到云端更新，自动下载并写入本地剪贴板
```

---

## � 下载流程（PC → iOS）

```
PC 复制内容
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 1️⃣ HuChuan 检测到剪贴板变化，上传到 WebDAV            │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 2️⃣ HuChuan 发送 Bark 通知 (值为 "1")                 │
│    作为 iOS 端的同步触发信号                          │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 3️⃣ iOS 监听 Bark 文件夹的写入事件                     │
│    检测到新文件，触发同步                             │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 4️⃣ 从 WebDAV 下载剪贴板内容                          │
│    保存到 Clip 的 SQLite 数据库                       │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────┐
│ 5️⃣ 触发本地通知，用户下拉即可将内容保存到剪贴板         │
│    (利用 ClipboardReader 扩展)                       │
└─────────────────────────────────────────────────────┘
```

---

## 🛠 技术实现

### 核心模块

| 模块 | 文件 | 功能 |
|------|------|------|
| **剪贴板监控** | `PasteboardMonitor.swift` | 使用 Darwin 通知 + 私有框架监听系统剪贴板变化 |
| **后台保活** | `ApplicationMonitor.swift` | 播放静音音频保持 App 持续后台运行 |
| **云同步服务** | `ClipKit/Database/` | WebDAV 上传/下载 + SQLite 存储 |
| **通知扩展** | `ClipboardReader/` | 下拉通知时读取剪贴板并保存 |

### 配置项

在设置页面可配置以下参数：

| 配置项 | 说明 |
|--------|------|
| **Target Path** | CopyLog 剪贴板文件的存储路径 |
| **Bark Path** | Bark API 地址，用于接收同步触发通知 |
| **WebDAV URL** | WebDAV 服务器地址 |
| **WebDAV Username** | WebDAV 账号 |
| **WebDAV Password** | WebDAV 密码 |
| **剪贴板通知** | 是否显示剪贴板变化通知 |
| **云同步通知** | 是否显示云同步结果通知 |

---

## � 安装部署

### 1. 编译 iOS 端

```bash
# 克隆仓库
git clone https://github.com/daxia25881/Clip-.git
cd Clip-

# 更新子模块
git submodule update --init --recursive

# 用 Xcode 打开，修改签名后编译
open Clip.xcodeproj
```

### 2. 打包 IPA

```bash
chmod +x package_ipa.sh
./package_ipa.sh
```

### 3. 安装到 iOS 设备

- **TrollStore**：直接安装打包好的 IPA
- **AltStore**：侧载安装（需每 7 天重签）

### 4. 部署 PC 端

参考 [HuChuan 项目](https://github.com/daxia25881/huchuan) 部署 PC 端同步工具。

---

## 📂 项目结构

```
Clip/
├── Clip/                     # 主应用
│   ├── ApplicationMonitor    # 后台保活
│   ├── Pasteboard/           # 剪贴板监控
│   ├── Settings/             # 设置页面（云同步配置）
│   └── History/              # 历史记录
├── ClipKit/                  # 共享框架
│   ├── Database/             # SQLite + Core Data
│   └── Extensions/           # UserDefaults 扩展
├── ClipboardReader/          # 通知内容扩展
├── ClipBoard/                # 自定义键盘
└── Dependencies/             # 依赖库 (Roxas)
```

---

## � 系统要求

| 要求 | 版本 |
|------|------|
| iOS | 13.0+ |
| Xcode | 11+ |
| Swift | 5.0+ |
| WebDAV | 任意支持 WebDAV 的服务 |

---

## � 相关项目

- [rileytestut/Clip](https://github.com/rileytestut/Clip) - 原版 Clip
- [HuChuan](https://github.com/daxia25881/huchuan) - PC 端同步工具
- [Roxas](https://github.com/rileytestut/roxas) - iOS 工具框架
- [Bark](https://github.com/Finb/Bark) - iOS 推送服务
- [SyncClipboard](https://github.com/Jeric-X/SyncClipboard) - 兼容协议

---

## 📜 许可证

本项目基于 [Unlicense](./UNLICENSE) 协议开源，可自由使用、修改和分发。

---

<p align="center">
  <b>Made with ❤️ by <a href="https://github.com/daxia25881">daxia25881</a></b>
</p>
