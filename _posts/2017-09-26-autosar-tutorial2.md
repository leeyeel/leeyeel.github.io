---
layout: post
title:  "AUTOSAR框架介绍（二）" 
date:   2017-09-26 00:29:54
categories: 学习笔记
tags: autosar 
excerpt: 上一部分主要介绍AUTOSAR的构架，下面继续
mathjax: true
---

#### 软件成分

AUTOSAR使用它自身的记号来模型化应用. 一个应用包含一个或多个基于应用层的SWC. 为了让SWC可以与其他SWC交流，
AUTOSAR使用VFB(virtural functional bus). 从SWC的角度来说，SWC所看到的一切均为VFB,而不是依赖于硬件的BSW以及硬件本身。
总体上VFB的实现不仅靠RTE还靠BSW. 两个相互关联的SWC是否在相同的ECU上并不重要，他们都连接在相同的VFB上而且并不需要知道另一个位于何处。

汽车的功能既不能放到一个简单的组分里也不能散播到太多的组分.一个组分除了实际的实现之外往往还伴随着SWC的描述文件。
除其他部分外一个描述文件包括:

* 普通属性
  * 名字
  * 制造商

* 通讯性质
 * PPorts
 * Rports
 * Interfaces

* 内部构造
  * 子成分
  * 连接

* 需求硬件资源
  * 处理时间
  * 调度
  * 内存

了解对于每个SWC的硬件需求信息使得决定一个特殊的ECU放置在何处变得容易起来。如果有这种情形，两家供应商提供了功能相似的组件，
但是稍微好的那家需要更高的硬件需求，并且必须要给系统增加另一个ECU，这时我们便可以据此决定怎么做。如果我们没办法增加ECU的数量，
这时候我们只能使用性能差一点但是需求硬件资源低的那一个。

在VFB层开发系统关注的中心是被称为SWC的基础构件块. 一个组件有用来与其他组件交流的端口，任何一个端口只能被分配到一个具体的组件上.
组件实现的功能的复杂性随着端口数目的变化差异很大。AUTOSAR允许相同组分的多个实例化存在，为了存储实例特有的数据相同的实现有不同的内存空间.
#### 端口

SWC有两种端口，PPort 提供在接口中定义的数据，而 RPort 反而需求数据，对于发送者-接受者以及客户-服务器接口,AUTOSAR也存在服务版本。

#### 接口

AUTOSAR提供三种接口类型:客户-服务器,发送者-接受者，以及刻度.

##### 客户-服务器
 客户-服务器 模式非常出名并且被广泛应用. 服务器提供服务同时可能用到一个或多个客户端来执行任务。 AUTOSAR中定义客户-服务器模式很简单的定义为
n:1(n>=0, 1个服务器).调用服务器的操作使用客户端提供的参数来执行需要执行的任务，这些参数类型即既可以是简单型(bool)也可是复杂类型(数组).

当客户端想要调用服务器接口的指令时，必须提供每一个操作指令的参数. 当收到回应时，这个客户端不是好的就是坏的.可能的回复类型有三种:

* 可用的回应,服务器可以执行需求指令并且左右操作接口参数已经被赋值.
* 基础设施错误, 因为总线故障使得通向或者接收服务器的通信出现错误.例如由于客户端的超时导致回应指令永远无法返回客户端。
* 应用错误,有时当执行客户端调用的指令时服务端发生故障.

正如上文中指出的，AUTOSAR只支持n:1的客户-服务端机制. 这意味着任何作为客户端的部分必须有连接到服务器端PPort之一的RPort, 然而这个PPort 
却可以连接到任意数量的RPort. 确认每个回复传输到了正确的客户端的RPort取决于通信的实现. 因为一个组分并没有限制为一个端口或一个端口类型，
一个组分以及相同的组分既可以作为客户端也可以作为服务器.

客户端如何调用服务端存在限制,在同一个客户端的RPort上，相同指令的两个调用是不能同时调用的，必须等到第一个调用收到响应,好的或者坏的那个，
才可以再次调用相同的指令。 在相同RPort上不同操作的同时调用是允许的，但是VFB并不保证调用的次序，
即服务器先看到哪个调用的次序或者收到来自于服务器的次序. 然而VFB必须要使得客户端与之前的调用相对应。

当组分为客户-服务端模式时，他们有自己的图形接口表示方法,如下所示:  
![]({{site.url}}assets/autosar/graphical-c-s.png)

##### 发送者-接收者

当组分为发送者-接收者模式时，他们有自己的图形接口表示方法,如下所示:  
![]({{site.url}}assets/autosar/graphical-s-r.png)

##### 刻度

当组分为刻度模式时，他们有自己的图形接口表示方法,如下所示:  
![]({{site.url}}assets/autosar/graphical-c.png)

#### 组分类型
AUTOSAE有其中组分类型:

##### 应用层组分(Application software component)
应用层组分实现完整的功能或者仅仅部分功能。这部分是原子性不可再分且有访问所有AUTOSAR通讯及服务的权限。传感器-驱动器组建用来处理所有
传感器与驱动器的相互作用.
##### 传感器-驱动器(Sensor-actuator software component)
所有传感器-驱动器相关的任务都由原子性的传感器-驱动器SWC处理，正是传感器与驱动器通过提供与硬件独立的接口，使得其他SWC使用传感器或者驱动器成为可能。
为了实现这些它需要访问ECUAL的权限。
##### 刻度参数组分(Calibration parameter component)
它唯一的功能是为刻度所有连接的组分提供参数值.
##### 混合(Composition)
##### 服务组分(Service component)
##### ECU抽象组分(ECU-abstraction component)
##### 复杂设备驱动组分(Complex device driver component)

### 运行实体
一个运行实体是SWC内部最小的代码片段。正是这些运行实体映射到OS任务并且实施SWC的行为。需要这部分是因为SWC自己并不能意识到存在所有OS功能的BSW层。
一个SWC可能有多个来运行某个任务的运行实体。

有两类运行实体:

* 类别1 是所有没有任何等待点的运行实体.也就是说，这些运行实体可以确认在有限时间内完成.类别1又分为两个子类别，1A仅能使用阴性定义的API，
1B是1A的扩展，可以使用显性定义的API并且可以使用服务器提供的功能.

* 类别2 中的运行实体包含至少一个等待点，除了极少数例外，所有类别2的运行实体严格映射到一个扩展任务，因为它是唯一提供等待状态的任务类型。

RTE事件简称 RTEEvents,通过激活或者唤醒来触发运行实体的执行。

<table border="1">
<tr>
<td> Name     </td>
<td>Communication restriction </td>
<td> Description </td>
</tr>
<tr>
<td> TimingEvent  </td>
<td> None </td>
<td> Triggers a runnable periodically. </td>
</tr>
<tr>
<td> DataReceiveEvent  </td>
<td> Sender-receiver only  </td>
<td> Triggers a runnable when new data has arrived.</td>
</tr>
<tr>
<td>OperationInvokedEvent </td> 
<td>Client-server only</td>
<td> Triggers a runnable when a client wants to use one of its services provided on a PPort. </td>
</tr>
<tr>
<td>AsynchronousServerCallReturnsEvent </td>
<td>Client-server only  </td>
<td>Triggers a runnable when an asynchronous call has returned.</td>
</tr>
</table>

### 映射到OS任务
看下面这图就懂了.
![]({{site.url}}assets/autosar/mapping.png)
