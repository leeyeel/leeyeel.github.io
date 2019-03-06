---
layout: post 
title: "UDS诊断之读DTC信息(19 hex)服务"
date: 2019-03-02 20:36:20
categories: 汽车
tags: 汽车电子 UDS DTC ISO1429 
excerpt: 读DTC信息服务是UDS诊断中比较复杂的一个服务，所以首先介绍它。
mathjax: false
---
## 目录
- [读DTC信息(0x19)服务功能介绍](#1)
- [读DTC信息服务的sub-function介绍](#2)
    - [0x00-ISOSAEReserved](#2.0)
    - [0x01-reportNumberOfDTCByStatusMask](#2.1)
    - [0x02-reportDTCByStatusMask](#2.2)
    - [0x03-reportDTCSnapshotIdentification](#2.3)
    - [0x04-reportDTCSnapshotRecordByDTCNumber](#2.4)
    - [0x05-reportDTCSnapshotRecordByRecordNumber](#2.5)
    - [0x06-reportDTCExtendedDataRecordByDTCNumber](#2.6)
    - [0x07-reportNumberOfDTCByServerityMaskRecord](#2.7)
    - [0x08-reportDTCBySeverityMaskRecord](#2.8)
    - [0x09-reportSeverityInformationOfDTC](#2.9)
    - [0x0A-reportSupportedDTC](#2.10)
    - [0x0B-reportFirstTestFailedDTC](#2.11)
    - [0x0C-reportFirstConfirmedDTC](#2.12)
    - [0x0D-reportMostRecentTestFailedDTC](#2.13)
    - [0x0E-reportMostRecentConfirmedDTC](#2.14)
    - [0x0F-reportMirrorMemoryDTCByStatusMask](#2.15)
    - [0x10-reportMirrorMemoryDTCExtendedDataRecordByDTCNumber](#2.16)
    - [0x11-reportNumberOfMirrorMemoryDTCByStatusMask](#2.17)
    - [0x12-reportNumberOfEmissionsRelatedOBDDTCByStatusMask](#2.18)
    - [0x13-reportEmissionsRelatedOBDDTCByStatusMask](#2.19)
    - [0x14-reportDTCFaultDetectionCounter](#2.20)
    - [0x15-reportDTCWithPermanentStatus](#2.21)
    - [0x16-reportDTCExtDataRecordByRecordNumber](#2.22)
    - [0x17-reportUserDefMemoryDTCByStatusMask](#2.23)
    - [0x18-reportUserDefMemoryDTCSnapshotRecordByDTCNumber](#2.24)
    - [0x19-reportUserDefMemoryDTCExtDataRecordByDTCNumber](#2.25)
    - [0x1A-0x41-ISOSAEReserved](#2.26)
    - [0x42-reportWWHOBDDTCByMaskRecord](#2.27)
    - [0x43-0x54-ISOSAEReserved](#2.28)
    - [0x55-reportWWHOBDDTCWithPermanentStatus](#2.29)
    - [0x56-0x7F-ISOSAEReserved](#2.30)

<h2 id="1">1. 读DTC信息(0x19)服务功能简介</h2>

读DTC信息(0x19)服务是专门设计用来读取DTC(Daignostic Trouble Code)的一个服务,也是跟Diagnostic最为接近关系最为紧密的一个服务。
系统检测到错误后，会把此错误存储起来，存储的标识就是DTC，不同的错误对应不同的DTC, 从用户的角度讲，用户只要读到某个DTC就可以判断某个错误发生了，
更进一步地，系统存储的不仅仅是代表故障标识的DTC, 还保存了其他故障发生时的信息。 用户可以根据这些信息对故障发生时状态做出判断，以此作为故障原因的推断依据。
具体到系统发生错误时如何存储，用户可以不用关心。读取DTC服务的基本思想是通过一系列的sub-function来读取DTC信息，
19服务目前所支持的所有sub-function将会在下一章节中一一介绍。
本文会尽可能包括ISO14229中此章节的所有内容，但是还是希望读者能通读一遍ISO14229原文。

在2013版本中对读DTC信息服务特别做了一些说明:
- 对于一个给定的DTC(比如0x080511)，任何子服务的正向响应中都不会多次上报这个DTC，但是读取DTCSnapshotRecords是个例外，
因为对于同一个DTC可能包含多个DTCSnapshotRecords.
- 当读取DTC(特别是当sub-function = reportDTCByStatusMask)时如果使用了paged-buffer-handling(分页缓冲处理？这个地方不了解，了解的请告诉我，非常感谢),
在响应时DTC的数量有可能会减少。这时 DTC为0x000000 且 DTC Status为0x00, 客户端会忽略这个DTC，认为没有此响应。

<h2 id="2">2. 读DTC信息服务的sub-function介绍</h2>

在ISO14229(2006)版本中，sub-function 只有15个，0x16-0x7F全部为保留未定义，ISO14229(2013)中做了补充，增加了0x16,0x17,0x18,0x19,0x42,0x55这几个。
除此之外ISO14229(2013)在描述语言上也更详细，也容易理解。尽管如此，国内绝大部分还是使用的2006版本，原因大概可能是当年买的代码只支持2006。
如果是初学的话，还是建议直接从2013开始，2013兼容2006版本，更适合学习。

在本章节中，我们会对19服务的所有sub-function进行详细介绍。初学者在读完一遍理解之后，再遇到这些sub-function只看名字就能知道他们是什么功能，
因为他们的功能都写在名字上。

<h2 id="2.0">2.0    0x00-ISOSAEReserved</h2>

0x00在2006版本以及2013版本中都为保留子功能.

<h2 id="2.1">2.1    0x01-reportNumberOfDTCByStatusMask</h2>

从字面意思上来讲这个sub-function的功能是"上报DTC的数量，而这个数目是通过StatusMask决定的"。
上报DTC的数目很好理解，StatusMask是DTC状态的掩码。DTC的状态——Status是个复杂的概念, 这里我们先做简单介绍。DTC的Status由1个Byte表示，
共8个bit,每个bit的名称见下表:

|DTC Status: bit 名称| bit 位置|
| ------| ------ |
| testFailed                        |0|
| testFailedThisOperationCycle      |1|
| pendingDTC                        |2|
| confirmedDTC                      |3|
| testNotCompletedSinceLastClear    |4|
| testFailedSinceLastClear          |5|
| testNotCompletedThisOperationCycle|6|
| warningIndicatorRequested         |7|

其中bit7为高位，bit0为低位。confirmedDTC是任何DTC必须要支持的，其他则可以根据实际情况自定义支持或者不支持。
举例来说，这样如果某个DTC(比如0x123456)的Status为testFailed且testFailedThisOperationCycle, 则Status表示为0x03(00000011<sub>b</sub>)。
reportNumberOfDTCByStatusMask的意思则表示符合StatusMask的DTC的数目。
比如StatusMask为0x02(00000010<sub>b</sub>), 即DTC必须要满足testFailedThisOperationCycle这个条件。
在本例中则由于DTC 0x123456的Status(0x03), 包含了testFailedThisOperationCycle这个条件，此0x123456这个DTC符合StatusMask的要求。
在实际实现中我们并不需要把Status与StatusMask按位展开一一比较，只需要把当前DTC的Status跟StatusMask做一下“与”运算，如果结果非0,则表示条件符合。
DTC的Status定义以及各个状态之间的转换机制比较复杂，在ISO14229中也有详细描述，我们稍后再做进一步介绍。

了解了DTC的Status与StatusMask之后我们就可以进一步介绍客户端与服务端的交互过程。我们直接借用ISO14229上的例子:

- 假设离合器位置传感器对地短路故障名称为P0805-11，其DTC为0x080511,它的Status为0x24(0010 0100<sub>b</sub>),下表为DTC P0805-11的StatusOfDTC各个位的状态:

|DTC Status: bit 名称| bit 位置| bit状态 |描述|
| ------| ------ |------| ------ |
| testFailed                        |0|0|DTC未在请求时测试失败          |
| testFailedThisOperationCycle      |1|0|DTC从未在当前操作循环内失败    |
| pendingDTC                        |2|1|DTC在当前或前一个操作循环内失败|
| confirmedDTC                      |3|0|DTC未在请求时确认              |
| testNotCompletedSinceLastClear    |4|0|DTC测试完成,自上一次清除操作   |
| testFailedSinceLastClear          |5|1|DTC测试失败,自从上一次清除操作 |
| testNotCompletedThisOperationCycle|6|0|DTC测试在这个操作循环内完成    |
| warningIndicatorRequested         |7|0|服务端未要求警告指示器激活     |

- 假设混合电池温度传感器电压过高故障名称为P0A9B-17，DTC为0x0A9B17, Status为0x26(0010 0110<sub>b</sub>),下表为DTC P0A9B-17的StatusOfDTC各个位的状态:

|DTC Status: bit 名称| bit 位置| bit状态 |描述|
| ------| ------ |------| ------ |
| testFailed                        |0|0|DTC在请求时无测试失败          |
| testFailedThisOperationCycle      |1|1|DTC在当前操作循环内失败        |
| pendingDTC                        |2|1|DTC在当前或前一个操作循环内失败|
| confirmedDTC                      |3|0|DTC在请求时未确认              |
| testNotCompletedSinceLastClear    |4|0|DTC测试已完成,自上一次清除操作 |
| testFailedSinceLastClear          |5|1|DTC测试失败,自从上一次清除操作 |
| testNotCompletedThisOperationCycle|6|0|DTC测试在这个操作循环内完成    |
| warningIndicatorRequested         |7|0|服务端未要求警告指示器激活     |

- 假设A/C Request “B” - circuit intermittent故障名称为P2522-1F，DTC为0x25221F, Status为0x2F(0010 1111<sub>b</sub>),下表为DTC P2522-1F的StatusOfDTC各个位的状态:

|DTC Status: bit 名称| bit 位置| bit状态 |描述|
| ------| ------ |------| ------ |
| testFailed                        |0|1|DTC在请求时测试失败          |
| testFailedThisOperationCycle      |1|1|DTC在当前操作循环内失败        |
| pendingDTC                        |2|1|DTC在当前或前一个操作循环内失败|
| confirmedDTC                      |3|1|DTC在请求时已确认              |
| testNotCompletedSinceLastClear    |4|0|DTC测试已完成,自上一次清除操作 |
| testFailedSinceLastClear          |5|1|DTC测试失败,自从上一次清除操作 |
| testNotCompletedThisOperationCycle|6|0|DTC测试在这个操作循环内完成    |
| warningIndicatorRequested         |7|0|服务端未要求警告指示器激活     |

在本例中，我们假设DTCStatusMask为0x08,也就是confirmedDTC位必须置1。所以上面三个DTC只有DTC P2522-1F符合要求，
因为只有它的DTC Status跟DTCStatusMask进行”与“运算后结果不为0。
客户端与服务端的报文交互内容如下：

客户端向服务断请求信息内容如下
![]({{site.url}}assets/UDS/DTC/reportNumberOfDTCByStatusMask_request.png)

服务端响应客户端内容如下

![]({{site.url}}assets/UDS/DTC/reportNumberOfDTCByStatusMask_response.png)

这里有几点需要说明:
1. StatusOfDTC有8个状态，具体到某个DTC，这个8个状态并不需要全部支持，ISO14229规定confirmedDTC是强制必须支持的，其他7个则可以根据具体情况自定义支持或者不支持。 
服务断所能支持的DTC Status即为DTCStatusAvailabilityMask，比如服务端支持testFailed, testFailedThisOperationCycle, pending则DTCStatusAvailabilityMask为0x07。
3. 如果客户端请求时包含了服务端不支持的状态掩码，此时服务端只会处理服务端所支持的那些位。
4. DTCFormatIdentifier是DTC格式标识。目前遇到的大部分为0x01,即SO_14229-1_DTCFormat。具体格式定义见下表。

![]({{site.url}}assets/UDS/DTC/DTCFormatIdentifier.png)

除此之外，reportNumberOfDTCBySeverityMaskRecord, reportNumberOfMirrorMemoryDTCByStatusMask, reportNumberOfEmissionsRelatedOBDDTCByStatusMask
与reporNumberOfDTCByStatusMask具有相同的交互格式,我们在最后的小节中对此进行总结。


<h2 id="2.2">2.2    0x02-reportDTCByStatusMask</h2>

reportDTCByStatusMask服务的功能为返回客户端满足StatusMask的DTC列表。与上一节不同的是，reportNumberOfDTCByStatusMask返回DTC的数目，
而reportDTCByStatusMask则返回具体的DTC列表。与reportNumberOfDTCByStatusMask类似，如果客户端请求了StatusMask不支持的状态，则服务端只会处理自己能支持的那些状态。

以下为ISO14229上的例子,我们首先假设服务端支持除了bit7"warningIndicatorRequested"之外的所有的Status bit,也就是说DTCStatusAvailabilityMask为0x7F。
同时为了简单起见我们假设服务端总共支持3个DTC，这个3个DTC的信息如下:

- 假设混合电池温度传感器电压过高故障名称为P0A9B-17，DTC为0x0A9B17, Status为0x24(0010 0100<sub>b</sub>),下表为DTC P0A9B-17的StatusOfDTC各个位的状态:

|DTC Status: bit 名称| bit 位置| bit状态 |描述|
| ------| ------ |------| ------ |
| testFailed                        |0|0|DTC未在请求时测试失败          |
| testFailedThisOperationCycle      |1|0|DTC未在当前操作循环内失败      |
| pendingDTC                        |2|1|DTC在当前或前一个操作循环内失败|
| confirmedDTC                      |3|0|DTC在请求时未确认              |
| testNotCompletedSinceLastClear    |4|0|DTC测试已完成,自上一次清除操作 |
| testFailedSinceLastClear          |5|1|DTC测试失败,自从上一次清除操作 |
| testNotCompletedThisOperationCycle|6|0|DTC测试在这个操作循环内完成    |
| warningIndicatorRequested         |7|0|服务端未要求警告指示器激活     |

- 假设A/C Request “B” - circuit intermittent故障名称为P2522-1F，DTC为0x25221F, Status为0x00(0000 0000<sub>b</sub>),下表为DTC P2522-1F的StatusOfDTC各个位的状态:

|DTC Status: bit 名称| bit 位置| bit状态 |描述|
| ------| ------ |------| ------ |
| testFailed                        |0|0|DTC未在请求时测试失败          |
| testFailedThisOperationCycle      |1|0|DTC未在当前操作循环内失败      |
| pendingDTC                        |2|0|DTC未在当前或前一个操作循环内失败|
| confirmedDTC                      |3|0|DTC未在请求时已确认            |
| testNotCompletedSinceLastClear    |4|0|DTC测试已完成,自上一次清除操作 |
| testFailedSinceLastClear          |5|0|DTC测试未失败,自从上一次清除操作 |
| testNotCompletedThisOperationCycle|6|0|DTC测试在这个操作循环内完成    |
| warningIndicatorRequested         |7|0|服务端未要求警告指示器激活     |


- 假设离合器位置传感器对地短路故障名称为P0805-11，其DTC为0x080511,它的Status为0x2F(0010 1111<sub>b</sub>),下表为DTC P0805-11的StatusOfDTC各个位的状态:

|DTC Status: bit 名称| bit 位置| bit状态 |描述|
| ------| ------ |------| ------ |
| testFailed                        |0|1|DTC在请求时测试失败            |
| testFailedThisOperationCycle      |1|1|DTC在当前操作循环内失败        |
| pendingDTC                        |2|1|DTC在当前或前一个操作循环内失败|
| confirmedDTC                      |3|1|DTC在请求时确认                |
| testNotCompletedSinceLastClear    |4|0|DTC测试已完成,自上一次清除操作 |
| testFailedSinceLastClear          |5|1|DTC测试失败,自从上一次清除操作 |
| testNotCompletedThisOperationCycle|6|0|DTC测试在这个操作循环内完成    |
| warningIndicatorRequested         |7|0|服务端未要求警告指示器激活     |

在这个例子中，只有P0A9B-17 以及 P0805-11这两个返回给客户端。由于P2522-1F的Status为0x00,不满足DTCStatusMask(此例为0x84)的要求，所以不会返回给客户端。
此例中还有一点需要注意，由于服务端不支持bit7的状态(DTCStatusAvailabilityMask=0x7F),因此在处理DTCStatusMask时服务端会自动忽视bit7。客户端与服务端的交互内容如下:

客户端向服务断请求信息内容如下
![]({{site.url}}assets/UDS/DTC/reportDTCByStatusMask_request.png)

服务端响应客户端内容如下

![]({{site.url}}assets/UDS/DTC/reportDTCByStatusMask_response.png)

如果没有任何DTC的实际Status与StatusMask匹配，则服务端将不返回任何DTC，这时客户端向服务端的请求信息与上面一致，服务端响应客户端内容如下:

![]({{site.url}}assets/UDS/DTC/reportDTCByStatusMask_response2.png)

<h2 id="2.3">2.3    0x03-reportDTCSnapshotIdentification</h2>

