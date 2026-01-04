---
layout: post
title:  "Rust绘制曼德博集合Mandelbrot set" 
date:   2026-01-04 16:42:00
categories: 学习总结
tags: rust 
excerpt: Mandelbrot 集：从数学定义到使用Rust绘制图形
mathjax: true
---
* TOC
{:toc}

## Mandelbrot集合是什么

起因是在写AI Agent，写AI Agent就一定会参考OpenAI/Codex, 参考Codex就要看Rust代码，
不会Rust就要学，学习Rust选择阅读O'REILLY的《Rust程序设计》, 其中第二章遇到了Mandelbrot集。

阅读到这里的时候，一方面感叹数学图案竟然这么复杂深邃又迷人，
另一方面有好几个疑问并没有在书中找到答案。所以在阅读完这个章节后，
又重新在ChatGPT的帮助下梳理了疑问，重新组织了一篇更详细的介绍,希望能帮助其他也有疑问的小伙伴。

![]({{site.url}}assets/mandelbrot/mandelbrot-1.webp)

首先就是Mandelbrot集到底是什么，它的数学定义其实很简单:

对于复数 ( c )，从[z_0 = 0] 开始，它的n+1} = z_n^2 + c]

如果这个序列 **不会发散**（即 (|z_n|) 始终有界），那么复数 ( c ) 就属于 Mandelbrot 集。

需要注意：( c ) 是复数, 且没有解析公式，只能通过迭代计算判断

没有解析公式，实际上决定了我们后续的程序结构。

以上是Mandelbrot集的数学定义，为了更容易的理解，这里直接使用书中提到的引导。

![]({{site.url}}assets/mandelbrot/mandelbrot-0.png)

对于下面的一个循环赋值,如果可以运行的话，x的值会如何变化？对于小于1的数求平方会得到一个更小的数，
即结果趋向于0，1的平方还是1，对于大于1的数平方会得到更大的数字，即结果趋向于无穷大。
因此根据传入的值，x要么趋向于0，要么一直是1，要么趋向于无穷大。

```rust
fn square_loop(mut x: f64) {
    loop {
        x = x * x;
    }
}
```

但是对于下面的例子,情况会变得有些复杂。这一次，x从0开始，每次迭代会在平方之后加上一个c。

```rust
fn square_add_loop(c: f64) {
    let mut x = 0.;
    loop {
        x = x * x + c;
    }
}
```
用归纳法可以证明，如果`c < -2`或者`c > 1/4`, 则迭代之后一定是发散的。
如果再复杂一点，不仅限于实数，推广到复数。

```rust
use num::Complex;
fn complex_square_add_loop(c: Complex<f64>) {
    let mut z = Complex { re: 0.0, im: 0.0 };
    loop {
        z = z * z + c;
    }
}
```

这个证明起来有些复杂，直接给出结论，如果c属于Mandelbrot集合，则`|Zn| < 2`,
反过来也成立，如果`|Zn| > 2`, 则最终迭代一定会发散，
这样我们可以直接通过判断迭代过程中|Zn|是否大于2来判断这个c是否属于Mandelbrot集合。
不过我们的运算毕竟是有限的，不可能无限增加精度。有可能发散速度非常慢，在我们有限的运算内仍然没有大于2，
所以我们需要返回迭代次数，通过迭代次数设置像素颜色，大体上可以绘制Mandelbrot集合图像。


## 为什么不能从集合出发？

如何画出mandelbrot集合呢？很直观的会产生这样的想法：

> Mandelbrot 集是一个集合，
> 那先把集合的内容计算出来，然后在平面上绘制这些数据点。

答案是：**做不到，也不该这么做。**

原因在于Mandelbrot 集是 **连续的**, 它具有 **无限精细的结构**,我们没有“枚举所有点”的方法

因为无法“生成 Mandelbrot 集”，所以我们只能 **测试某一个复数是否属于它**。

所以正确的绘制顺序应该是先从图像像素出发，把这个像素映射到选中的复平面内，
然后判断这个点在有限次的运算中，是否会出现|Zn| > 2，从而判断这个点是否属于Mandelbrot 集。

```
像素 → 复数 → 是否逃逸 → 着色
```
而不是反过来。

## 为什么必须做“像素 → 复平面”的映射？

```rust
fn pixel_to_point(bounds: (usize, usize), pixel: (usize, usize),
                  upper_left: Complex<f64>, lower_right: Complex<f64>) -> Complex<f64> {
    let (width, height) = (lower_right.re - upper_left.re, upper_left.im - lower_right.im);
    Complex {
        re: upper_left.re + pixel.0 as f64 * width / bounds.0 as f64,
        im: upper_left.im - pixel.1 as f64 * height / bounds.1 as f64
    }
}
```
[
\begin{aligned}
\mathrm{Re}(c) &= x_{\min} + \frac{x}{W}(x_{\max}-x_{\min}) \
\mathrm{Im}(c) &= y_{\max} - \frac{y}{H}(y_{\max}-y_{\min})
\end{aligned}
]

其中：

* ((x, y)) 是像素坐标
* (W, H) 是图像宽高
* ([x_{\min}, x_{\max}] \times [y_{\min}, y_{\max}]) 是复平面区域

以上书中的Rust代码，对于这个映射，我的另一个疑问是，

> 一个像素不也是一个点吗？
> 为什么要引入“复平面区域”？

这里的关键区别在于：**像素是点**, 但“像素对应哪个复数”这个关系，必须由一个 **复平面区域** 来定义

否则我们无法回答这几个问题：

* 屏幕左上角是哪个复数？
* 右下角是哪个复数？
* 实轴与虚轴的比例是多少？

所以代码中，我们做的并不是：

> 像素 → 复数点

的映射，而是：

> 像素 → 复平面某个矩形区域中的点

这种映射。

这个函数完成的数学映射可以写成：

## 为什么放大后经常“一片漆黑”？

书中代码区域并不能看到Mandelbrot集合的全貌，是因为所选区域-1.20,0.35 -1,0.20本身无法覆盖全貌。
为了看清图像内部，通常会选则更小的区域，但是实际体验时经常遇到漆黑一片的情况，
原因通常不是代码错误，而是 **选区错误**。

### Mandelbrot 图像中可分为三类区域：

1. **集合内部**
   所有点都不逃逸 → 通常绘制为黑色

2. **集合外部**
   很快逃逸 → 颜色变化单调

3. **集合边界**
   逃逸与不逃逸的临界区域 → 分形细节全部来自这里

如果我们选择放大的窗口：

* 完全落在集合内部 → 整张黑
* 离边界太远 → 细节很少

### 一条非常实用的经验法则：

> **放大一定要沿着边界走**

也就是“看起来快要全黑，但还没完全黑”的地方。但是实际处理起来，特别使我们当前的Rust代码，
无法沿着边界走，一个稳妥的方法是直接沿着经典观光路线。

下面是一条 **4:3 比例 · Seahorse Valley（海马谷）** 的示意路径，适合初学者逐步放大观察。

### 五个窗口区域（左上 → 右下）

```
-2.5,1.5  1.5,-1.5
-0.95,0.25  -0.55,-0.05
-0.7635,0.1464  -0.7235,0.1164
-0.7456439,0.1333259  -0.7416439,0.1303259
-0.7438408,0.1319773  -0.7434408,0.1316773
```

我们只需要：固定图像比例为 4:3,比如我是4000x3000, 依次用这些复平面窗口渲染,
每一张图适当提高最大迭代次数即可绘制, 就能清晰看到分形结构逐步展开。

![]({{site.url}}assets/mandelbrot/mandelbrot-2.webp)

![]({{site.url}}assets/mandelbrot/mandelbrot-3.webp)

![]({{site.url}}assets/mandelbrot/mandelbrot-4.webp)
