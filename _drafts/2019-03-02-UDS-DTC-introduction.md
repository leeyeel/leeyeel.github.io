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
- [读DTC服务功能介绍](#1)
- [sub-function介绍](#2)
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

<h2 id="1">1. 读DTC服务功能简介</h2>

