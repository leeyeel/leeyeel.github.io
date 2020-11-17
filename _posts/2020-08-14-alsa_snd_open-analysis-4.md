---
layout: post
title:  "linux alsa-lib snd_pcm_open函数源码分析（四)"
date:   2020-08-15 00:56:00
categories: 笔记心得
tags: audio linux alsa
excerpt: snd_pcm_open分析系列的第四篇，介绍snd_pcm_open_noupdate子函数
mathjax: true
---
* TOC
{:toc}

`snd_pcm_open_noupdate`实际执行起来要比我们单纯分析代码复杂的多，
因为函数同样时采用了多层嵌套递归的方式，特别是如果使用了alsa的多个插件，
执行过程会更下复杂。

总体的思想是读取配置树，根据配置文件插件类型拼接出函数符号，然后从动态库中查找函数来执行，
在这些函数中会一层一层的往下调用，最终调用的硬件层。同时每一层调用返回的设备都会以链表的形式链接起来。

最终返回的snd_pcm_t句柄中，实际包是所有插件句柄的最外层入口，通过此入口可以依次查找到所有的插件句柄。

# 1.函数原型

```c
static int snd_pcm_open_noupdate(snd_pcm_t **pcmp, snd_config_t *root,
                 const char *name, snd_pcm_stream_t stream,
                 int mode, int hop)
{
    int err;
    snd_config_t *pcm_conf;
    const char *str;

    //从pcm下查找name配置节点
    err = snd_config_search_definition(root, "pcm", name, &pcm_conf);
    if (err < 0) {
        SNDERR("Unknown PCM %s", name);
        return err;
    }
    //获取节点string,通常不是string则返回错误码
    if (snd_config_get_string(pcm_conf, &str) >= 0)
        err = snd_pcm_open_noupdate(pcmp, root, str, stream, mode,
                        hop + 1);
    else {
        snd_config_set_hop(pcm_conf, hop);
        //这里是重要入口，打开配置文件,在打开配置文件过程中逐渐执行了所有的函数
        err = snd_pcm_open_conf(pcmp, name, root, pcm_conf, stream, mode);
    }
    snd_config_delete(pcm_conf);
    return err;
}
```
