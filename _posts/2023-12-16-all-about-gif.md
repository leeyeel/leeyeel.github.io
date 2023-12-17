---
layout: post
title:  "GIF图片格式简史"
date:   2023-12-16 23:31:00
categories: 教程
tags: gif 音视频 图像
excerpt: GIF图片格式的历史，格式介绍，以及ffmpeg等对gif的处理
mathjax: true
---

### 严重告警

本文严重抄袭维基百科的GIF词条，大部分内容可直接参考[维基原文](https://en.wikipedia.org/wiki/GIF)
同时严重抄袭这篇[What's In A
GIF](https://giflib.sourceforge.net/whatsinagif/bits_and_bytes.html)

强烈推荐去看下原文，写的非常详细且系统

### GIF的前世今生

GIF（Graphics Interchange Format, 图形交换格式）诞生于1987年，它的目的是创建一种体积小，
便于在当年的小水管网络上传播，同时质量又说的过去的图像格式。
GIF最初的版本是87a，随后在1989年推出了增强版89a，增强版中新增了动画、透明背景和元数据存储的支持。
凭借其支持动画的能力和相对较小的文件大小，GIF很快在网络图像，尤其是简单图像如标志和按钮领域中广受欢迎。
即便到了今天(2023)年，GIF仍然是最流行的动态图格式，以至于孤陋寡闻的我，一直以为GIF是专为动态图设计的。

GIF最开始是由史蒂芬·威尔海特（Stephen Wilhite）在Compuserve公司带领团队开发，
顺便说一句威尔海特也在2013年获得威比奖（The Webby Award）终身成就奖，并于2022年3月14日因COVID-19及并发症逝世，
享年74岁。GIF本身并不支持动图循环播放，它原始的规则只支持它从第一帧播放到结束，
后来网景公司(Netscape，是的，就是创造了firefox浏览器，并在浏览器大战中输给了微软的那个网景)在1990年拓展了GIF,
在Netscape Navigator 2.0版本中率先支持了动画循环播放，后来逐渐被各个浏览器支持，最终变成了GIF事实上的标准。

### 文件格式概述

GIF格式采用调色板模式，即有一个颜色表，每种颜色可以使用RGB24格式存储，最多可以有256种颜色。
这256种颜色构成了GIF的调色板（RGB24每个颜色3字节，256颜色则3*256=3 * 0x100 = 0x300个byte）。
之后对于原始图像中的每个像素，不再使用具体的像素值，而是直接使用这个颜色在调色板中的索引值
(索引值应该是0-255之间的数字)。

这样，对于某个颜色种类小于256种的图片，则可以实现无损压缩。
对于超过256种颜色的图片来说，无论如何也是会产生信息损失的，只不过可以使用一些技巧把这种信息损失降到最低，
比如使用[Dither方法](https://en.wikipedia.org/wiki/Dither)具体的方法就不在这里讨论了,可参考

对于一张分辨率较高的图片，由于像素数目比较多，而颜色又总共只有256种，必然又大量重复的索引值，
GIF使用了LZW这种无损编码算法进一步对数据进行了压缩。关于LZW专利，这里面还有一场早期的互联网斗争。
LZW是被Unisys这家公司申请了专利的，但是当时没人注意到这一点，或者没人在意。
等到1994年，Unisys这家忽然宣布要所有使用LZW的公司都要付费。甚至到1999年时又修改了许可条款，
未经允许任何人都无法使用。最终引发了一场“Burn GIFs”的运动，即要把所有GIF图片转换为PNG格式，
客观上也促进了PNG格式的发展。甚至GIF也推出过方案使得索引值可以不经过LZW压缩，以此来规避专利问题。
当然Unisys的专利已于2004年到期，现在GIF真正属于互联网了。

在GIF的89a版本中，添加了对透明度及动态图的支持。这里的透明度，只有0跟1两个值，即完全透明跟完全不透明。
对动态图的支持，表明GIF支持多帧图像，且GIF支持每帧图像都有自己的调色板，
这样就可以通过把原图划分为多个区域，每个区域都用256种颜色来表示，
最后再利用透明度这个功能在不同的帧中只显示自己的部分，最终把不同的区域叠加起来，
原则上就可以创造出远多余256种颜色。只不过采用这种方法需要多帧，会增大GIF本身体积，
虽然原理上可行，但是实用价值不大。下面的图片用来展示这个方法。

![]({{site.url}}assets/gif/truecolor1.gif)![]({{site.url}}assets/gif/truecolor2.gif)


### 具体文件格式

下面介绍GIF的具体文件格式,以a89为例,GIF的格式组成由下图，

![]({{site.url}}assets/gif/gif_file_stream.gif)

注意实线框为必须项，虚线框为可选项。

![]({{site.url}}assets/gif/sample_1.gif)![]({{site.url}}assets/gif/binary-raw.png)

上图是个极其简单的GIF图，右侧是它的二进制数据，我们分别来看GIF的各个字段:

- Header Bloack

数据为`47 49 46 38 39 61`,其实就是GIF89a的ASCII码。

![]({{site.url}}assets/gif/header_block.gif)

- Logical Screen Descriptor

![]({{site.url}}assets/gif/logical_screen_desc_block.gif)

数据为`0A 00 0A 00 91 00 00`, 逻辑屏幕描述符紧随标题之后,总共7个字节。

    - Canvas width, Canvas height

        这里的宽度跟高度不一定就是整个图像的宽度跟高度，如果分块的话，就是分块的宽度跟高度，这个字段的目的就是给分块提供可能。

    - Packed Filed

        - global color table flag 
        全局颜色表标志,为0，表示没有全局颜色表。为1，表示有全局颜色表(我们的例子中有一个全局颜色表）。

        - color resolution.
        它代表的是颜色位深。只有在有全局颜色表时才有意义。如果这个字段的值是N，则位深为N+1, 能表示的颜色种类总数目将是2^(N+1)。
        样本图像中的001代表2位/像素；111将代表8位/像素。
    
        - sort flag
        非必须，如果为1,则表示全局颜色表中的颜色按照重要性递减的顺序排序，即图像中出现的频次递减。
        对解码有帮助，但不是必须的。

        - size of Global Color Table
        全局颜色表中的颜色个数，比如值为N，则颜色表个数为2^(N+1)


    - background color index

    背景颜色的索引，这个索引对应的全局颜色表中的颜色，将会被认为为背景

    - pixel aspect ratio

    像素宽度与高度的比值。这个参数几乎被所有现代浏览器忽略,具体用处可能与当年的模拟电视图像有关。

- Global Color table
    
数据为`FF FF FF FF 00 00 00 00 FF 00 00 00`,使用RGB24格式表示的调色板，个数根据上面的`size of Global Color Tabl`来决定。

![]({{site.url}}assets/gif/global_color_table.gif)


- Graphics Control Extension

数据为`21 F9 04 00 00 00 00 00`,这部分是89a的扩展内容，目的是支持透明度以及动态图。本例中的图片没有透明度及动画，
这两方面的内容可参考[Transparency and
Animation](https://giflib.sourceforge.net/whatsinagif/animation_and_transparency.html)

![]({{site.url}}assets/gif/graphic_control_ext.gif)

    - extension introducer

    固定为0x21

    - graphic control label

    固定为0xF9

    - block size 

    总共的字节数,通常四个字节

    - Packed Filed
    共1个字节,其中前三位保留，接下来的三位为disposal method, 用来制定切换到下一幅图像应该如何处理，共可表示0-7,
    动画图像的值是 1，这表明解码器应该保持当前图像不变，并在其上绘制下一幅图像。如果是 2，就意味着画布应恢复到背景色；3 则表示画布应恢复到绘制当前图像之前的状态。
    据我所知，这个值并不被广泛支持。对于 4 到 7 的值，其行为还没有定义。如果这个图像不是动画，这些位通常会被设为 0，表示没有特定的处理方法。

    第7位是用户输入标志，当其为 1 时，表示解码器会等待用户输入才会切换到下一幅图像。不过，在大多数情况下，这个位的值会是 0。

    最后一位是透明度标志。如果需要透明度，则需要设置为1,否则设置为0

    - delay time
    用来控制动态图的帧率，单位是百分之一秒，即10毫秒。

    - Transparent Color index

    透明颜色索引。指定哪个颜色为透明，哪个颜色就像涂了隐身药水变透明

    - Block terminator

    块结束符号，通常00

- Image Descriptor

![]({{site.url}}assets/gif/image_descriptor_block.gif)

数据为`2C 00 00 00 00 0A 00 0A 00 00`,
第一个字节是图像分隔符，每个图像描述符块都以 2C 作为起始值。接下来的 8 个字节用于表示随后图像的位置和大小。
一个 GIF 文件可以包含多幅图像。在最初的 GIF 设计中，这些图像是为了组合到一个更大的虚拟画布上。然而，如今多幅图像通常用于制作动画。
每幅图像都从同一个图像描述符块开始，本例中这个块的长度恰好为 10 字节。
在 GIF 中，图像并不一定要占据逻辑屏幕描述符定义的整个画布大小。因此，图像描述符块会指定图像在画布上的起始左边距和上边距位置。但现代的查看器和浏览器通常会忽略这些字段。
接下来，这个块会指定图像的宽度和高度。这些值都是使用两字节、无符号、小端格式表示的。我们的示例图像显示，图像从 (0,0) 开始，宽度和高度均为 10 像素（这意味着图像占据了整个画布）。

最后一个字节又是一个Packed Filed。在我们的示例文件中，这个字节是 0，因此所有的子值都将是零。

    -  local color table flag
    局部颜色表标志。将这个标志设置为 1 允许您指定随后的图像数据使用的颜色表与全局颜色表不同。

    - interlace flag
    交错标志。交错改变了图像呈现在屏幕上的方式，可以减少令人讨厌的视觉闪烁,视觉闪烁的原因，又要追溯到上世纪模拟显示器的扫描方式。
    交错在显示器上的效果是，先显示图像其中一部分，这样观众可以先看到一个模糊的图像，然后逐渐清晰，最后完全显示，也是在那个宽带极其有限的情况下的产物。
    防止屏闪可以不考虑，因为现在的显示器不会有这个问题。关于显示效果举个例子一看就明白了，左边是顺序显示，右边是交错显示。

![]({{site.url}}assets/gif/no-interlaced.gif)![]({{site.url}}assets/gif/interlaced.gif)

    - 其余sort flag, size of local color table
    与前文描述一致，只不过是局域颜色表

- Local Color Table

    与全局颜色表一致，需要local color table flag为1生效

- Image Data

数据为`02 16 8C 2D 99 87 2A 1C DC 33 A0 02 75 EC 95 FA A8 DE 60 8C 04 91 4C 01 00`,

通常情况下这部分才是GIF最主要的内容，只不过我们举的例子太小了所这这部分内容较少，
需要说明的是这部分需要LZW编码。具体编码方案这里不做介绍。

![]({{site.url}}assets/gif/image_data_block.gif)


- Plain Text extension

数据内容为：`21 01 0C 00 00 00 00 64 00 64 00 14 14 01 00 0B 68 65 6C 6C 6F 20 77 6F 72 6C 64 00`。

GIF 89a标准允许在接下来的图像上添加文本标题。然而，这个功能并没有广泛流行；像 Photoshop 这样的浏览器和图像处理软件通常会忽略这一功能。
就像所有扩展块类型一样,这个块以扩展引入符开始,这个值总是 21。下一个字节是纯文本标签, 这个值 01, 用于将纯文本扩展与所有其他扩展区分开来。
接下来的字节是块大小,表示实际文本数据开始之前有多少字节，或换句话说现在可以跳过多少字节。
字节值可能是 0x0C，这意味着应该向前跳过 12 个字节。随后的文本被编码在数据子块中,当到达长度为 0 的子块时，该块结束。

- Application extension

数据内容为:`21 FF 0B 4E 45 54 53 43 41 50 45 32 2E 30 03 01 05 00 00`,
GIF89规范允许在 GIF 文件本身中嵌入特定于应用程序的信息。这种能力并没有得到广泛使用。
大约唯一已知的公开使用是就是前面提到的 Netscape 2.0 扩展，它用于循环播放动画 GIF 文件


- Comment Extension

数据内容为:`21 FE 09 62 6C 75 65 62 65 72 72 79 00`
![]({{site.url}}assets/gif/comment_ext.gif)

GIF89 规范中的最后一个扩展类型是评论扩展。这允许你在 GIF 文件中嵌入 ASCII 文本，通常用于添加图像描述、图像版权信息或其他人类可读的元数据，如图像捕获的 GPS 位置。
这个扩展的第一个字节是扩展引入符，编号为 21。接下来的一个字节总是 FE，代表评论标签。然后我们直接跳到包含评论 ASCII 字符代码的数据子块。
从例子中我们可以看到，这里有一个长度为 9 字节的数据子块。如果你将这些字符代码翻译出来，会发现评论内容是“blueberry”。
最后一个字节 00 表示一个没有后续字节的子块，标志着我们已经到达了这个块的末尾。

- Trailer

数据内容为:`3B`

![]({{site.url}}assets/gif/trailer_block.gif)

### 软件使用

首先是ffmpeg，尽管它是一个音视频框架，但是由于视频与动态图天然的联系，ffmpeg在n2.6版本(2015年)就对GIF做了支持，
尽管支持图片或者视频转为gif,但是如果原视频或者图片带有透明通道,转换后透明通道会丢失。这个功能直到n4.0(2017年）才开始支持。
所以ffmpeg版本低于4.0的linux发行版比如ubuntu18.04均无法转换带透明通道的GIF,需要更新ffmpeg版本或者使用更新的linux发行版。
不过尽管n4.0支持透明通道，但是转换效果并不好，会有部分透明边界问题，使用时还是推荐升级到最新版本。


在n4.0中，palattegen filter中开始添加透明通道

```diff&patch
diff --git a/libavfilter/vf_palettegen.c b/libavfilter/vf_palettegen.c
index 03de317348..5ff73e6b2b 100644
--- a/libavfilter/vf_palettegen.c
+++ b/libavfilter/vf_palettegen.c
@@ -27,6 +27,7 @@
 #include "libavutil/internal.h"
 #include "libavutil/opt.h"
 #include "libavutil/qsort.h"
+#include "libavutil/intreadwrite.h"
 #include "avfilter.h"
 #include "internal.h"

@@ -74,6 +75,7 @@ typedef struct PaletteGenContext {
     struct range_box boxes[256];            // define the segmentation of the colorspace (the final palette)
     int nb_boxes;                           // number of boxes (increase will segmenting them)
     int palette_pushed;                     // if the palette frame is pushed into the outlink or not
+    uint8_t transparency_color[4];          // background color for transparency
 } PaletteGenContext;

 #define OFFSET(x) offsetof(PaletteGenContext, x)
@@ -81,6 +83,7 @@ typedef struct PaletteGenContext {
 static const AVOption palettegen_options[] = {
     { "max_colors", "set the maximum number of colors to use in the palette", OFFSET(max_colors), AV_OPT_TYPE_INT, {.i64=256}, 4, 256, FLAGS },
     { "reserve_transparent", "reserve a palette entry for transparency", OFFSET(reserve_transparent), AV_OPT_TYPE_BOOL, {.i64=1}, 0, 1, FLAGS },
+    { "transparency_color", "set a background color for transparency", OFFSET(transparency_color), AV_OPT_TYPE_COLOR, {.str="lime"}, CHAR_MIN, CHAR_MAX, FLAGS },
     { "stats_mode", "set statistics mode", OFFSET(stats_mode), AV_OPT_TYPE_INT, {.i64=STATS_MODE_ALL_FRAMES}, 0, NB_STATS_MODE-1, FLAGS, "mode" },
         { "full", "compute full frame histograms", 0, AV_OPT_TYPE_CONST, {.i64=STATS_MODE_ALL_FRAMES}, INT_MIN, INT_MAX, FLAGS, "mode" },
         { "diff", "compute histograms only for the part that differs from previous frame", 0, AV_OPT_TYPE_CONST, {.i64=STATS_MODE_DIFF_FRAMES}, INT_MIN, INT_MAX, FLAGS, "mode" },
@@ -250,7 +253,7 @@ static void write_palette(AVFilterContext *ctx, AVFrame *out)

     if (s->reserve_transparent) {
         av_assert0(s->nb_boxes < 256);
-        pal[out->width - pal_linesize - 1] = 0x0000ff00; // add a green transparent color
+        pal[out->width - pal_linesize - 1] = AV_RB32(&s->transparency_color) >> 8;
     }
 }
```
使用ffmpeg转换图片并保留透明通道的方法：

```
ffmpeg -i input.gif -vf "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -gifflags +transdiff -y out.gif

#注意，只有vf部分是必须的，gifflags只是为了提高编码效率
```

其次可以使用`imagemagick`工具进行转换，此工具不仅支持gif动态图，还支持webp动态图，
比如使用`imagemagick 6`缩放gif则可简单使用：

```
convert input.gif -resize 300x200 out.gifflags
```

`imagemagic 7`版本命令方式有所改变，不过改变不大，这里不再详细讨论
