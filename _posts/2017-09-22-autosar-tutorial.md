---
layout: post
title:  "AUTOSAR框架介绍（一）" 
date:   2017-09-22 17:55:54
categories: 汽车
tags: autosar 
excerpt: 最近在自学AUTOSAR的一些内容，把学习中收集到的一些资料整理及心得总结一下，作为学习笔记，若有错误及建议，请一定要告诉我，不胜感激。    
mathjax: true
---
* TOC
{:toc}

### What is the AUTOSAR standard and why is it created?

简单来说，AUTOSAR(根据官方视频，读音类似于/'ɔtosə/, AUTomotive Open Systems ARchitecture)中文名称汽车开放系统构架，
是一个由汽车原始设备制造商为汽车制造行业发起制定的一个标准化的软件构架，
目的是解决汽车电子日益曾长的复杂度以及实现硬件与软件的分离。

AUTOSAR有三大主题，分别是构架，方法论，以及应用接口，接下来会以此进行介绍。

### AUTOSAR的构架
![architecture1]({{site.url}}assets/autosar/architecture1.png)  
AUTOSAR构架通常用微控制器层以及运行在之上的三层软件层来表示，从上到下以此为应用层(Applicat ion Layer, 简称AL),
运行时间环境层(Runt ime Environment,简称RTE),基础软件层(Basic Sof t ware,简称BSW),
以及微控制器层.同时BSW又可以细分为四个部分:微控制器抽象层(Microcont roller Abst ract ion Layer, 简称MCAL),
ECU抽象层(ECU Abst ract ion Layer,简称ECUAL),服务层(Services Layer,简称SL),以及复杂驱动层(Complex
Drivers Layer,简称CDL).如下图所示.

##### BSW

MCAL位于BSW层的最底端，它可以利用其内部驱动直接与微控制器通讯，这些内部驱动包括内存，通讯，以及IO驱动.
MCAL的任务是使它之上的层可以与微控制器层独立， MCAL的实现需要依赖微控制器，但是它向上层提供了标准化且与微控制器独立的接口.

ECUAL有为外部设备提供的驱动，并且它可以利用MCAL为其提供的接口从而访问最底层的设备。位于ECUAL之上的层可以通过ECUAL提供的接口
访问设备以及外部设备,而不需要了解任何关于硬件的信息，比如是外部设备还是内部设备，微控制器长什么样等等. 
ECUAL的功能就是使得上层设备与ECU的具体结构独立。由于MCAL的作用，ECUAL实现了与微控制器的独立，但是ECUAL本身还是与ECU硬件相关的，
连接ECUAL的层则既不依赖微控制器也不依赖ECU.

CDL是两个跨越整个BSW层的子组件之一，它通常用来集成一些特殊的功能或者移植自之前系统的功能。
它是唯一位于RTE与微控制器之间的层，一些对时间相应要求严格的设备驱动可以放在这里，
因为放到BWS的其他部分的话，可能因为有多个层或者标准化等原因导致时间过长。同时与AUTOSAR不兼容的一些驱动也可以放在这里。
不管应用，为控制器或者ECU硬件是否存在，在实现以及之后，位于CLD连接层之上的层都依赖于将要集成的功能。

SL位于BSW的最上层，跟随操作系统，SL提供了管理器的集合，比如内存管理器，网络管理器，ECU管理器等,同时诊断服务也在SL.
由于SL部分跨越了整个BSW层，因此它并不是完全独立于微控制器以及ECU硬件的，然而它面向RTE的接口却是完全独立于微控制器及ECU硬件的。

![architecture2]({{site.url}}assets/autosar/architecture2.png)  

##### RTE 

RTE是位于AL与BSW之间的一层，它从服务层给应用软件提供服务.SWC之间的所有通讯都要通过RTE,不管是运行在相同还是不同的ECU上. 
RTE的目的就是使得RTE之上的层跟RTE之下的层完全独立。换句话说，运行在ECU上的SWC是不知道ECU长什么样子的，
因为SWC不经过任何修改就可以运行在长相不同的ECU上。

逻辑上可以RTE可以看做能实现不同SWC功能的两部分:通讯及调度

实现RTE时，它是依赖ECU和应用的，这样它被明确地设计为针对不同长相的ECU. 并不是SWC去自适应不同的ECU，而是RTE做这个工作,
这样SWC保持不变就可以完成任务。

##### AL

AL与另外两层不同，它是基础成分且没有标准化，SWC是这层以及AUTOSAR的关键部分，并且已经作为专用部分。创建SWC以及其在AL中的行为可以根据
供应商的需求自由完成。唯一的限制条件是，所有与其他部分的通信，不管是在内部还是相互之间的通讯，都必须通过RTE用标准化的方式完成。

因为RTE使得它之上的层独立于硬件，比如ECU以及微控制器，除了极个别情况，AL只依赖于RTE. 
比如传感器-执行器 SWC 依赖于硬件但是 SWC的通讯并不依赖于硬件.


