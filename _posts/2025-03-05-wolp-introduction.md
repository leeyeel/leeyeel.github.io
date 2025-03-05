---
layout: post
title:  "wake on lan plus, 升级版本的网络唤醒"
date:   2025-03-05 16:02:00
categories: 教程
tags: 工具 
excerpt: openwrt上可用的远程唤醒与远程关机工具
mathjax: true
---

### 场景介绍

使用openwrt中的wol网络唤醒软件，可以唤醒局域网中的设备,
但是唤醒后无法关机，所以希望有一个既可以唤醒设备，又可以关机的应用。

### 代码仓库

源码在这里，下面介绍下其中用到的一些之前没用过东西。

[WOL plus仓库地址](https://github.com/leeyeel/WOL-plus).

1. openwrt中luci框架

在 OpenWrt 的 Web 界面（LuCI）中，采用了一种 MVC（Model-View-Controller） 设计模式，
使得应用开发更加结构化和模块化。LuCI 使用 Lua 语言，
并基于 ubus（OpenWrt 的消息总线）和 ubox（日志系统）来与 OpenWrt 系统交互。

在 LuCI 中，MVC 框架的核心目录结构如下：

```bash
/usr/lib/lua/luci
│── controller    # 控制器（C）
│── model         # 数据模型（M）
│── view          # 视图（V）
│── template      # 视图模板
│── dispatcher.lua # 请求分发器
```

LuCI 的 MVC 结构遵循：

- Model（模型）：封装数据访问，通常在 `/usr/lib/lua/luci/model` 
或 `/usr/lib/lua/luci/model/cbi` 目录中。

- View（视图）：定义用户界面的 HTML 结构，存放于 `/usr/lib/lua/luci/view` 目录。

- Controller（控制器）：处理请求、业务逻辑，
并调用相应的 Model 和 View，位于 `/usr/lib/lua/luci/controller` 目录。

可能是因为太过简单，也可能是因为应用本身太早，
Wake on lan这个功能又太稳定，后续没有更新，
实际上wol这个应用并没有使用MVC框架。

Wake On LAN这个应用直接使用了js脚本调用etherwake或者wol这两个应用。

```javascript
if (has_ewk && has_wol) {
    o = s.option(form.ListValue, 'executable', _('WoL+ program'),
            _('Sometimes only one of the two tools works. If one fails, try the other one'));

    o.value('/usr/bin/etherwake', 'Etherwake');
    o.value('/usr/bin/wol', 'WoL');
}
```
完整的脚本位于：`/www/luci-static/resources/view/`

2. LuCI文本国际化

所有中文包都放置在`/usr/lib/lua/luci/i18n/ `这个目录，
luci使用语言翻译的方式与Qt有些类似，实际加载的是二进制文件而不是文本文件。

在js代码中,使用`_()`包含起来的字符串，会被认定是需要翻译的文本。使用xgettext可以提取需要国际化的文本，
例如：`xgettext --from-code=UTF-8 --output=po/luci-app-wol.pot --language=JavaScript --keyword=_ $(find ./ -name
"*.js")`。

gettext生成的是文本文件，但是openwrt使用的是二进制文件，openwrt中提供了转换pot文本文件到mo二进制文件的应用程序，
该应用程序位于luci/modules/luci-base中，是个独立的C语言编写的应用。使用make po2lmo即可单独编译这个应用。

```
git clone https://github.com/openwrt/luci.git
cd luci/modules/luci-base
make po2lmo
```

3. WOL协议 

Wake-on-LAN（简称 **WoL**）是一种 **远程网络唤醒技术**，允许用户通过 **网络** 唤醒处于 **待机** 或 **休眠** 状态的计算机。WoL 主要用于远程管理、节能应用和服务器维护，支持通过局域网（LAN）或互联网（WAN）唤醒计算机。

- WoL 数据帧结构

WoL 依赖 **魔法包 (Magic Packet)** 进行远程计算机唤醒。魔法包是一个特殊的 **以太网帧 (Ethernet Frame)**，其结构如下：

**完整的 WoL 以太网帧结构**

| 字段 | 长度（字节） | 说明 |
|------|------------|------|
| 目标 MAC 地址 | 6 | 目标计算机的 MAC 地址（广播地址 `FF:FF:FF:FF:FF:FF`）|
| 源 MAC 地址 | 6 | 发送者的 MAC 地址（如网关、发送 WoL 的设备）|
| 以太网类型 | 2 | **0x0842** (Wake-on-LAN) 或 **0x0800** (IP, 如果是 UDP 方式) |
| WoL 数据 (Magic Packet) | 102+ | 固定格式的唤醒数据，包含 `FF FF FF FF FF FF` + `目标 MAC 地址重复 16 次` |

- WoL 魔法包 (Magic Packet) 格式

**魔法包 (Magic Packet)** 是 WoL 唤醒数据的核心，其格式如下：

| 数据段 | 长度（字节） | 说明 |
|--------|------------|------|
| 前导同步码 | 6 | `FF:FF:FF:FF:FF:FF`，用于同步和识别 |
| 目标 MAC 地址 | 16 × 6 = 96 | 目标计算机的 **MAC 地址重复 16 次** |

- WoL 传输方式

WoL 数据帧可以通过 **以太网 (Ethernet)** 或 **UDP 广播** 传输：

**以太网帧 (纯广播)**
   - 直接通过二层网络（L2）发送，不需要 IP 地址，仅使用 MAC 地址。
   - **目标 MAC 地址** 设置为 `FF:FF:FF:FF:FF:FF` 进行广播。
   - **以太网类型 (EtherType)** 为 `0x0842` (Wake-on-LAN)。

**UDP 广播（跨子网）**
   - WoL 数据帧通常封装在 **UDP 数据包** 内，以便跨子网传输。
   - 默认使用 **UDP 端口 9（discard）或 7（echo）** 进行广播。
   - UDP 载荷部分仍然是标准 **WoL 魔法包** 格式。

4. 监听以太帧

5. 添加守护
