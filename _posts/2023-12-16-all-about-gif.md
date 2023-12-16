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
(索引值应该是0-255之间的数字)。这样，对于某个颜色种类小于256种的图片，则可以实现无损压缩。
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

![]({{site.url}}assets/gif/truecolor1.gif)

![]({{site.url}}assets/gif/truecolor2.gif)


### 具体文件格式

下面我们举例介绍GIF的具体文件格式

| 字节偏移 (hex) | Hexadecimal     | 文本或数值 | 释义                                      |
|--------------|-----------------|---------------|--------------------------------------------------|
| 0            | 47 49 46 38 39 61 | GIF89a        | 头|
| 6            | 03 00            | 3             | 逻辑宽（注意，不一定就是图片宽）                            |
| 8            | 05 00            | 5             | 逻辑高                            |
| A            | F7               |               | GCT follows for 256 colors with resolution...    |
| B            | 00               | 0             | 背景色: index #0; #000000 black        |
| C            | 00               | 0             | 默认像素宽高比, 0:0                  |
| D            | 00 00 00         |               | 全局颜色表(Global Color Table,GCT), color #0: #000000, black     |
| 10           | 80 00 00         |               | Global Color Table, color #1: transparent...     |
| ...          | ...              | ...           | ...                                              |
| 30A          | FF FF FF         |               | Global Color Table, color #255: #ffffff, white   |
| 30D          | 21               | '!'           | An Extension Block...                            |
| 30E          | F9               |               | A Graphic Control Extension                      |
| 310          | 01               |               | Transparent background color; bit field...       |
| 311          | 00 00            |               | Delay for animation in hundredths of a second... |
| 313          | 10               | 16            | Color number of transparent pixel in GCT         |
| 314          | 00               |               | End of GCE block                                 |
| 315          | 2C          | ','           | An Image Descriptor (introduced by 0x2C, an ASCII comma ',') |
| 316          | 00 00 00 00 | (0, 0)        | North-west corner position of image in logical screen |
| 31A          | 03 00 05 00 | (3, 5)        | Image width and height in pixels |
| 31E          | 00          | 0             | Local color table bit, 0 means none |
| 31F          | 08          | 8             | Start of image, LZW minimum code size |
| 320          | 0B          | 11            | Beginning of first data sub-block, specifying 11 bytes of encoded data to follow |
| 321          | <image data>|               | 11 bytes of image data, see field 320 |
| 32C          | 00          | 0             | Ending data sub-block, specifying no following data bytes (and the end of the image) |
| 32D          | 3B          | ';'           | File termination block indicator (an ASCII semi-colon ';') |

注意，GIF真正的数据基本都在上述表格中的0x321偏移处,只不过这里举例中只有11个字节，再次注意，
这里的image data并不是直接的颜色索引值，而是经过LZW编码后的数据。

### 软件使用

首先是ffmpeg，尽管它是一个音视频框架，但是由于视频与动态图天然的联系，ffmpeg在n2.6版本(2015年)就对GIF做了支持，
尽管支持图片或者视频转为gif,但是如果原视频或者图片带有透明通道,转换后透明通道会丢失。这个功能直到n4.0(2017年）才开始支持。
所以ffmpeg版本低于4.0的linux发行版比如ubuntu18.04均无法转换带透明通道的GIF,需要更新ffmpeg版本或者使用更新的linux发行版。
不过尽管n4.0支持透明通道，但是转换效果并不好，会有部分透明边界问题，使用时还是推荐升级到最新版本。


在n4.0中，palattegen filter中开始添加透明通道
```
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
