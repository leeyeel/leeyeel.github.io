---
layout: post
title: "C#中的委托delegate与C/C++中的函数指针"
date: 2017-12-24 00:43
categories: 笔记心得
tags: C# 委托　函数指针
excerpt: 通过对比C#中委托与C/C++中函数指针，来更好的理解委托
mathjax: false
---

### 写在前面

这篇笔记比较适合于跟我学习路线相似的小伙伴，也就是说熟悉C/C++，但是第一次接触C#的小伙伴．当我使用C#的委托时,我对C#的委托是感到很困惑的，
尽管我看了网上很多的教程以及模仿了他们写了自己的代码也顺利通过了，但是依然感到困惑．直到我有时间可以好好看一本C#的教材时才终于把委托搞清楚．
所以记录一下，希望帮助那些跟我有类似困惑的小伙伴少走一些弯路.

### OUTLINE
这篇笔记我将会下面几个方面来帮助大家理解委托:    

- [1. C#中的委托其实就是封装好的C/C++中的函数指针](#1)
- [2. 委托是种类型，而不是方法](#2)
- [3. 委托基本语法](#3)
    - [3.1 声明委托类型](#3.1)
    - [3.2 创建委托对象](#3.2)
    - [3.3 委托的其他一些操作](#3.3)
- [4. 匿名方法与Lambda表达式](#4)
    - [4.1 匿名方法](#4.1)
    - [4.2 Lambda表达式](#4.2)
- [5. C#为什么要使用委托](#5)

<h2 id="1">1.C#中的委托类似于C/C++中的函数指针</h2>

这里我先来举个栗子，原栗子是*C#图解教程(第4版)*中介绍委托时用的栗子，这里我把它改造一下，用C/C++中的函数指针来实现，
先看下面的代码:  

```
#include <iostream>
#include <ctime>
#include <cstdlib>

void printLow(int value){
    std::cout<<value<<" - Low Value\n";
}

void printHigh(int value){
    std::cout<<value<<" - High Value\n";
}

int main(){
    //设置随机数种子
    srand((unsigned)time(NULL)); 
    //生成一个0-99的随机数
    int randValue = rand() % 100;
    //声明一个函数指针
    void (*MyDel)(int value) = NULL;
    //根据随机数的值给函数指针赋值
    MyDel = randValue < 50 ? printLow : printHigh;
    //这个地方也可以用(*MyDel)(randValue)的形式，两种方式在C++编译器看来都合法且效果相同
    //这里我们采用下面这种方式因为它更形象.
    MyDel(randValue);
    return 0;
}

```
上面这段C++代码，MyDel是一个函数指针,但是C#中没有指针(虽然声明为不安全代码，也是可以使用指针的)，如果要实现同样的功能，在C#该如何做呢？看下面的代码:  

```
using System;

namespace delegateExample
{
	delegate void MyDel(int value); //声明委托类型

	class MainClass
	{
		void PrintLow(int value){
			Console.WriteLine ("{0} - Low value", value);
		}
		void PrintHigh(int value){
			Console.WriteLine ("{0} - High Value", value);
		}
		public static void Main (string[] args)
		{
			MainClass mainclass = new MainClass ();
			MyDel del;	//声明委托变量
			//创建随机数生成器对象，并得到０到９９之间的一个随机数
			Random rand	= new Random();
			int randomValue = rand.Next (99);
			//创建一个包含PrintLow或者PrintHigh的委托对象并将其赋值给del变量
			del = randomValue < 50 
					? new MyDel (mainclass.PrintLow) 
					: new MyDel (mainclass.PrintHigh);
			del(randomValue);
		}
	}
}

```
C++ 代码跟C#对比一下，很容易就能发现，C#中的委托　`delegate void MyDel(int value);`，其实就是C++中的函数指针`void (*MyDel)(int value) = NULL;`,
如果你到这里感觉还是不是很明显，我们还可以进一步改造C++的代码:

```
#include <iostream>
#include <ctime>
#include <cstdlib>

void printLow(int value){
    std::cout<<value<<" - Low Value\n";
}

void printHigh(int value){
    std::cout<<value<<" - High Value\n";
}
//定义一个指向接受一个int参数且无返回值的函数的指针类型
typedef void (*MyDel)(int);
int main(){
    srand((unsigned)time(NULL)); 
    int randValue = rand() % 100;
//声明一个函数指针
    MyDel del;
    del = randValue > 50 ? MyDel(printHigh) : MyDel(printLow);
    del(randValue);
    return 0;
}

```
到这里已经很明显了,C#中委托的声明`delegate void MyDel(int value);`,类似于C++中定义一个函数指针类型`typedef void (*MyDel)(int);`.
好了，知道这一点以后，我们再来讲解一下另一个让很多C/C++程序员第一次见到delegate时非常疑惑的原因:

<h2 id="2"> 2. 委托是种类型，而不是方法</h2>

其实从C++中的typedef中是可以发现的，C#中的delegate声明其实对应到C++中的话就是typedef,也就是说delegate是种专一的类型声明.
初次接触C#中delegate的C++程序员很容易被它的外表欺骗认为它是个函数，因为它长的实在是太像函数了．　　　　
最后让我们再重复一下这句话: 
**委托是种类型,而不是方法**

<h2 id="3"> 3. 委托基本语法 </h2>

(主要搬运自*C#图解教程*第13章中的内容，如果你有时间，墙裂推荐去翻一下这本书的第13章)   
通过前面的讲解，我们知道委托类似于C/C++中的函数指针，但是委托并不等价于C/C++中的函数指针，否则也没必要单独做一个类型出来．委托类型具有函数指针很多不具有的功能．
这一部分我会做一个辛勤的搬运工来讲解委托的用法.

<h4 id="3.1"> 3.1 声明委托类型 </h4>
```
delegate void MyDel(int x);
```
C#中规定委托需要以delegate关键字开头，其余部分与方法的声明非常类似，有返回类型和签名，但切记，委托是类型，不是方法．还有一点需要注意，
声明委托类型时的返回类型以及签名，必须要与它调用的方法的返回类型跟签名一致，否则就会报错．比如上面的栗子中，`printLow`是一个接受一个int型参数无返回值的方法，
那么委托也只能声明为接受一个int型参数无返回值类型．

<h4 id="3.2"> 3.2 创建委托对象 </h4>
首先委托类型的声明:`MyDel del;`,其中MyDel是委托类型，del是变量．
创建委托对象有两种方式,一种使用new运算符比如: `del = new MyDel(printHigh);`,另一种快捷语法:`del = printHigh;`,这两种是等价的，
后一种之所以有效是因为方法名称跟委托类型之间存在隐式转换．

*注意: 不同编译器对此的处理可能不一样，在Mono下必须要显示转换才能编译通过:`del = (MyDel)printHigh;`,
否则就会报错．win下还未做测试*

<h4 id="3.3"> 3.3 委托的其他一些操作 </h4>
1.组合委托    

```
MyDel delA = printLow; 
MyDel delB = printHigh; 
MyDel delC = delA + delB; 
delC(randValue);//此时会分别执行printLow以及printHigh 
```
2.委托添加以及删除方法

```
MyDel del = printLow;
del += printHigh;
del -= printLow;
del(randValue); //先增加printHigh方法然后又删掉printLow方法．此时只有printHigh方法
```

<h2 id="4"> 4. 匿名方法与Lambda表达式 </h2>
<h4 id="4.1"> 4.1 匿名方法 </h4>
初学者比如我总是会遇到奇型怪状的委托然后一脸茫然，直到我看到了匿名方法才知道他们用的是什么鬼东西．
匿名方法是给那些我们只需要使用一次的方法准备的，因为只用一次，所以总是想着怎么才能少打几个字符．(在这一点上计算机学家跟物理学家都是一样的懒)
举个栗子,我们之前是用独立的具名方法声明方法:

```
public static int printLow(int value){
    Console.WriteLine ("{0} - Low value", value);
    return 0;
}
delegate void Mydel(int value);
Mydel del = printLow;
del(10);
```
如果我们不想这么麻烦，可以用匿名方法:

```
delegate int Mydel(int value);
Mydel del = delegate(int value){
    Console.WriteLine ("{0} - Low value", value);
    return 0;
};
del(10);
```
注意: 1)匿名方法大括号后面的分号是需要的　2)匿名方法不会显示声明返回类型．我们上面这个栗子没有使用返回值.如果你需要返回值，直接`int var = del(10);`即可．

<h4 id="4.2"> 4.2 Lambda表达式 </h4>
Lambda方法可以让代码更加简洁，之所以有Lambda方法还寻在匿名方法，纯粹是历史原因．这里搬运*C#图解教程*上的对Lambda表达式的一些规定，具体用法请查阅相关书籍.
1. 编译器可以从委托的声明中知道委托参数的类型，因此Lambda表达式允许我们省略类型参数，如le2的赋值代码所示.
    - 带有类型的参数列表称为显式类型.
    - 省略类型的参数列表称为隐式类型.
2. 如果只有一个隐式类型参数，我们可以省略周围的圆括号,如le3的赋值代码所示．
3. 最后，Lambda表达式允许表达式的主题是语句块或表达式．如果语句块包含了一个返回语句,我们可以将语句块替换为return关键字后的表达式,如le4的赋值代码所示.

```
MyDel del = delegate(int x)     { return x+1; } ;       //匿名方法
MyDel le1 =         (int x) =>  { return x+1; } ;       //Lambda表达式
MyDel le2 =             (x) =>  { return x+1; } ;       //Lambda表达式
MyDel le3 =              x  =>  { return x+1; } ;       //Lambda表达式
MyDel le4 =              x  =>           x+1;   ;       //Lambda表达式
```

<h2 id="5"> 5. C#中的委托，要比C/C++中的函数指针更加类型安全 </h2>
这部分是我对C#使用委托的理解.　我们前面说C#中没有指针，严格说是不对的，C#为了保证类型安全，默认情况下不允许使用指针，但是使用`unsafe`关键字的话就可以使用指针．
所以说，*C#使用委托而不是函数指针的原因其实是为了保证类型安全*．很多教材跟博客都是说这句话然后就结束了，
后来又看到[一篇博客](http://www.pl-enthusiast.net/2014/08/05/type-safety/)里详细讨论了类型安全,用轮子哥的话说就是,
*同一段内存，在不同的地方，会被强制要求使用相同的办法来解释（interpret)*,所以C里面的union就不是类型安全的，因为同一个内存地址可以按照不同的方式去解释. 
C++要比C类型安全一些，但是使用不当仍然可能造成类型不安全，这里我仍然使用上面那个例子来说明:

```
#include <iostream>
#include <ctime>
#include <cstdlib>

void printLow(int value)
{
    std::cout<<value<<" - Low Value\n";
}

void printHigh(int value)
{
    std::cout<<value<<" - High Value\n";
}
//定义一个指向接受一个int参数且无返回值的函数的指针类型MyDel
    typedef void (*MyDel)(int);

//定义一个指向接受一个float参数且无返回值的函数的指针类型TestDel
    typedef void (*TestDel)(float);

int main()
{
    srand((unsigned)time(NULL)); 
    int randValue = rand() % 100;

    MyDel mydel;
    TestDel testdel;
    mydel = randValue > 50 ? MyDel(printHigh) : MyDel(printLow) ; 

//c++可以检测到这种类型错误并报错
//	testdel = randValue > 50 ? printHigh : printLow ;

//c++允许这种转换且能编译通过
    testdel = (TestDel) mydel;
//运行时会得到不可预测的结果，比如: -1761483232 - High Value
    testdel(randValue);    
    return 0;
}

```  

在这段程序中，我们又声明了一个函数指针类型TestDel,与MyDel不同的是它指向的函数接受一个float类型的参数．接下来，我们通过类型强制转换把MyDel类型转换为TestDel类型，
c++允许这种转换，并且可以编译通过．但是运行就会得到不可预测的结果．C#对此做了严格的限制，它不允许委托类型的转换:

```
using System;

namespace delegateExample
{
	delegate void MyDel(int value); //声明委托类型
	delegate void TestDel(float value); //声明委托类型

	class MainClass
	{
		void PrintLow(int value){
			Console.WriteLine ("{0} - Low value", value);
		}

		void PrintHigh(int value){
			Console.WriteLine ("{0} - High Value", value);
		}

		public static void Main (string[] args)
		{
			MainClass mainclass = new MainClass ();
			MyDel del;	//声明委托变量
			TestDel testdel;
			//创建随机数生成器对象，并得到０到９９之间的一个随机数
			Random rand	= new Random();
			int randomValue = rand.Next (99);
			//创建一个包含PrintLow或者PrintHigh的委托对象并将其赋值给del变量
			del = randomValue < 50
				? new MyDel (mainclass.PrintLow)
				: new MyDel (mainclass.PrintHigh);

			//编译时会直接报错:Cannot convert type `delegateExample.Mydel' to `deledateExample.TestDel'
			testdel = (TestDel)del;

			testdel(randomValue);
		}
	}
}

```

C#在编译时就会报错,
![ErrorInfo]({{site.url}}assets/CsharpDelegate/csharpError.png)

### 其他
以上代码均测试过，不同平台结果可能有差异．测试平台`Ubuntu16.04`,g++版本`5.4.0 20160609`,C#使用Mono测试,版本`5.10`
