---
layout: post
title:  "单片机开发与linux驱动区别要点" 
date:   2019-03-26 00:21:00
categories: 学习总结
tags: 单片机 MCU 驱动 
excerpt: 本文适用于有单片机开发基础，但对Linux驱动开发没经验的小伙伴
mathjax: true
---
* TOC
{:toc}

之前一直做汽车电子的MCU驱动开发，接触过的大都是NXP的汽车级芯片，主要为PowerPC构架的一些MCU，
也有ARM构架的Cortex-M3内核以及Cortex-M4内核的MCU。最近入手S3C2440开发板一个，想借此了解下Linux驱动开发。
熟悉几天之后总结了一下与之前驱动开发的区别。刚拿到开发板的时候完全不知道如何操作，其实了解到这些区别后上手Linux驱动开发是没难度的。

- 区别一: 单片机程序大都直接运行在片内FLASH，Linu程序无法在这么小的片内FLASH上运行, 所以启动方式不同。

之前接触的MCU自带片内FLASH，片内Flash为Nor Flash,与内存统一编址。程序直接运行在FLASH中，
使用Keil, CodeWarrior等IDE借助仿真器就可以直接单步调试。这是因为在裸机，或者轻量级操作系统(uC/OS, FreeROTS等)时，代码量都很小，
MCU自带的1M或者2M的片内flash足以容纳这些代码量。尽管片内FLASH的价格相对昂贵，但是考虑到使用片内FLASH带来便捷以及稳定性，
加上单片机程序往往只需要较小的空间，所以多数单片机MCU都自带片内FLASH。

当需要运行Linux时，代码量相对较大，使用片内FLASH无法满足需求。如果使用几十M的Nor FLASH又会大大提高成本,
所以此类芯片常使用外挂Nand FLASH。NAND FLASH 不像NOR FLASH那样可以按字节读写，只能按Page读写。

这样MCU刚上电时就无法像单片机MCU那样从片内NOR FLASH开始一行一行执行。这就造成了普通单片机MCU启动方式与运行Linux系统的MCU启动方式的不同。

实际上使用Nand FLASH启动时，CPU会自动把NAND FLASH前4K的数据复制到片内SRAM中执行，这个片内SRAM被成为“跳板"(Stepping Stone)。这个过程是由硬件完成的，
不需要NAND FLASH的驱动即可完成。利用这一点可以在NAND FLASH的前4K中初始化硬件以及外挂SDRAM，
并把NAND FLASH中的程序复制到外挂SDRAM中，并跳转到外挂SDRAM中执行，从而完成启动。

- 区别二: 单片机程序可以使用IDE跟仿真器烧写程序到片内NOR FLASH，NAND FLASH的读写需要驱动支持，如果IDE没有NAND FLASH的驱动则无法烧写，所以烧写过程不同。

开发单片机MCU驱动时，由于具有片内FLASH，烧写可以直接通过仿真器比如J-LINK来完成。开发Linux主控芯片时，我们常用的J-Link仿真器(毕竟山寨J-LINK便宜)
不支持NAND FLASH烧写，不过有些仿真器比如Lauterbach是支持NAND FLASH烧写的。这样就造成我们无法使用Keil或者J-Flash等烧录工具把程序烧录到NAND FLASH上。
同时，这也意味着我们无法像调试单片机代码时使用J-Link设置断点单步调试(Lauterbach是可以支持的，毕竟贵)。

- 区别三: 编译环境不一样。在windows下搭建编译Linux内核的交叉编译环境太繁琐，所以大都直接到Linux下去编译。

这跟单片机编译是不一样的，单片机下的交叉编译环境比较容易搭建，或者直接使用Keil或者codewarrior等集成开发环境就好了。
编译Linux一般都是到Linux下编译，然后把编译好的文件烧录到NAND FLASH。

- 区别四: bootloader的作用不同。

单片机开发的bootloader不是必须的，它跟APP其实并没有本质上的不同，作为引导程序的最主要原因是为了方便升级。比如我电池管理系统装到电池包里面，
如果有bootloader,这样哪天发现需要升级的时候直接使用CAN或其他通讯协议就可以升级了，不需要拆包。如果没有bootloader，就只能拆包用仿真器烧写了。
但是对于Linux系统来说，bootloader是必须的，没有bootloader搬运NAND FLASH的程序，就无法实现启动。

- 其他区别

当然还有其他区别，比如运行Linux需要更大的内存，所以SDRAM也是外挂的。比如运行Linux的话CPU主频需更高，通常几百MHz甚至上GHz等等。
不过这些对开发来说并没有本质的影响。对我来说，最重要的其实是前两条。

理解了这些区别以后就可以对症下药了:

- 如果有NOR FLASH，则我们可以使用J-Link把bootloader烧写到Nor Flash,安装好J-Link驱动后使用**J-FLASH ARM**工具即可。具体使用方法可自行google。
- 对于只有NAND FLASH，又没有可以烧写NAND FLASH的仿真器时，我们可以利用Stepping Stone, 烧写程序到Stepping Stone可以使用**J-Link Commander**工具,具体可自行google。
