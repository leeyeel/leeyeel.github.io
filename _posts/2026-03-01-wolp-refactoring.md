---
layout: post
title:  "WOL Plus 重构记录：OpenWrt 远程唤醒与关机工具升级"
date:   2026-03-01 16:02:00
categories: "个人项目"
tags:
  - "OpenWrt"
  - "Wake-on-LAN"
  - "GitHub-Actions"
  - "WebUI"
  - "项目重构"
description: "记录 WOL Plus 的一次重构升级，包括 WebUI、认证、取消关机与 GitHub Actions 打包流程优化。"
keywords: "WOL Plus 重构, OpenWrt 远程关机, Wake on LAN 工具, GitHub Actions 打包"
excerpt: "记录 WOL Plus 的一次重构升级，包括 WebUI、认证与打包流程优化。"
mathjax: true
---

### 背景介绍

有了娃以后给床安装了围栏，然后围栏上又装了配套的蚊帐，导致整个床像个蒙古包，出入都非常不便。
像这样:

![]({{site.url}}assets/wolp/wolp2-1.png)


有时候躺床上了发现电脑没关机。没关机倒是问题不大，毕竟之前都是常年不关机，
但是偏偏机箱上装了三个RGB的风扇。差不多这样:

![]({{site.url}}assets/wolp/wolp2-2.jpg)

使用Wake On LAN可以唤醒设备，但是没有关闭设备的功能，
所以就有了之前的项目，可以实现关机功能。[wake on lan plus——升级版本的网络唤醒](https://blog.whatsroot.xyz/2025/03/05/wolp-introduction/)

当时虽然可以使用，不过首先就是界面简陋，其次如果误操作发送了关机命令，没有一个按钮可以取消这次关机。
就这样凑活用了一年，实在忍无可忍，干脆使用vibe coding 翻新了一遍。

### 代码仓库

源码在这里:

[WOL plus仓库地址](https://github.com/leeyeel/WOL-plus).

### 本次更新内容

#### 1. webui增加了用户名密码

![]({{site.url}}assets/wolp/wolp2-3.png)

这个功能个人用户可能用不到，但是一些多设备的场景比如机房可能会用到。

#### 2. 相应的增加了退出当前用户，修改用户名密码的功能。

#### 3. 增加了取消当前关机的功能。

设备收到关机命令后，会在设定的延迟时间后关机，并且可以看到倒计时。
这个主要是用于误发送关机命令的情况，比如想对设备X发送关机命令，结果不小心选择为了设备Y，那此时设备Y可以自己取消这条关机命令。

![]({{site.url}}assets/wolp/wolp2-4.png)

#### 4. 打包流程优化

![]({{site.url}}assets/wolp/wolp2-5.png)

使用github action 替代了原来的windows客户端的打包。
同时吸取用户的意见，并不是所有用户都linux操作基础，
所以把openwrt端的软件也使用github action直接打包为ipk格式的软件包，
方便用户直接使用。

只不过目前openwrt只有aarch64以及x86_64两个平台，其他平台的用户需要手动安装一下。

### 总结

总的来说无论实现原理，编码内容，还是实现过程都不复杂。但是却一直没有一个好用的开源工具出现，很奇怪。
还有就是对于这种简单，明确的任务，实在是太太太适合vibe coding了。
