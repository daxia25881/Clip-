# Clip 魔改版

> 基于 [rileytestut/Clip](https://github.com/rileytestut/Clip) 二次开发的 iOS 剪贴板管理器，新增云同步、WebDAV 上传、Bark 推送等实用功能。

[![Swift Version](https://img.shields.io/badge/swift-5.0-orange.svg)](https://swift.org/)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)
[![Platform](https://img.shields.io/badge/platform-iOS%2013+-lightgrey.svg)](https://www.apple.com/ios/)

<p align="center">
<img title="Clip Main Screen" src="https://user-images.githubusercontent.com/705880/63391950-34286600-c37a-11e9-965f-832efe3da507.png" width="320">
</p>

## ✨ 新增功能

相比原版 Clip，魔改版新增以下功能：

| 功能 | 说明 |
|------|------|
| 📤 **WebDAV 云同步** | 将剪贴板内容自动上传至 WebDAV 服务器，实现跨设备同步 |
| 🔔 **Bark 推送通知** | 通过 [Bark](https://github.com/Finb/Bark) 推送剪贴板内容到其他设备 |
| 📝 **自定义保存路径** | 可自定义剪贴板内容的存储目标路径 |
| 🔕 **通知开关控制** | 分别控制剪贴板通知和云同步通知的显示 |

## 🎯 原版功能

- 🔄 后台静默运行，持续监控剪贴板
- 📋 保存文本、URL 和图片
- 🗂 复制、删除、分享剪贴记录
- 📊 可自定义历史记录数量上限（10/25/50/100条）
- 📍 位置图标显示开关

## 📱 系统要求

- iOS 13.0+
- Xcode 11+
- Swift 5.0+

## ⚙️ 配置说明

打开 App 设置页面，可配置以下选项：

### 通知配置
- **剪贴板通知** - 开启/关闭剪贴板变化通知
- **云同步通知** - 开启/关闭云同步结果通知

### 上传配置
- **Target Path** - 自定义保存路径
- **Bark Path** - Bark 推送服务的 API 地址 (例: `https://api.day.app/your-key`)
- **WebDAV URL** - WebDAV 服务器地址
- **WebDAV Username** - WebDAV 用户名
- **WebDAV Password** - WebDAV 密码

## 🚀 编译说明

1. 克隆仓库
   ```bash
   git clone https://github.com/daxia25881/Clip-.git
   ```

2. 更新子模块
   ```bash
   cd Clip-
   git submodule update --init --recursive
   ```

3. 打开 `Clip.xcodeproj`，在 **Signing & Capabilities** 中更换为你自己的开发者账号

4. 编译运行 🎉

## 📦 安装方式

- **TrollStore**: 使用 `package_ipa.sh` 脚本打包 IPA 后通过 TrollStore 安装
- **AltStore**: 通过 AltStore 侧载安装（需每7天重签）
- **自签名**: 使用开发者证书或企业证书签名

## 📂 项目架构

```
Clip/
├── Clip/                 # 主应用
│   ├── Settings/         # 设置页面（含魔改版新增配置项）
│   ├── History/          # 历史记录页面
│   ├── Pasteboard/       # 剪贴板监控
│   └── ApplicationMonitor.swift  # 后台保活
├── ClipKit/              # 共享框架
│   ├── Database/         # Core Data 数据模型
│   └── Extensions/       # 扩展（含 UserDefaults 配置项）
├── ClipboardReader/      # 通知内容扩展
├── ClipBoard/            # 自定义键盘扩展
└── Dependencies/         # 依赖库（Roxas 等）
```

## 🔧 工作原理

### 后台保活
通过播放静音音频保持 App 在后台持续运行，绕过 iOS 后台限制。

### 剪贴板监控
使用 Darwin 通知 + 私有 `Pasteboard.framework` 实现系统级剪贴板变化监听。

### 云同步
检测到剪贴板变化后，自动通过 WebDAV 协议上传内容到指定服务器。

## 📜 开源协议

本项目基于 [Unlicense](UNLICENSE) 协议开源，你可以自由使用、修改和分发。

## 🙏 致谢

- [rileytestut/Clip](https://github.com/rileytestut/Clip) - 原版 Clip 项目
- [rileytestut/Roxas](https://github.com/rileytestut/roxas) - iOS 工具框架
- [Finb/Bark](https://github.com/Finb/Bark) - iOS 推送服务

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/daxia25881">daxia25881</a>
</p>
