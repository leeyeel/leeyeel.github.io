---
layout: post
title:  "从单片机开发到linux驱动开发" 
date:   2019-03-17 18:42:00
categories: 学习笔记
tags: 单片机 MCU Linux 驱动 区别
excerpt: 本文适用于有单片机开发基础，但对Linux驱动开发没经验的小伙伴
mathjax: true
---
之前一直做汽车电子的MCU驱动开发，接触过的大都是NXP的汽车级芯片，主要为PowerPC构架的一些MCU，
也有ARM构架的Cortex-M3内核以及Cortex-M4内核的MCU。最近入手S3C2440开发板一个，想借此了解下Linux驱动开发。
熟悉几天之后总结了一下与之前驱动开发的区别。刚拿到开发板的时候完全不知道如何操作，其实了解到这些区别后上手Linux驱动开发几乎是没难度的。

### 区别一: 单片机程序大都是直接运行在片内FLASH的，而跑Linux的芯片则不是, 所以启动方式不同。

之前接触的MCU自带片内FLASH，片内Flash为Nor Flash,与内存统一编址。程序直接运行在FLASH中，
使用Keil, CodeWarrior等IDE借助仿真器就可以直接单步调试。这是因为在裸机，或者轻量级操作系统(uC/OS, FreeROTS等)时，代码量都很小，
MCU自带的1M或者2M的片内flash足以容纳这些代码量。尽管片内FLASH的价格稍贵，但是考虑到带来的巨大便捷以及单片机往往只需要较小的容量即可满足需求，
大部分单片机MCU都自带片内FLASH。

当需要运行Linux时，代码量相对较大，使用片内FLASH往往无法满足需求，Nor FLASH的价格又偏贵, 使用几十M的Nor FLASH意味着更高的成本。
所以此类芯片往往需要使用外挂Nand FLASH启动。Nand FLASH需要有驱动支持才可读写，主控芯片并不知道外挂的Nand FLASH型号，所以无法直接读取。
使用Nand FLASH启动时，CPU会自动把NAND FLASH前4K的数据复制到片内RAM中执行，这个片内RAM被成为“跳板"(Stepping Stone)。
利用这一点可以在NAND FLASH的前4K中初始化硬件，包括外挂RAM，并把程序复制到外挂RAM中，从而实现启动。

### 区别二: 跑Linux的芯片大都没有片内FLASH, 只有NAND FLASH，所以烧写过程不同。

开发单片机主控芯片时，由于具有片内FLASH，烧写可以直接通过仿真器完成。开发Linux主控芯片时，我们常用的J-Link仿真器不支持NAND FLASH烧写
（有些仿真器比如Lauterbach支持NAND FLASH烧写)，所以我们无法使用IDE比如Keil直接把程序烧录到开发板。新手到这里就会卡一下。

### 其他区别: 单片机MCU主频较低，内存较小，一般都为片内RAM，能跑Linux的芯片一般主频较高，内存大，需要外挂RAM。

理解了这个区别以后就可以对症下药了:
(未完待续...)
