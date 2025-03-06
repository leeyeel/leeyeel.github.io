---
layout: post
title:  "掘地三尺分析ffmpeg中av_freep函数及C标准的strict aliasing rule介绍"
date:   2023-06-21 17:44:00
categories: 音视频 
tags: ffmpeg C/C++
excerpt: ffmpeg 中的av_freep函数深度解析，以及C语言的strict aliasing rule介绍
mathjax: true
---

罪魁祸首是因为这篇[ffmpeg历史垃圾桶中的AVFifoBuffer源码分析](https://blog.whatsroot.xyz/2023/01/02/ffmpeg-n44-avfifobuffer/)，以n4.4.3为例，ffmpeg源码中libavutil/mem.c文件这个函数:

```c

void av_freep(void *arg)
{
    void *val;

    memcpy(&val, arg, sizeof(val));
    memcpy(arg, &(void *){ NULL }, sizeof(val));
    av_free(val);
}
//其中av_free函数可直接认为是C库中的free()函数
```

他的作用是释放内存空间，并把指针置空来防止悬空指针。举个栗子:

```c
int main(){
  int *p = (int*)malloc(6);
  av_freep(&p);
  printf("p is: %p\n", p);
  return 0;
}
```

此处第4行中输出(gcc version 11.3.0):

![]({{site.url}}assets/ffmpeg/avfreep-1.png)

此处av_freep不仅释放了malloc的内存，还把p置空。

现在来研究下这个过程是如何实现的，结合我们main函数的例子，传入av_freep函数的参数是&p, 
其中p是个指针，它指向这块6个字节大小的内存，&p就是个二级指针，
类型是个int **,然后被强制转换为void*传递给av_freep。
在av_freep函数定义的第2行，会在栈空间开辟一块内存空间用于存放val，这个空间就叫他m1，里面存放的就是val，然后到第5行:

```c
memcpy(&val, arg, sizeof(val));
```

已知val是个指针，&val就是取val的地址也就是m1的地址。后面拷贝了一个指针长度的内容放到m1, m1本来存放的就是指针。所以这行实际就是对val进行了赋值操作。

那赋的什么值呢？再来看arg这个参数，它是个指针，所以arg的值就是arg指向的内容的地址，arg指向p，所以arg的值就是p的地址。p是个指针，它的地址处一个指针长度的内容就是刚好是p本身。所以memcpy(&val, arg, sizeof(val))实际就是把p赋值给val。由于这里传入的是p的地址，用arg参数表示就是:

```c
val = *arg; //由于arg指向p,相当于val = p;
```

第6行中间的部分是个复合字面量语法，可参考之前的笔记[c99 复合字面量](https://blog.whatsroot.xyz/2022/12/29/c99-compound-literals/)

```c
memcpy(arg, &(void *){ NULL }, sizeof(val));
```
这次是从一个void*类型的值为NULL的变量地址处拷贝一个指针长度——即NULL本身——到arg指向的地方，也就是main函数中的p。相当于:

```c
*arg = NULL;//由于arg指向p,相当于p = NULL;
```

这样就把p悬空指针的问题解决了。

av_free(val)这行，由于val与p相等，相当于执行了一条free(p)命令。所以这段代码相当于用free释放内存，然后把指针置成NULL（当然这里是先把指针做了拷贝备份，把传入的指针置空后释放内存)

*搞清楚了这段代码的作用，本文的主题才刚刚开始：*

## av_freep的参数既然是个二级指针，为什么不直接使用二级指针做参数，像下面这样?

```c
void av_freep(void **arg)
```

这是因为C语言标准中对void*是有特殊待遇的，在c99(ISO/IEC 9899:1999 (E) 6.3.2.3 Pointers)章节中的描述：

```
A pointer to void may be converted to or from a pointer to any incomplete or object type. A pointer to any incomplete or object type may be converted to a pointer to void and back again; the result shall compare equal to the original pointer.
```

指向任何类型的指针都可以转换为void*,反之亦然，但是void**是没有特殊待遇的，所以如果这里使用void**,可能会产生指针类型不兼容的问题。

## 为什么不直接使用我们分析代码时的方式？比如下面这样?

```c

void av_freep(void *arg)
{
    void **ptr = (void **)arg;
    av_free(*ptr);
    *ptr = NULL;
}
```

通过追溯github上blame信息，发现n2.6版本之前就是这么写的，直到2015年Rémi Denis-Courmont提交了现在的版本。

![]({{site.url}}assets/ffmpeg/avfreep-2.png)

(顺便提一下这个Remi也是个法国人，同时也是VLC media player的首席架构师:[主页](https://www.remlab.net/)，
 以及[介绍vlc框架]的视频(https://www.youtube.com/watch?v=Zqw7mJdwO4I) )

Remi的提交commit:

```
mem: fix pointer pointer aliasing violations.

This uses explicit memory copying to read and write pointer to pointers of arbitrary object types. This works provided that the architecture uses the same representation for all pointer types (the previous code made that assumption already anyway).
```

简单翻译一下：修复了二级指针的'混叠'冲突。使用显式的memcpy去读写指向任意类型的二级指针。只要平台对所有指针类型都有相同的表示，这个修改就可以正常工作（当然之前的代码已经做了这个假设）。

我给Remi发邮件问这个地方，为什么memcpy就可以解决这里的aliasing violation, Remi回复说最好查看下C标准，他暂时记不清楚了，Aliasing rules对memcpy是不同的规则，而且这里也仅仅是个很partial(局部?)的修复。

```
Hi, Aliasing rules are not the same for memcpy(). It's better to refer to the specifications, which I do not have on top of my head. But anyhow this patch was only a very partial fix.

Remi
```

再顺着关键词搜索strict aliasing 相关的内容，放到结尾参考文献里：

(阅读文档时注意，由于编译器版本不一样，实际可能并不能看到跟作者一致的输出结果）

- strict aliasing介绍

strict aliasing rule是c/c++编译器所做的一个假设，它假设不会有两个或多个不同类型的指针指向同一块内存地址，这也是这里aliasing（别名?）这个单词出现的原因。再白话一点讲就是，编译器会假设用户不会有不同类型的指针指向同一块内存地址，比如明明是一个int型指针，用户偏偏用float型指针解引用去访问这块内存。之所以要做这个假设，是因为假设成立的话编译器可以对代码做更多的优化。

参考文献[C90与C99标准关于strict aliasing 的规定对比]中提到的C标准中，有关于strict aliasing 所谓的“类型”更精确的介绍。

![]({{site.url}}assets/ffmpeg/avfreep-3.png)

正如作者所说，C90与C99关于strict aliasing rule的相关内容基本一致，之所以是后来才引起讨论大概是因为先前的编译器没有去关注或实现这个规则。

以C99的标准，翻译下这里所说的访问某个对象存储的值所允许使用的类型:

1. 与对象的有效类型兼容的类型

2. 与对象的有效类型兼容的带有类型限定符的类型

3. 与对象的有效类型兼容的带有signed或者unsigned等修饰符的类型

4. 与对象的有效类型兼容的带有修饰符或者类型限定符的类型

5. 在成员(也包括递归的包含子聚合或联合类型)中包含了上述提到的类型之一的聚合或者联合类型。或

6. char类型

看完翻译大概率仍然一头雾水，这里举例说明：

第1条与对象有效类型兼容的类型比如常见的int, int32_t;第2条带有类型限定符的类型比如int与const int;第3条带有修饰符的类型比如signed,unsinged; 第4条既有类型限定符又有修饰符的，int 与const unsigned int这种。上面这几条比较好理解，举个栗子：

```c
#include <stdio.h>

void print_float(const volatile int* ptr) {
    float* float_ptr = (float*)ptr;
    printf("%f\n", *float_ptr);
}

int main() {
    int num = 42;
    print_float((const volatile int*)&num);
    return 0;
}
```

在这个例子中，我们有一个 int 类型的变量 num。然后，我们通过将其地址转换为 const volatile int* 类型的指针，并将其传递给 print_float 函数。在 print_float 函数内部，我们将 const volatile int* 类型的指针 ptr 强制转换为 float* 类型的指针 float_ptr。这个转换不在我们上面规定的四条中，实际上违反了strict aliasing规则，因为我们将 int 类型的 num 通过 float* 类型的指针进行了访问。
除此之外，这里还使用了 "a qualified version of a type compatible with the effective type of the object" 的情况。具体来说，我们将 int* 类型的指针转换为 const volatile int* 类型的指针，并将其传递给函数。这里的 const volatile int* 类型是 int* 类型的类型限定+修饰符修饰版本。尽管类型被限定了const 和 volatile，但是这个限定版本仍然与 int* 类型兼容。在 print_float 函数内部，将 const volatile int* 类型的指针 ptr 转换为 float* 类型的指针 float_ptr 符合 "a qualified version of a type compatible with the effective type of the object" 的要求，这一步并不违反strict aliasing规则。
第5条有点复杂，里面提到的聚合（aggregate）类型，是指类似数组，结构体这种聚合了多个对象的类型。这条是说如果一个聚合类型（结构体或数组）或联合类型的成员中包含了前述提到的类型之一（或者是包含了一个子聚合类型或包含联合类型的成员），那么这个聚合类型或联合类型就可以被用作访问对象的类型。也就是说如果一个结构体或数组的成员中包含了某个类型，那么可以使用该结构体或数组类型来访问这个成员，而不会违反严格别名规则。

举个栗子:

```c
struct Point {
    int x;
    int y;
};

union Data {
    int i;
    float f;
};

void foo(struct Point* point) {
    point->x = 10;
    point->y = 20;
}

int main() {
    struct Point p;
    foo(&p);
    return 0;
}
```

在这个例子中，struct Point 是一个聚合类型，它的成员包括了两个 int 类型的变量 x 和 y。在 foo 函数中，参数 point 的类型是 struct Point*，它是一个指向 struct Point 类型的指针。因此，在函数内部可以通过这个指针访问 x 和 y 成员，而不会违反strict aliasing规则。

第6条，这里为什么char是特殊的？并没有找到公开的资料解释。我猜是因为计算机数据最小按照字节来对齐，而char就是最小的字节单位，char无论如何也不会产生对齐问题。至于void*类型的指针也可以任意转换，可能就完全是为了方便人为规定的。比如:

```c
#include <stdio.h>

void print_char(const char* str) {
    printf("%s\n", str);
}

int main() {
    int num = 42;
    print_char((const char*)&num);
    return 0;
}
```
把'int'类型的指针强制转换为'char'类型的指针，并不违反strict aliasing规则。


到目前为止，似乎一切顺利，甚至习以为常，索然无味，不知所云。这是因为我们的C语言课程就是这么介绍的，而C语言课程的依据最终也来源于C语言标准。大多数情况下，我们开始写C代码的时候都是老老实实规规矩矩，但是当看过了各种开源项目对C语言的骚操作之后，自己也会逐渐放飞自我，这时候如果没有搞清楚标准，就会埋下危机。

看下面这个例子test.c：

```c

#include <stdio.h>

int foo( float *f, int *i ) {
    *i = 1;
    *f = 0.0;

   return *i;
}
int main() {
    int x = 0;
    printf("%d\n", x);

    x = foo((float*)&x, &x);
    printf("%d\n", x);
    return 0;
}
//下文有执行结果

```

在这个代码里，foo的两个参数一个是float类型的指针，一个是int型指针，这两个不同类型的指针都可访问x,此时就违反了strict aliasing rule。这里用这个例子解释为什么要做strict aliasing rule这个规定。如上面那6条，C语言标准规定了可以合法访问的情况，除此之外的访问方法就是未定义（undefined)或者(编译器)实现定义(implementation-defined)行为。

由于没有规定不同类型的指针指向同一块内存后该如何处理，这就给编译器优化代码带来了困难。比如上面这个代码，如果我们知道用户的代码绝不会违反strict aliasing规则，则foo函数可以优化为直接return 1;即可,但是如果我们不知道用户有没有违反这个规则，那就必须要老老实实一步一步翻译用户的代码。

gcc默认编译选项是没有开启 -fstrict-aliasing 的，当开启-O2编译优化时，会默认打开 -fstrict-aliasing选项，此时如何用户违反 strict-aliasing，则就会引发问题。上面的例子中：

```bash
➜  gcc test.c -o main
➜  ./main 
0
0

//开启O2优化
➜ gcc test.c -O2 -o main
➜ ./main 
0
1
```

到此为止应该了解了什么是strict aliasing rule以及为什么需要strict aliasing rule。下面我们再回过头来看，旧版本ffmpeg中的av_freep函数，到底哪里违背了strict aliasing rule。如下面的例子:

```c
void av_freep(void *arg)
{
    void **ptr = (void **)arg;
    free(*ptr);
    *ptr = NULL;
}

int main(){
  int *p = （int*）malloc(32);
  av_freep(&p);
  return 0;
}
```

在这段代码中，传递给av_freep的参数是个int**的指针，而在第3行代码中，这个指针被转换为了void**，这种情况并不在我们之前介绍的6种类型中，所以违反strict aliasing rule。

## 总结

由于gcc的版本更新，参考文献中提到的违反strict aliasing rule的示例，除本文中的例子外，即便手动开启了strict aliasing的选项，其他大部分都无法在当前的gcc版本中复现。

在查阅资料的过程中，也发现C标准并不是生来完美，它有bug，也会出补丁。甚至说标准与实现之间还有很多不同：标准是一回事，编译器的实现是另一回事，编译器实现并非完全按照标准实现。比如我们常用的通用指针void*,在C90以及C99中都未看到明确的可当作generic pointer的说明，直到 2018 C 标准才有一段关于void作为generic pointer的说明。更别说gcc自带的各种C扩展，更也不在C标准之内。这种不统一当然会给开发者特别是跨平台开发者带来麻烦。

作为普通开发者而言，至少对我本身讲，当然没有必要为标准的问题去争论。正如[C90与C99标准关于strict aliasing 的规定对比]这篇博文的作者所说，(争论这些)往往唯一的胜利策略是不参与。但是我们依然有必要去了解语言标准，因为只有了解它，熟悉它，才能规避错误，写出更优质的代码。

## 参考文献

- [1] [解释了什么是strict aliasing](https://stackoverflow.com/questions/98650/what-is-the-strict-aliasing-rule)
- [2] [举例什么是strict aliasing,并配有汇编代码](https://cellperformance.beyond3d.com/articles/2006/06/understanding-strict-aliasing.html)
- [3] [举例如何避免违规则](https://stackoverflow.com/questions/98340/what-are-the-common-undefined-unspecified-behavior-for-c-that-you-run-into)
- [4] [c++,附带网站可以选择编译器版本](https://gist.github.com/shafik/848ae25ee209f698763cffee272a58f8)
- [5] [C90与C99标准关于strict aliasing 的规定对比](http://kristerw.blogspot.com/2017/07/strict-aliasing-in-c90-vs-c99-and-how.html)



