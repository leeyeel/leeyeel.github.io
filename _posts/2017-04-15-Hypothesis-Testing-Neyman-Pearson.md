---
layout: post
title:  "假设检验(1)——奈曼-皮尔逊(Neyman-Pearson)检验" 
date:   2017-04-15 23:54:54
categories: 统计
tags: 统计 假设检验
excerpt: 打算做一个统计学系列的博客，主要记录自己的学习过程。
mathjax: true
---

### 你需要一本好教材

参数估计解决的问题是当我们测量到这些样本的时候，总体的参数是多少，而假设检验解决的问题是，这些估计得到的参数或者分布有多大概率是正确的。
假设检验的应用非常广泛，实验物理数据分析中常常会用到,其他比如医学，生物，社会学等也很常用。
本次内容主要介绍几种常用的\(当然是我感觉常用的\)假设检验方法，对每种方法的历史做一些介绍，并给出一些定理的证明，同时尽可能的用一些例题来加深一下理解。

### 假设检验的基本原理

根据待检验的类型，假设检验可以分为 **参数检验** 跟 **非参数检验**。参数检验很好理解，比如说我们已经知道一个年级的学生身高分布是正态分布，我们通过测量一个班的学生的身高，
来检验整个年级学生身高的均值是不是为某个值(比如160cm),这样对某个参数进行的假设检验就是参数检验。而非参数检验需要解决的问题，则是通过对一个班级学生的身高测量，
来确定整个年级的身高分布是不是真的服从高斯分布。

我们先来讲解参数检验，用一般化的语言来描述上面测量身高的例子就是：假设总体$X$的概率分布为$F(x;\theta)$，函数形式已知，但其中的参数$\theta$未知，
我们从一组子样测量值$(x_{1},x_{2},...,x_{n})$来检验未知参数$\theta$是否等于某个指定的值$\theta_{0}$。这样的假设检验便是参数检验。
对于参数检验我们需要一个原假设(Null Hypothesis）: 
        <center> $$H_{0}:\theta = \theta_{0}$$ </center> 
同时我们还可以有其他假设，与原假设相对，其他假设称为备则假设(Alternative Hypothesis),比如我们可以假设：
        <center> $$H_{1}:\theta = \theta_{1}$$ </center>
像这样的假设都称为**简单假设**，原因就是不管我们在原假设还是备则假设，我们所做的假设都只是一个具体的值，$\theta_{0}$或者$\theta_{1}$,实际上在做备则假设时还可以有其他类型，
比如我们可以取:
        <center> $$H_{1}:\theta \geq \theta_{1}$$ </center>
这时候备则假设并不是一个数值，而是一个集合，这样的假设称为**复杂假设**。之所以要区分简单假设跟复杂假设，是因为我们后面介绍的假设检验方法跟假设的类型有关。

**假设检验的精髓是构造合适的统计量。**