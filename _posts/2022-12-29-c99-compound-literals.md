---
layout: post
title:  "c99 Compound Literals语法介绍"
date:   2022-12-29 19:38:00
categories: 总结
tags: ffmpeg
excerpt: c99 Compound Literals 介绍
mathjax: true
---

### 一个实例

c99复合文字语法，书上有介绍，但是实际见到的少，今天在阅读ffmpeg源码中看到如下：

```c
void av_freep(void *arg)
{
    void *val;

    memcpy(&val, arg, sizeof(val));
    memcpy(arg, &(void *){ NULL }, sizeof(val));
    av_free(val);
}
```

注意其中第6行中的`(void*){NULL}`,实际就是个compound literals,可以参考[C99 standard ISO/IEC 9899:1999](https://www.iso.org/standard/29237.html)(这里有一份[可下载文档](https://www.dii.uchile.cl/~daespino/files/Iso_C_1999_definition.pdf)),或参考[gcc对ompound literals的介绍](https://gcc.gnu.org/onlinedocs/gcc/Compound-Literals.html).
compound literals有点类似匿名类型，可用于结构体或数组，我们用gcc档里的例子,假设我们声明一个结构体structure：

```c
struct foo {int a; char b[2];} structure;
```

使用compound literals方式可以用:

```c
structure = ((struct foo) {x + y, 'a', 0});
```

上面的方式与下面方式等价:

```c
{
  struct foo temp = {x + y, 'a', 0};
  structure = temp;
}
```

### 使用及注意可总结如下

1. 可以构造一个数组，此时compound literal会被强制转换为指向数组第一个元素的指针，构造数组时需要注意数组不能是可变长度的，如果没有指定长度，编译器会自动推算出长度

```c
char **foo = (char *[]) { "x", "y", "z" };
```

为方便理解，示例代码如下:

```c
#include <stdio.h>

int main(){
    char **foo = (char *[]) { "x", "y", "z" };
    printf("foo :%s, %s, %s\n", foo[0], foo[1], foo[2]);
    return 0;
}

//结果: foo :x, y, z
```

2. 如果在函数体外定义，则这个compound literals必须是常量表达式，举例如下:

```c
#include <stdio.h>

int a = 10;
int *p1 = (int []){2, a}; //编译错误，必须是常量表达式
int *p2 = (int []){2, 10};//编译通过

int main(){
    return 0;
}
```

3. 需特要别注意的是, compound literals是个左值，比如下面的语句就是允许的(左值也意味着它是可以取地址的)：

```c
int i = ++(int) { 1 };
```
示例代码:

```c
#include <stdio.h>

int main(){
    int i = ++(int) { 1 };
    printf("i :%d\n", i);
    return 0;
}
//结果: i :2
```
4. 如果compound literals出现在函数体外，则它具有静态存储周期，
否则就是与代码块相关的自动存储周期。这点除了静态存储周期外，与我们普通变量声明一致。

5. gcc有很多拓展语法，导致即使在c90中或者c++中也能使用compound literals，
但是拓展语法与c99的有区别，使用时需要特别注意。

### av_freep的问题

再回到av_freep函数，memcpy(arg, &(void *){ NULL }, sizeof(val));这条语句实际上是先定义了一个值为NULL，类型为void *的匿名变量，然后取这个匿名变量的地址，并拷贝一个指针的长度，刚好就是匿名变量的值NULL，最终实现的效果就是arg指向的内容变为NULL;
