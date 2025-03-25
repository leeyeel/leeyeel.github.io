---
layout: post
title:  "linux下解决微信开机自启动问题" 
date:   2025-03-25 11:12:00
categories: 故障排查
tags: bug troubles 
excerpt: linux原生微信，最近发现有开机自启动问题，遂排查并解决。
mathjax: true
---
* TOC
{:toc}

#### 事件起因

- 使用桌面系统版本为ubuntu 24.04 LTS

安装了微信linux版本，版本为4.0.0测试版，x86版。
最近使用时发现，每次开机微信总是会自动启动。联想到国内软件的一贯作风后，
本能的就以为是腾讯的问题。然后在设置中查找是否默认开了开机自启，发现没有，

如下图:![]({{site.url}}assets/wechat/wechat1.png)

考虑到国内软件的一贯作风，觉得还是软件问题，于是又进行了下面的一系列排查。

#### 排查流程

1. 登录进入微信后，排查是否有开机自启动选项勾选。发现没有。

![]({{site.url}}assets/wechat/wechat2.png)

大概是测试版，刚开始，乱七八糟的功能还没带过来，
所以看着还是挺简洁的。

2. 排查常用的开机自启动方法中是否有微信。

通常情况下，Linux下的应用自启动常见于以下位置：

- 系统级：/etc/xdg/autostart/
- 用户级：~/.config/autostart/
- Systemd服务：/lib/systemd/system/

其中我的`~/.config/autostart/`这个目录是空的，其他两个虽然有很多项，
但是通过查找wechat关键字，都没有找到任何相关项。

3. 查看微信安装包中是否有什么可疑似行为。

那只能通过微信安装包本身来排查了，

    1. 使用`ar x`命令解压WeChatLinux_x86_64.deb

    ```bash
    ➜  wechat ls
    control.tar.xz  data.tar.xz  debian-binary 
    ```
    其中control.tar.xz 为包控制信息，data.tar.xz  是真正的安装文件，debian-binary 为版本标识。

    2. 使用`tar -xf`解压control.tar.xz 及data.tar.xz

    ```bash
    ➜  wechat ls
    control  control.tar.xz  data.tar.xz  debian-binary  opt  postinst  postrm  prerm  usr 
    ```
    有价值的主要是`postinst`以及`usr`文件夹，前者是个安装脚本，里面可以进行设置，
    后者是个文件夹，里面可能有相关的设置。

    3. 分别排查`postinst`以及`usr/share/applications/wechat.desktop`文件：
    都没发现与自启动相关的内容，`postinst`是个脚本，太长了就不贴了,
    wechat.desktop中也没有与`Autostart`相关的设置。也可以排除。
    ```
    [Desktop Entry]
    Name=wechat
    Name[zh_CN]=微信
    Exec=/usr/bin/wechat %U
    StartupNotify=true
    Terminal=false
    Icon=/usr/share/icons/hicolor/256x256/apps/wechat.png
    Type=Application
    Categories=Utility;
    Comment=Wechat Desktop
    Comment[zh_CN]=微信桌面版
    ```
4. 排除所有不可能，那么

以上都是微信客户端主动能做的常规操作，如果微信客户端确实没做，
那就是只剩下被动自启动了，就是系统的会话恢复机制。

GNOME 桌面默认有“Session Restore”功能，可能会自动恢复之前运行的程序，误以为微信“自动启动”。


#### 解决方案

知道了原因，自然就好解决了，主要是从不报错，报错后不恢复两方面解决。

1. 关机时先退出微信，然后再关机。(这应该是微信客户端的问题)
2. 禁用桌面恢复机制:

```
gsettings set org.gnome.SessionManager auto-save-session false
```

#### 对不起，腾讯

竟然不是软件自己的逻辑，真的要对腾讯说声对不起，虽然，但是这次冤枉你了。

