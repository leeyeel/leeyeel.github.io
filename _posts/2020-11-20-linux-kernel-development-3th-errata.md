---
layout: post
title:  "《linux 内核设计与实现(原书第3版)》翻译问题" 
date:   2020-11-20 23:06:00
categories: 翻译纠错 
tags: errata
excerpt: 阅读《linux内核设计与实现(原书第三版)》时发现的翻译问题
mathjax: true
---
* TOC
{:toc}

中文版:
linux内核设计与实现(原书第3版)/(美)拉芙(Love,R.)著，陈莉君,康华译.——北京:机械工业出版社,2011.6(2019.9重印)
原文书名: Linux Kernel Development, Third Edition

# 1. unix 系统中的进程调度

中文版P40, 章节4.4.2 Unix系统中的进程调度,在讲解unix系统调度将nice值映射到时间片上的问题时的第一个问题:
```latex
类推，如果是两个具有普通优先级的进程，他们同样会每个获得50\% 处理器时间，但是是在100ms内各获得一半。
```

原文在如下:

```latex
Now, what happens if we run exactly two low priority processes? We’d
expect they each receive 50\% of the processor, which they do. But they each enjoy the
processor for only 5 milliseconds at a time (5 out of 10 milliseconds each)! That is, instead
of context switching twice every 105 milliseconds, we now context switch twice every
10 milliseconds.
Conversely, if we have two normal priority processes, each again receives
the correct 50\% of the processor, but in 100 millisecond increments.
```

前面讲道，如果两个相同的低优先级的进程会发生什么?我们希望他们每个都占用50%的处理器时间，他们的确是这样的。
但是他们每个一次只占用了5ms处理器时间(每10ms中的5ms)。也就是说，不像每105ms切换两次上下文，现在每10ms则切换一次。
这句话直译的话就是:相反，如果我们有两个普通优先级的进程，每个进程再次获取刚好50%的处理器时间，需要100ms的时间增量。
因为前面10ms切换两次上下文，后面占用50%只需要增加5ms，但是如果是两个普通优先级的进程，每个进程想要占用50%的处理器时间则需要增加100ms。

所以这句话本意是想表达，普通优先级的进程时间片是100ms,两个普通优先级的进程，每个占用50%则是100ms,需要100ms才能切换一次上下文。
其实是**在200ms内各获得一半**。
