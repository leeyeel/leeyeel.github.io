---
layout: post
title:  "劳特巴赫(Lauterbach)——顶级调试器和仿真器" 
date:   2018-11-25 00:42:00
categories: 杂项
tags: 笔记
excerpt: Lauterbach的调试器跟仿真器真的做到了极致，功能强大到令人发指。
mathjax: true
---
### 目录
* [1. lauterbach简介](#1)
基本介绍，包括硬件及软件。
* [2. 快速调试入门](#2)
* [2.1 查看修改内存](#2.1)
* [2.2 查看修改寄存器](#2.2)
* [2.3 设置断点](#2.3)
* [2.4 系统运行状态](#2.4)

<h2 id="1">1. lauterbach简介</h2>
点击进入[Lauterbach官网](https://www.lauterbach.com/)，跟很多仿真器官网风格类似，
第一次访问还以为是个快倒闭的小公司网站。网站支持多语言显示，点击下侧**Chinese Home**可以切换为中文，**概要**部分对Lauterbach的简单介绍：
```
劳特巴赫是世界上最大的硬件辅助调试工具生产厂商。我们的工程师团队在制造顶级的调试器和仿真器领域拥有超过30年的经验。
```
International Home还有一段介绍：
```
Our product line TRACE32® supports technologies like JTAG, SWD, NEXUS or ETM with embedded debuggers, software and hardware trace and logic analyzer systems for over 3500 cores and CPUs within 250 families like Arm® Cortex®-A/-M/-R, PowerArchitecture, TriCore, RH850, MIPS etc.
```
仅从介绍上看，Lauterbach的产品在支持的接口类型，处理器架构类型，指令集上面非常全面，几乎包含了市面上所有类型，
而其他产品往往只能支持一种或者两种构架，比如Keil uvision支持51及ARM系列。

1. 硬件介绍
硬件为[PowerDebug Pro](https://www.lauterbach.com/frames.html?powerdebugpro.html),通过USB 3.0与PC相连，
另一端根据不同的处理架构使用不同的扩展与MCU相连。实物图如下所示：
![powerdebugpro]({{site.url}}assets/lauterbach/2_powerdebugpro.jpg)
主页上有对不同处理器构架支持扩展的详细介绍。硬件上的连接方式下图所示：
![connections]({{site.url}}assets/lauterbach/1_connection.png)

2. 软件介绍
IDE使用**TRACE32**工具，是我们本文介绍的重点。由于我自己的代码涉及商业信息，不方便截图，所以本文的绝大部分内容跟图片都直接来源于
[Debugger Basics - Training](https://www2.lauterbach.com/pdf/training_debugger.pdf)的官方文档.
**Lauterbach的文档写的非常全面且具体，大部分都配了图并且有举例，如有精力，强烈建议阅读先阅读一遍**&laquo **Debugger Basics - Training** &raquo.
<h2 id="2">1. 快速调试入门</h2>
1.配置过程

参考手册

2.常用调试

