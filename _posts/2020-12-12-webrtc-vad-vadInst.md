---
layout: post
title:  "webrtc vad 源码解析(一)"
date:   2020-12-23 23:35:00
categories: 音视频
tags: webrtc vad 音频 
excerpt: webrtc vad 源码阅读中对VadInst结构体的说明
mathjax: true
---
* TOC
{:toc}

webrtc关于vad的源代码中的句柄使用了`VadInst`这个结构体，这个结构体有些绕，
涉及到一点点的语法内容，这里做个记录。
源代码位于webrtc的`common_audio/vad/include/webrtc_vad.h`,
即[https://webrtc.googlesource.com/src/common_audio/vad/include/webrtc_vad.h](https://webrtc.googlesource.com/src/common_audio/vad/include/webrtc_vad.h)文件。

### 1. 结构体前置声明

`webrtc_vad.h`文件中有如下语句:

```c
typedef struct WebRtcVadInst VadInst;
```

源代码中并没有`WebRtcVadInst`结构体的定义，此处实际是struct的前置声明语法。
c++中常会对class做前置声明，在确实需要某个类但是又不希望包含声明这个类的头文件时可直接使用`class xxx`的方式做个前置声明，
告诉编译器有个类，需要占个位置。结构体的前置声明不能使用`struct xxx`的方式，需要使用`typedef`关键字，类似上面的方法。

头文件中同时声明了几个vad相关的函数:
```c
// Creates an instance to the VAD structure.
VadInst* WebRtcVad_Create(void);


// Frees the dynamic memory of a specified VAD instance.
//
// - handle [i] : Pointer to VAD instance that should be freed.
void WebRtcVad_Free(VadInst* handle);

// Initializes a VAD instance.
//
// - handle [i/o] : Instance that should be initialized.
//
// returns        : 0 - (OK),
//                 -1 - (null pointer or Default mode could not be set).
int WebRtcVad_Init(VadInst* handle);
```
观察下`WebRtcVad_Create`的实现:
```c
VadInst* WebRtcVad_Create() {
  VadInstT* self = (VadInstT*)malloc(sizeof(VadInstT));

  self->init_flag = 0;

  return (VadInst*)self;
}
```
在分配内存时实际时使用的是`VadInstT`结构体申请成功后把`VadInstT`类型的指针强制转换为`VadInst`类型。

在使用时，比如`WebRtcVad_Init`函数，会再把传入的`VadInst`类型转换为`VadInstT`类型。
所以`VadInst`只是个占位的名称而以，本质上还是使用的`VadInstT`类型。
```c
// TODO(bjornv): Move WebRtcVad_InitCore() code here.
int WebRtcVad_Init(VadInst* handle) {
  // Initialize the core VAD component.
  return WebRtcVad_InitCore((VadInstT*) handle);
}
```

### 2. c库free原理

上面分析了为什么可以使用的`VadInst`指针的原理，实际上只是作为一个名称，内部使用时会再转换为`VadInstT`，
但是有一个例外,即`WebRtcVad_Free`函数:
```c
void WebRtcVad_Free(VadInst* handle) {
  free(handle);
}
```
此函数没有强转传入的handle为`VadInstT`类型，直接free了`VadInst`类型的指针。这涉及到c库的free实现原理。
在使用malloc分配内存时，c库记录了分配好的内存空间的指针及大小，并把这些信息加入链表，当调用free时，
会从链表中查找到这个节点并获取到相关信息，所以free时只需要传入指针即可，c库知道我们要free的内容的类型，大小等信息。
这也是为什么free时不需要强制转换为`VadInstT`类型的原因，因为c库本就知道这些信息。
