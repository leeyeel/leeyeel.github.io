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

![]({{site.url}}assets/wolp/wolp2.png)

### 软件解析

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

2. openwrt中的etherwake及wol介绍

在 OpenWRT 中，主要有两个软件用于 Wake-on-LAN（WOL）：etherwake与wol

etherwake 是一个 C 语言编写的工具，用于通过 MAC 地址 发送 Wake-on-LAN 数据包。
它只能通过mac地址直接发送,所以无法跨网段，但是可以指定网卡。而wol支持指定ip及端口，所以实际上可以跨网段唤醒。

不过默认安装的话，openwrt采用的是ethernet。

3. LuCI文本国际化

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

4. WOL协议 

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

所以目标MAC地址，源MAC地址，以太网帧类型，以及 WoL数据，已经116字节，
同时WoL数据还支持附加数据作为密码，我们选为6字节，所以总共为122字节。

使用关机功能时，就是通过对比服务端发送的关机信号中的密码，
是否与客户端的密码相同，相同的话才会执行关机指令。

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

由于需要唤醒设备，唤醒设备通常是直接网卡的硬件唤醒，所以直接使用以太网帧，
即原始帧数据。

5. WOL数据中的源地址，目标地址

实际使用过程中，发现是这个顺序：`目标 MAC | 目标 MAC | 帧类型 | WOL 数据`，
即源 MAC 地址丢失，变成了目标 MAC 地址,如图，开头的数据都是目标地址。
![]({{site.url}}assets/wolp/wolp1.png)

这通常发生在 br-lan 发送 WOL 数据帧时。至于为什么br-lan让源MAC变成目标MAC，
是因为在Linux Bridge 的默认行为下：
    -   如果数据包是广播/组播
        - br-lan 可能会覆盖源 MAC 地址
        - 使其 看起来像来自目标设备
        - 主要用于 防止环路 和 广播风暴
    - 如果 WOL 数据包是单播
        - 可能不会出现这个问题
        - 但如果是广播，则源 MAC 可能会被修改

当然也有解决方案，但这个通常没什么影响，除非希望设计更严格的验证。
偷懒的话，就不验证这个MAC地址了。

6. 添加守护

无论linux还是windows，如果想保证持续运行监听关机信号，就需要添加守护。
相比较来说，在ubuntu上添加守护很简单，只需要配置好systemctl的配置即可。
重点是windows的守护。

windows守护常见的就是添加到windows服务中，但是添加windows服务有太多太多方案，
我希望的是尽可能与linux下的代码兼容。

windows服务中不像 Linux 那样直接监听 SIGTERM 或 SIGKILL 信号，
Windows 服务的 启动、关闭 是通过 Service Control Manager (SCM) 进行管理的，
而不是通过 UNIX 信号机制。
这就导致如果需要监听信号的话，需要使用`golang.org/x/sys/windows/svc`这样的三方库，
当然使用三方库也不是不可以，比较不好的是没法与linux兼容。

那有没有更好的解决方案，当然有，v2raya就是很好的案例。
网络上找不到v2raya的打包方案介绍，只能看源码，这里顺便介绍下v2raya的打包方案。

- v2raya的go代码在service文件夹中

go代码部分并没有使用类似`golang.org/x/sys/windows/svc`这样的三方库`来监听服务控制消息，
甚至就没有专门处理系统消息，相当于写代码时不需要考虑守护这回事。

- 使用Inno setup打包

当然也可以不使用inno setup打包，但是inno确实很方便，v2raya对于windows提供两种方案，
这里只参考inno setup打包的方案。

- inno 脚本中使用了winsw包装windows服务

winSW包装windows服务的好处就是，winSW能把普通应用直接包装为windows服务，
而不需要处理windows服务相关的控制消息。在v2raya的iss脚本中，可以看到如下代码：

```bash
[Run]
Filename: "{app}\{#MyAppExeName}"; Parameters: "install";
Filename: "{app}\{#MyAppExeName}"; Parameters: "start";
```
这里的`MyAppExeName`定义为`#define MyAppExeName "v2rayA-service.exe"`。

这里很具有隐蔽性，实际`v2rayA-service.exe`就是`winSW.exe`,之所以要改名字，
是因为winSW会根据本身的名字来默认创造一些服务名字，使用`v2rayA-service.exe`就可以省略掉一些参数。

这部分工作是在github的工作流中完成的，在`.github/workflows/./release_main.yml`中有如下代码片段：

```bash
 Invoke-WebRequest $Url_WinSW -OutFile "D:\WinSW.exe"                                                                        
 Copy-Item -Path "D:\WinSW.exe" -Destination "D:\v2raya-x86_64-windows\v2rayA-service.exe"
```

也就是这里把winSW拷贝为了`v2rayA-service.exe`

还有一点，使用inno 脚本打包为exe的时候，用户直接运行exe就可以安装应用程序，
是因为inno 打包工具直接把winSW也打包进去了。

