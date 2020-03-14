---
layout: post
title:  "劳特巴赫(Lauterbach)——Trace32工具的简单介绍" 
date:   2018-11-25 00:42:00
categories: 汽车
tags: 笔记 lauterbach
excerpt: Lauterbach的仿真器真的做到了极致，功能强大到令人发指。
mathjax: true
---
## 目录
- [lauterbach简介](#1)
- [Trace32使用](#2)
    - [查看修改内存](#2.1)
    - [查看修改寄存器](#2.2)
    - [设置断点](#2.3)
    - [系统运行状态](#2.4)

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
仅从介绍上看，Lauterbach的产品在支持多种调试接口类型比如JTAG, SWD, NEXUS等，而且支持多种CPU构架，多种指令集，几乎包含了市面上所有类型，
不仅如此,其调试工具Trace32几乎支持可以运行在任何操作系统:MS-DOS, WINDOWS 3.11, Windows 95/98/2000/ME/XP/Vista/Windows7, Windows NT, OS-9, XENIX, UNIX, Linux, SUNVIEW, 
Open Windows, MOTIF, SCO Open Desktop, Novell Unixware.

- 硬件介绍
硬件为[PowerDebug Pro](https://www.lauterbach.com/frames.html?powerdebugpro.html),通过USB 3.0与PC相连，
另一端根据不同的处理类型使用不同的扩展与MCU相连。实物图如下所示：
![]({{site.url}}assets/lauterbach/powerdebugpro.jpg)
另一端根据不同的处理架构使用不同的扩展与MCU相连。实物图如下所示：

![]({{site.url}}assets/lauterbach/3_powerdebugpro.jpg)

主页上有对不同处理器构架支持扩展的详细介绍。硬件上的连接方式下图所示：

![]({{site.url}}assets/lauterbach/1_connection.png)

- 软件介绍

IDE使用**TRACE32**工具，是我们本文介绍的重点。由于我自己的代码涉及商业信息，不方便截图，所以本文的绝大部分内容跟图片都直接来源于
[Debugger Basics - Training](https://www2.lauterbach.com/pdf/training_debugger.pdf)的官方文档.
Lauterbach的文档写的非常全面且具体，大部分都配了图并且有举例，如有精力，强烈建议阅读先阅读一遍 *Debugger Basics - Training*.
<h2 id="2">2. 调试</h2>

1.配置过程

TRACE32不具备编译器，所以实际使用时只能加载由第三方编译好的APP。为了可以Debug,除了APP外应该还要导入源代码，Trace32会自动关联APP与源代码。
TRACE32实现一系列的烧录，关联源代码的操作可以通过脚本来实现。TRACE32本身带有大量的例子，我们可以直接在例子上修改即可。熟悉了TRACE32的命令之后，
我们再根据自己的需求修改或定制我们自己的脚本程序。

2.常用调试

使用TRACE32调试时，不仅可以像使用其他IDE一样通过鼠标点点点的方式，还可以像Linux的Terminal那样通过输入命令来调试，熟悉时候使用命令行操作会极大的提高效率。

1) 查看数据

TRACE32根据访问类型对可访问的数据做了分类，最主要的类型为程序类与数据类。分类的原因可能是为了兼容不同的处理器构架，
因为对ARM或者Power来说的话Flash地址跟内存地址是统一编址的，不分类也可以。
访问程序类使用

```
Data.List P:0x1234
```
这种格式，P是Program的首字母，不同的内核构架会使用不同的指令集，如果是A*R*M可以使用R,如果是*T*HUMB可以使用T,
如果是Power可以使用V,举例如下：
```
Data.List R:0x1234	；R representing ARM instruction set encoding for the ARM architecture
Data.List T:0x1234	; T representing THUMB instruction set encoding for the ARM architecture
Data.List V:0x1234	; V representing VLE instruction set encoding for the Power Architecture
```
访问数据类使用：
```
Data.Dump D:0x1234	; display a hex dump starting at Data address 0x1234
```
字母D表示Data,若不指定访问类，则使用默认的访问类，Data.Dump的默认类型为Data，Data.List的默认类型为Program。

其他:

对于全局变量来说，不仅可以通过地址访问，还可以直接通过符号访问，比如g_u32Var为某个全局变量，则可直接访问：
```
Data.List g_u32Var	;
```
其他访问类的详细内容请查看手册。

2) 修改内存内容
修改内存内容只需要鼠标指向想要修改的内容然后双击即可。同时命令框中会自动出现对应的命令。见下图:  

![]({{site.url}}assets/lauterbach/4_modifiedMemory.png)

使用命令修改内存内容有如下格式:
```
Data.Set <address>|<range> [%<format>] <value> [/<option>]
```
手册上的例子如下:
```
Data.Set 0x6814 0xaa                ; Write 0xaa to the address 0x6814
Data.Set 0x6814 %Long 0xaaaa        ; Write 0xaaaa as a 32 bit value to the address 0x6814, add the leading zeros automatically
Data.Set 0x6814 %LE %Long 0xaaaa    ; Write 0xaaaa as a 32 bit value to the address 0x6814, add the leading zeros automatically Use Little Endian mode
```
3) 设置断点

- 函数断点

知道函数名字，希望在此函数处设置断点，可以复制函数名，然后点击工具栏中的设置断点按钮，在弹出的窗口中直接粘贴函数名即可。
如下图所示:

![]({{site.url}}assets/lauterbach/9_setBreakPoint.png)

- 设置软件断点

设置断点是调试中肯定会用到的功能，实现断点有软件断点与硬件断点两种。当设置一个软件断点时，断点处的指令会被处理为特殊的指令，
这个指令会让程序暂停并把控制权给调试者。由于软件断点实际上是软件通过特殊的指令实现的，所以软件断点可设置无限多个。由于软件断点是通过检测指令来实现的，
所以通常情况只能对运行在RAM中的代码设置软件断点，不过TRACE32也允许对运行在Nor FLASH中的代码设置软件断点，
详细信息可参考**Software Breakpoints in FLASH (norflash.pdf)**。
软件断点如下图所示,在想要设置断点的地方双击,出现红色小方块(比如428行附近)表示断点设置成功，在**Break**中点击**List**可以查看所有断点，
其中**SOFT**表示这是一个软件断点。

![]({{site.url}}assets/lauterbach/5_softBreakPoint.png)

- 设置硬件断点

硬件断点是通过监测地址来实现的，所以在任何地方均可设置硬件断点。与软件断点不同，MCU通常只支持少量的硬件断点，具体支持的断点数量可查看*Debugger Basics - Training*。
设置的硬件断点如下图所示，其中onChip表示硬件断点。

![]({{site.url}}assets/lauterbach/6_onChipBreakPoint.png)

- 更改默认断点类型

对程序代码来说，默认的断点类型为软件中断，如果代码完全位于ROM中，默认中断类型可以通过**Break - Implementation**来改变，如下图:

![]({{site.url}}assets/lauterbach/7_changeBreakPointType.png)

- 设置硬件中断范围

如果代码位于RAM与Nor FLASH中，则可以定义硬件中断的范围,使用命令格式如下:
```
MAP.BOnchip <range> ;建议TRACE32 在定义的范围内使用硬件中断
MAP.List            ;检查设置
```
举例如下:
```
MAP.BOnchip 0x0++0x1FFF
MAP.BOnchip 0xA0000000++0x1FFFFF
```
实现的效果如下图所示:

![]({{site.url}}assets/lauterbach/8_onChipRange.png)

- 读写断点 

除对程序执行可以设置断点外，Lauterbach还支持对数据读或写设置断点,读写断点的默认类型是硬件断点。
如下图所示，选择**Read**或者**Write**可以设置在flags在被读取或者被写入的时候停止。

![]({{site.url}}assets/lauterbach/10_readBreakPoint.png)

进一步的，还可以设置读取到某个值或者写入某个值时中断，这里不再举例。

- 其他断点

除了上述功能外，Lauterbach还支持条件断点，可根据所选变量是否等于或者不等于某个数值，或者根据某个任务被调用次数是否等于某个值来决定是否中断程序。
Lauterbach的功能非常强大，几乎支持我们能想到的所有断点方式。

4) 其他功能

- 查看运行时间

有时候我们需要知道某个函数或某部分的执行时间，只需要在命令行输入runTime即可。runTime可以显示两个断点的时间，相减即是运行时间。如下图所示:

![]({{site.url}}assets/lauterbach/11_runTime.png)

- 任务占用率

TRACE32可以统计各个人物的CPU占用率, 原理是对PC采样。具体实现方法可参考 *Debugger Basics - Training*,最终实现的效果见下图:

![]({{site.url}}assets/lauterbach/12_taskSampling.png)
