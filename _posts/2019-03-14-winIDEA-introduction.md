---
layout: post
title:  "iSYSTEM winIDEA 入门教程" 
date:   2019-03-14 18:42:00
categories: 汽车
tags: 笔记 winIDEA iSYSTEM IC5000 IC5700 使用教程
excerpt: 介绍一下如何使用iSYSTEM 仿真器与 winIDEA 进行代码调试
mathjax: true
---
* TOC
{:toc}

## 目录
- [iSYSTEM介绍](#1)
- [winIDEA使用入门](#2)

<h2 id="1">1. iSYSTEM介绍</h2>

同样来于德国的公司，成立于1986年，总部位于德国施瓦布豪森，靠近慕尼黑。iSYSTEM专注于汽车领域，我们本篇介绍的仿真器为该公司生产的iC5700 On-chip Analyzer，
样子是一个蓝色的大盒子。与仿真器配套的集成开发环境为winIDEA。winIDEA的功能强大，但是由于winIDEA没有编译器，
用惯了keil, CodeWarrior等这类IDE的小伙伴刚开始可能会不知如何下手。其实想想AUTOSAR开发使用的Lauterbach + Trace32的组合，Trace32也不带编译器。  

本篇教程适合刚接触winIDEA的小伙伴，帮助大家快速上手使用。
IC5700实物图见下图:  

![]({{site.url}}assets/iSYSTEM/product_IC5700.jpg)


<h2 id="2">2. winIDEA使用入门</h2>
第一次使用winIDEA的小伙伴直接移步[官方帮助文档](https://www.isystem.com/downloads/winIDEA/help9_12_288/index.html)的Getting Started章节,
如果是RH850 系列就看Getting started with RH850 章节，如果是NXP的芯片就看Getting started with MPC5748G, 由于我用的是NXP 的MPC5606，
所以参照Getting started with MPC5748G这章节。另外我们这次是使用的USB与IC5700连接，使用网线的小伙伴自己看帮助文档就好了。
先把线连接好，PC通过USB连接到仿真器，给仿真器供电，仿真器通过JTAG口连接到开发板，打开仿真器电源。

- 新建WorkSpace  
这里新建的WorkSpace是之后相对路径的根目录，第一次启动winIDEA可能还会弹出**Select Workspace**的对话框，直接关闭就好了。
依次点击**File / Workspace / New Workspace**,输入文件名字并选择位置。如下图所示:

![]({{site.url}}assets/iSYSTEM/newWorkspace.PNG)

注意:官方帮助文档提到在选择OK之后会出现一个选择硬件插件的对话框，如下图所示，可能是因为winIDEA版本原因，我操作时并未弹出此对话框。

![]({{site.url}}assets/iSYSTEM/selectHardwarePlugin.png)

- 硬件配置
这一步主要是选择使用的仿真器类型，根据自己的实际情况操作就是了，我自己使用的是IC5700，官方那个帮助手册里使用的是IC5000。
依次打开**Hardware / Hardware**对话框，选择自己的仿真器,如下图:

![]({{site.url}}assets/iSYSTEM/hardwareConfiguration_1.PNG)

选择好硬件后，点击**Communication**选项卡，在**USB**下拉菜单中选中自己的仿真器硬件，点击**Test**，如果连接成功可以看到下图所示的状态。

![]({{site.url}}assets/iSYSTEM/hardwareConfiguration_2.PNG)

- CPU配置
这一步是选择CPU型号。打开**Hardware / Emulation Options**对话框，点击**CPU**选项卡，根据自己的情况选择CPU类型，由于我是MPC5606,
所以依次选择**PowerPC/OnCE 5xxx /MPC5606B**,主要注意，我的PowerPC里只有OnCE 5xxxx这一个系列,不同的小伙伴看到的可能不一样。如下图所示:

![]({{site.url}}assets/iSYSTEM/CPU.PNG)

- 验证配置是否正确
这一步的目的是在下载数据到MCU之前先验证下之前的操作是否正确。连好线以后依次点击**Debug / Run control / CPU Reset**查看下debug会话是否成功建立。

- 添加下载文件
这一步的目的是把编译好的文件添加到winIDEA,之后就可以把文件下载到MCU中。之所以有这个操作的原因就是winIDEA自身没有编译器，
所以只能先加载第三方工具编译好的文件，然后下载到MCU。
打开**Debug / Files for download**，在**Download Files**选项卡中选择**New**,选中编译好的文件。winIDEA几乎支持所有的格式，由于我们希望可以调试代码，
所以我们这里选择了带有调试信息的elf文件。如果对地址有偏移需求(比如为了不覆盖Boot,APP不应该从0地址开始)，在**Offset**中填入自己想要的数值即可。
具体如下图所示:

![]({{site.url}}assets/iSYSTEM/download.PNG)![]({{site.url}}assets/iSYSTEM/downloadFile.PNG)

- 验证加载文件
官方帮助文档里介绍要验证加载文件，我没有做这一步。直接把帮助文档里的图片拿来。
上一步加载完成文件后点击**OK**,之后在**Download**窗口中选择**Option**选项卡，勾选**Verify against Loaded code**复选框即可。效果如下图:

![]({{site.url}}assets/iSYSTEM/verify.png)

注意：此时点击主菜单栏中的**Debug/Download**是可以把文件烧录到MCU中去的，而且点击运行后还可以运行，但是此时无法查看代码。如下图所示，此时程序已经在运行，
搜索main文件也可以搜索到，但是双击main.c或者右键选择查看源代码均无反应。是因为虽然elf文件中有调试信息，但是并没有全部源代码信息。
要想查看源代码单步调试，需要添加源代码。

- 添加源代码文件
这一步是添加源代码，winIDEA会把源代码与elf中的调试信息自动关联起来。依次点击**Debug / Debug Options / Directories**,点击**New**添加源代码路径，
勾选**Search subdirectories**复选框。关闭窗口，会提示有改变需要重新加载，点击确定，这样源代码就添加完成了。

- 开始Debug
至此我们可以Debug了，点击主菜单中的**Debug / Download**重新下载文件到MCU，搜索main文件，此时双击或者右键查看源代码，即可打开main.c文件，可以直接看到代码。
进入到main函数，设置断点，然后点击运行按钮运行程序，
查看程序是否停在断点处,至此开始你的debug之旅吧。

此处需要注意，winIDEA的断点设置并不是点一下就可以，它需要先把光标停留在想设断点的行(可以设置的断点的行前会有方框标记),然后点击debug工具栏中红色断点工具即可。
直接使用帮助手册中的图:

![]({{site.url}}assets/iSYSTEM/Calypso6Mdebug.png)

上图中间部分C代码，419行处为断点处，其他行有方框的表示可以设置断点的位置。

<h2> 后记 </h2>

写这篇的原因是因为今天第一次使用winIDEA, 发现网上对winIDEA的介绍几乎没有，更没有一篇引导新手入门的教程。
所以自己搜集资料分享给大家，希望有小伙伴在在手足无措的时候，也能快速上手。
