---
layout: post
title:  "linux alsa-lib snd_pcm_open函数源码分析（六)"
date:   2020-08-15 00:56:00
categories: 笔记心得
tags: audio linux alsa
excerpt: snd_pcm_open分析系列的第六篇，alsa调用插件的流程总结
mathjax: true
---
* TOC
{:toc}

采用的自定义插件配置如下:

```bash
pcm.rate16k {
    type plug
        slave {
            pcm "hw:0,0"
            rate 16000
        }
}
```

# 1. rate16k的执行流程

本篇重点对alsa加载插件的流程做总结，依然以上面的配置参数为例。如果用户想要使用rate16k这个插件，
则在`snd_pcm_open`函数中传入的name为`rate16k`:

- 参数rate16从`snd_pcm_open`传至`snd_pcm_open_noupdate`,在`snd_pcm_open_noupdate`中,
由于`snd_config_get_string`获取不到string类型的节点返回负数错误码。
流程会执行到`snd_pcm_open_conf`,注意此时传入的配置节点已经为`snd_config_search_definition`找到的pcm的节点，
也就是本篇示例的节点的根节点。

- `snd_pcm_open_conf`接收到的name此时为rate16k,函数会查找type节点，并获取到type对应的字符串plug,
之后拼接出符号`_snd_pcm_plug_open`并从动态库中查找到函数，之后执行此函数。

- 在执行`_snd_pcm_plug_open`函数中，又执行了另一个重要的函数`snd_pcm_open_slave`,此函数实际时调用`snd_pcm_open_named_slave`,
在此函数中，首先去获取string, 此时的节点依然为复合节点，显然获取string失败，此时会再次执行`snd_pcm_open_conf`函数,
区别是此处的配置节点已经不是pcm节点而是slave节点。

- 在`snd_pcm_open_conf`中会获取pcm对应的字符串"hw:0,0",并从"hw:0,0"中分离出hw这个关键字。
分离出来后会继续拼接出符号`_snd_pcm_hw_open`，在动态库中查找到此函数并执行。

- 在`_snd_pcm_hw_open`函数中，获取到了rate的整型值16000,如果有其他值比如"format"或者channels等也会一并获取。
获取到这些参数后，会调用`snd_pcm_hw_open`函数进行真正的hw设备的打开操作。

- 在`snd_pcm_hw_open`函数中会分别调用`snd_ctl_hw_open`及`snd_pcm_hw_open_fd`函数，这两个函数会使用ioctl命令，
调用到内核中去。可以说调用到这两个函数时已经到了用户态的最底层，调用`snd_pcm_hw_open_fd`最终会返回pcmp,
这个参数会向上`snd_pcm_hw_open`-->`_snd_pcm_hw_open`-->`snd_pcm_open_conf`-->`snd_pcm_open_named_slave`-->`snd_pcm_open_slave`。

- 此时返回到`_snd_pcm_plug_open`中，由于`snd_pcm_open_slave`实际已经返回了hw设备的handle,
返回的这个handle作为slave设备的handle作为参数传入到`snd_pcm_plug_open`中。

- 在`snd_pcm_plug_open`中通过`snd_pcm_new`创建一个plug设备，并把slave设备的handle赋值为plughandle结构体中的gen.slave字段。
同时`pcm->fast_ops`实际为`slave->fast_ops`，即实际为hw设备的`fast_ops`。

至此，采用本篇举例的配置的插件加载完成。

# 2. 更复杂插件的流程

如果使用了更复杂的插件，即slave设备不是hw设备而是其他插件，则在执行`snd_pcm_open_slave`中调用`snd_pcm_open_conf`时，
传入的参数会是其他插件的名称，此时会进一步递归，再次查找传入`snd_pcm_open_conf`,只要传入的参数不是'hw'类型，则会一直递归。
最终会拼接出所有插件的符号并从动态库中找到这些函数执行。

# 3. snd_pcm_open总结

`snd_pcm_open`函数确实比较复杂，半年前接触alsa时还对alsa一无所知，同时发现网络上alsa的资料太少了，
仅有的资料也比较老，特别是内核部分的代码，kernel-4.4比2.6版本做了很多的改动，往往看了资料再去看代码发现根本不是这么回事，
无奈之下还是看源代码，结果发现第一个函数`snd_pcm_open`就如此复杂。

期间设备树匹配，codec驱动修改，重采样混音插件，音频算法集成，高通滤波等等功能都一一实现，但是依然对`snd_pcm_open`的工作不够清楚，
它复杂，健壮，神秘，几乎无任何源码分析的相关资料，这种挑战驱使我每当有空都要花点时间去分析它，前前后后花了接近三个月的周末休息时间，
终于捋清了它的大概脉络。尽管如此，对alsa的很多细节还是不够了解，比如配置树的数据结构，比如重采样插件具体执行重采样的过程。
对于重采样的具体过程，目前分析到是调用到了pcm_rate.c中的函数，并最终调用到了alsa-plugin库内的函数去具体执行重采样的过程，
但是这些重采样的参数是什么时候，通过什么参数告诉alsa的目前还不是很清楚，后续有时间还会继续跟踪。
