---
layout: post
title:  "python使用protobuf接收websockets数据"
date:   2021-05-05 18:11:00
categories: 笔记心得
tags: python protobuf websocket javascript
excerpt: python使用protobuf接收websocket数据
mathjax: true
---
* TOC
{:toc}

### protobuf介绍

protobuf是google开发并开源的与具体语言，平台无关的序列化数据机制。

protobuf官网见:[https://developers.google.com/protocol-buffers](https://developers.google.com/protocol-buffers)

### 使用场景介绍

服务端通过websocket发送数据，客户端使用python获取数据，数据交互使用protobuf。
python需要安装google.protobuf库，websocket使用了websocket-client库，安装方法:`pip install websocket-client`。
