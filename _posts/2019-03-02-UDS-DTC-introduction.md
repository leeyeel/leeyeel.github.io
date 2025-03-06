---
layout: post 
title: "UDS诊断之读DTC信息(19 hex)服务(Part I)"
date: 2019-03-02 20:36:20
categories: 学习总结
tags: 汽车 UDS DTC ISO1429 
excerpt: 读DTC信息服务是UDS诊断中比较复杂的一个服务，所以首先介绍它。
mathjax: false
---
* TOC
{:toc}

## 目录
- [读DTC信息(0x19)服务功能介绍](#1)
- [读DTC信息服务的sub-function介绍](#2)
    - [0x00-ISOSAEReserved](#2.0)
    - [0x01-reportNumberOfDTCByStatusMask](#2.1)
    - [0x02-reportDTCByStatusMask](#2.2)
    - [0x03-reportDTCSnapshotIdentification](#2.3)
    - [0x04-reportDTCSnapshotRecordByDTCNumber](#2.4)
    - [0x05-reportDTCStoredDataByRecordNumber](#2.5)
    - [0x06-reportDTCExtDataRecordByDTCNumber](#2.6)
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

读DTC服务的sub-Function太多了，所以分几次介绍。

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

snapshot是指故障发生时的快照，具体内容有整车厂定义，比如时间，温度，车速，等信息。DTCSnapshotRecord可以用来重建故障时的状态。
reportDTCSnapshotIdentification的功能为返回snapshot标识ID，
从名称上就可以知道返回内容并非具体的snapshot，而是可以确定snapshot身份的标识。我们直接通过ISO14229上的例子来讲解这个服务的作用。

对于此例我们做如下假设:

- 对于某个给定的DTC，服务端最多只能存储2个DTCSnapshot。
- DTC(0x123456)存储了2个Snapshot,并且这个DTC已经发生了3次(由于服务端缺少足够空间，这样只有第一个snapshot以及最近的snapshot被保存下来)。
- DTC(0x789ABC)存储了1个Snapshot。
- 所有的DTCSnapshot以升序排列。
- 对于服务端来说DTCSnapshotRecordNumber是唯一的。

客户端向服务断请求信息内容如下
![]({{site.url}}assets/UDS/DTC/reportDTCSnapshotIdentification_request.png)

服务端响应客户端内容如下

![]({{site.url}}assets/UDS/DTC/reportDTCSnapshotIdentification_response.png)

我们对这个结果稍作说明，上图响应中DTCSnapshotRecordNumber从0x01到0x03,说明DTCSnapshotRecordNumber是从1开始计数的，
之所以到0x03就结束是因为我们此例中一共只有三个Snapshot,如果有多个Snapshot这个RecordNumber可能就会一直数到所有Snapshot数完为止。
这里面的DTCSnapshotRecordNumber是一直累加的，是因为我们这里假设了DTCSnapshotRecordNumber是唯一的，
即尽管DTC不是同一个(比如0x123456跟0x789ABC)但是RecordNumber却是全局累加的。


<h2 id="2.4">2.4   0x04-reportDTCSnapshotRecordByDTCNumber</h2>

reportDTCSnapshotRecordByDTCNumber的功能是根据DTC来查找对应的Snapshot。同样以ISO14229上的例子来讲解。先作如下假设:

- 对于某个给定的DTC，服务端最多只能存储2个DTCSnapshot。
- 本例是上节例子的延续，因此上节的假设在本例中都成立。
- 假设请求的是DTC(0x123456)存储的2个Snapshot中的第2个。
- 假设DTC(0x123456)的StatusOfDTC为0x24,并且接下来的环境数据每次DTC发生时都被捕获。
- DTCSnapshot记录数据的DID为0x4711。
- DTCSnapshot记录的内容如下图:

![]({{site.url}}assets/UDS/DTC/DTCSnapshot_record_content.png)

本例中服务端返回了1个DTCSnapshot记录。
客户端向服务断请求信息内容如下
![]({{site.url}}assets/UDS/DTC/reportDTCSnapshotRecordByDTCNumber_request.png)

服务端响应客户端内容如下

![]({{site.url}}assets/UDS/DTC/reportDTCSnapshotRecordByDTCNumber_response.png)

这里有几点需要说明:
- 本例中同样假设DTCSnapshotRecordNumber对服务端来说是唯一的(这里唯一的意思是说对于任何DTC，只要有Snapshotrecord,则DTCSnapshotRecordNumber就会累加一个）。
实际情况中可能有不同的定义方式，比如可以对每一个DTC都有一个DTCSnapshotRecordNumber序列，或者对某几个DTC有一个DTCSnapshotRecordNumber的序列。
- 上图响应信息中，byte 7 (DTCSnapshotRecordNumber)为DTCSnapshot的序号, 当DTCSnapshotRecordNumber为全局唯一时，
reportDTCSnapshotRecordByDTCNumber以及下一节要介绍的reportDTCStoredDataByRecordNumber都可用，但是当DTCSnapshotRecordNumber不是全局唯一时，
下一节要介绍的reportDTCStoredDataByRecordNumber功能就不可用，因为这时候给定一个DTCSnapshotRecordNumber不能唯一的确定是哪一个DTC的DTCSnapshotRecord。
- 响应信息中，byte 8 (DTCSnapshotRecordNumberOfIdentifiers)为 dataIdentifier的序号，此例中只有一个dataIdentifier (0x4711),
所以DTCSnapshotRecordNumberOfIdentifiers的值为0x01,若有多个dataIdentifier,其值会继续增加下去。
- dataIdentifier是数据ID，dataIdentifer 与 Snapshot record的内容相关联:一个dataIdentifier对应一组Snapshot record content。
当一个dataIdentifier 只涉及到所有数据中的一部分数据，而又需要所有数据时，就需要多个dataIdentifier。
- ISO14229中并没有对dataidentifier的长度(本例中2个字节)以及DTCSnapshotRecord内容的长度(本例中5个字节)做强制规定。

<h2 id="2.5">2.5  0x05-reportDTCStoredDataByRecordNumber</h2>

reportDTCStoredDataByRecordNumber在ISO14229(2006)中的名称为DTCSnapshotRecordByRecordNumber,两者除了名字不同外没有其他不同, 
它的功能是根据RecordNumber来查找对应的Snapshot(上一小节中则是通过DTCNumber来查找)。由于reportDTCStoredDataByRecordNumber
只是与上一节reportDTCSnapshotRecordByDTCNumber请求Snapshot的方式不同，所以我们仍然使用上一节的假设与例子。
reportDTCStoredDataByRecordNumber报文交互内容如下:

客户端向服务断请求信息内容如下
![]({{site.url}}assets/UDS/DTC/reportDTCStoredDataByRecordNumber_request.png)

服务端响应客户端内容如下

![]({{site.url}}assets/UDS/DTC/reportDTCStoredDataByRecordNumber_response1.png)
![]({{site.url}}assets/UDS/DTC/reportDTCStoredDataByRecordNumber_response2.png)

这里有一点需要说明:
- 本例中假设DTCSnapshotRecordNumber对服务端来说是唯一的，如果DTCSnapshotRecordNumber不唯一，那么reportDTCStoredDataByRecordNumber将无法实现。
因为这时候给定一个DTCSnapshotRecordNumber不能唯一的确定是哪一个DTC的DTCSnapshotRecord。

<h2 id="2.6">2.6  0x06-reportDTCExtDataRecordByDTCNumber</h2>

reportDTCExtDataRecordByDTCNumber在ISO14229(2013)版本中的名称为reportDTCExtendedDataRecordByDTCNumber,它的功能是根据客户端请求的DTC，返回一个DTCExtendedDataRecord。
其功能与reportDTCSnapshotRecordByDTCNumber类似，
区别只是reportDTCSnapshotRecordByDTCNumber返回的是DTCSnapshotRecord 而reportDTCExtDataRecordByDTCNumber返回的是DTCExtendedDataRecord。
与reportDTCSnapshotRecordByDTCNumber一样，客户端请求是发送的DTCNumber叫做DTCMaskRecord,实际并没有"Mask"的功能，服务端会查找与DTCMaskRecord完全匹配的DTC。

通常情况下(客户端请求时的DTCExtDataRecordNumber不等于0xFE或0xFF，注意这点ISO14229(2013)与ISO14229(2006)不同，ISO14229(2006)只有不等于0xFF这一个例外),
服务端只会返回客户端1条预定义的DTCExtendedData 记录,否则服务端会返回存储的所有DTCExtendedData records。
DTCExtDataRecord(ISO14229(2006)此处名称为DTCExtendedDataRecord)的格式与内容由整车厂定义，
DTCExtDataRecord中的数据结构由DTCExtDataRecordNumber定义，定义方式与reportDTCSnapshotRecordByDTCNumber中的dataIdentifier相似。

如果客户端请求的DTCMaskRecord 或者 DTCExtDataRecordNumber不可用或者服务端不支持，服务端会否定响应。关于否定响应ISO14229(2006)与ISO14229(2013)也有不同，
ISO14229(2013)中规定，如果客户端请求DTCExtDataRecordNumber为0xFE,但是服务端不支持OBD相关的扩展数据(0x90-0xEF)时同样会产生否定响应。

使用ISO14229中的例子,做如下假设:
- 对于某个给定的DTC，服务端最多只能存储2个DTCExtendedData。
- 假设客户端请求DTC(0x123456)所有可用的DTCExtendedData。
- 假设DTC(0x123456)的statusOfDTC 为0x24,且随后的扩展数据是可用的。
- DTCExtendedData通过DTCExtDataRecordNumbers 0x05 和0x10引用,这两个DTCExtDataRecordNumbers的内容见下图.

![]({{site.url}}assets/UDS/DTC/DTCExtDataRecordNumber.png)

本例中，客户端请求信息中DTCExtDataRecordNumber的值为0xFF,表示请求所有符合条件的记录，服务端将返回所有可用的(本例子中2个)DTCExtendedData。

客户端向服务断请求信息内容如下
![]({{site.url}}assets/UDS/DTC/reportDTCExtDataRecordByDTCNumber_request.png)

服务端响应客户端内容如下
![]({{site.url}}assets/UDS/DTC/reportDTCExtDataRecordByDTCNumber_response.png)

这里有一点需要说明:
- 与reportDTCSnapshotRecordByDTCNumber中的DTCSnapshotRecord类似，ISO14229中也未对reportDTCExtDataRecordByDTCNumber中的DTCExtDataRecord长度做强制规定，
虽然本例中的长度为1个字节，但是具体长度整车厂可以自行定义,更加灵活的是，不同的DTCExtDataRecord的长度也不必完全一致(本例中都为1个字节)。


<h2 id="2.7">2.7  0x07-reportNumberOfDTCByServerityMaskRecord</h2>

reportNumberOfDTCByServerityMaskRecord的功能为返回与严重等级相匹配的DTC数目，它的形式与reportNumberOfDTCByStatusMask类似，
不同的是这里是通过ServerityMaskRecord。DTCSeverityMask包含3个表示严重程度的bit,具体定义在ISO14229中有详细的定义，我们这里不做过多介绍。
DTCSeverityMask的使用方法也与StatusMask类似，只不过除了要满足DTCStatusMask的要求外还要满足DTCSeverityMask的要求，也就是说满足reportNumberOfDTCByServerityMaskRecord
的DTC需要符合下面的条件:
```
(((statusOfDTC & DTCStatusMask) != 0) && ((severity & DTCServerityMask) != 0)) == TRUE
```
每当有一个DTC满足条件，则计数加一。与 DTCStatusMask类似，如果客户端指定了服务端不支持的DTCServerityMask位，则服务端只处理它能支持的DTCServertiy。
当所有DTC都检查一遍后，服务端会返回DTCStatusAvailabilityMask并且返回2个字节的计数到客户端。
以ISO14229中的例子来说明:

- 假设混合电池温度传感器电压过高故障名称为P0A9B-17，DTC为0x0A9B17, Status为0x24(0010 0100<sub>b</sub>), DTCFunctionalUnit = 0x10, DTCSeverity = 0x20。
下表为DTC P0A9B-17 StatusOfDTC 各bit的状态:

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

- 假设A/C Request “B” - circuit intermittent故障名称为P2522-1F，DTC为0x25221F, Status为0x00(0000 0000<sub>b</sub>), DTCFunctionalUnit = 0x10, DTCSeverity = 0x20
下表为DTC P2522-1F的StatusOfDTC各个bit的状态:

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

- 假设离合器位置传感器对地短路故障名称为P0805-11，其DTC为0x080511,它的Status为0x2F(0010 1111<sub>b</sub>), DTCFunctionalUnit = 0x10, DTCSeverity = 0x40。
下表为DTC P0805-11的StatusOfDTC各个位的状态:

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

在本例中，DTCSeverityMaskRecord(DTCSeverityMask)为0xC0, DTCSeverityMaskRecord(DTCStatusMask)为0x01,因此只有DTC P0805-11 (0x080511)符合要求。

客户端向服务断请求信息内容如下:
![]({{site.url}}assets/UDS/DTC/reportNumberOfDTCBySeverityMaskRecord_request.png)

服务端响应客户端内容如下
![]({{site.url}}assets/UDS/DTC/reportNumberOfDTCBySeverityMaskRecord_response.png)


