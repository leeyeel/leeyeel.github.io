---
layout: post
title:  "linux alsa-lib snd_pcm_open函数详细分析（一)"
date:   2020-08-11 11:56:00
categories: 笔记心得
tags: audio linux alsa
excerpt: snd_pcm_open分析系列的第一篇，介绍函数原型，作用，以及使用中的位置
mathjax: true
---

`snd_pcm_open`通常是接触alsa-lib的第一个api,也通常是使用alsa进行录音或播放的第一步。
正如名字中表示的一样，`snd_pcm_open`用来打开一个pcm音频设备，并得到这个音频设备的句柄，
即便用户使用了alsa的插件，使用时也同样是使用此接口，非常方便。但是这种使用上的方便是以`snd_pcm_open`及其复杂的实现为代价的。
这篇笔记的目的就是尽可能详细的分析这个函数到底做了什么工作，以及这些工作到底是怎么实现的。

### 1.版本信息

- alsa-lib-1.1.5
- alsa-plugins-1.1.5
- linux-kernel-4.4.167

### 2.函数原型

`snd_pcm_open`实现位于`alsa-lib/src/pcm/pcm.c`中。
从函数实现上主要有两个功能，第一个是更新配置文件，第二个是打开设备。
这两个函数过程都很复杂，后面我们会继续详细解释。
```c
/*
 * \brief Opens a PCM
 * \param pcmp 返回pcm句柄
 * \param name 要打开的pcm设备的名字
 * \param stream 想要的stream类型
 * \param mode 打开模式 (see #SND_PCM_NONBLOCK, #SND_PCM_ASYNC)
 * \return 0 表示成功，否则返回一个负的错误码
 */
int snd_pcm_open(snd_pcm_t **pcmp, const char *name,
         snd_pcm_stream_t stream, int mode)
{
    snd_config_t *top;
    int err;

    assert(pcmp && name);
    err = snd_config_update_ref(&top);
    if (err < 0)
        return err;
    err = snd_pcm_open_noupdate(pcmp, top, name, stream, mode, 0);
    snd_config_unref(top);
    return err;
}
```

### 4.使用示例

下面是一段播放音频的代码，大部分来自于alsa-utils中的aplay.c文件，为了方便了解使用流程对其做了精简，
此示例仅仅为了说明`snd_pcm_open`的位置，无法直接编译运行。
```c
static int play_process(snd_pcm_t *handle, char *play_name)
{
    int err;
    snd_pcm_hw_params_t *params;
    snd_pcm_t *handle;
    char *pcm_dev_name = PLAY_DEV_NAME;
    snd_pcm_format_t format = SND_PCM_FORMAT_S16_LE;

    /*音频文件的参数，此处需要与实际音频文件对应*/
    unsigned channels = 2;  /* 表示play_name这个文件为双声道 */
    unsigned rate =16000;   /* 表示play_name这个文件的采样率为16000 */
    /* 25表示每秒25帧数据，也可以选其他值 */
    snd_pcm_uframes_t frames = rate / 25;
    int read_size = 0;

    printf("playing file name is:%s \n", play_name);

    /* 打开pcm设备，此函数是我们分析的全部*/
    err = snd_pcm_open(&handle, pcm_dev_name, SND_PCM_STREAM_PLAYBACK, 0);
    if (err < 0){
        printf("failed to open pcm device, error:%d\n",err);
        return err;
    }

    /*未具体实现此函数，只是为了说明这里需要设置参数*/
    /*具体的实现可以参考alsa-utils/aplay/aplay.c文件*/
    err = set_parameters(handle, format, channels, rate, frames);
    if (err < 0){
        printf("failed to open %s \n", play_name);
        return err;
    }
    int size = frames * snd_pcm_foramt_size(format, channels);
    char *buffer = malloc(size);
    FILE *file = fopen(play_name, "rb");
    if(!file){
        printf("failed to open %s\n", play_name);
        return -1;
    }

    while(1){
        memset(buffer, 0, size);
        read_size = fread(buffer, 1, size, file);
        if(read_size != size){
            printf("read %d bytes rather than %d\n", read_size, size);
            break;
        }
        err = snd_pcm_writei(handle, buffer, frames);
        if(err == -EPIPE){
            printf("-EPIPE\n");
            snd_pcm_prepare(handle);
        }
    }
    close(file);
    snd_pcm_drain(handle);
    sdn_pcm_close(handle);
    free(buffer);

    return 0;
}
```
### 5.代码分析

下面是对`snd_pcm_open`函数的分析过程，函数主要实现了两个工作:更新配置文件及打开pcm设备。
我们按照这两部分分别进行分析。

##### 5.1 snd_config_update_ref

函数的目的是更新snd_config配置,与`snd_config_update_r`功能类似，主要区别是此函数会增加引用计数，
所以在引用计数为0前获取到配置树将永远不会被删除。同时由于函数使用了锁，所以函数是线程安全的。

注意这里的参数top，是个二级指针。在`snd_pcm_open`中传下来的是`snd_config_t *top;`中top的地址。

关键函数`snd_config_update_r`的详细分析参考[inux alsa-lib snd_pcm_open函数详细分析（二)]({{site.url}}/2020/08/11/alsa_snd_open-analysis-2)

```c
/* top为出参 */
int snd_config_update_ref(snd_config_t **top)
{
    int err;

    if (top)
        *top = NULL;
    snd_config_lock();  /*加锁保证线程安全*/
    /* 主要功能实现在此，后续文章会继续分析 */
    err = snd_config_update_r(&snd_config, &snd_config_global_update, NULL);
    if (err >= 0) {
        if (snd_config) {
            if (top) {
                snd_config->refcount++; /*增加引用计数*/
                *top = snd_config;      /*最终返回结果*/
            }
        } else {
            err = -ENODEV;
        }
    }
    snd_config_unlock();
    return err;
}
```

##### 5.2 snd_pcm_open_noupdate

函数的目的是打开pcm设备，所要打开的具体设备需要依赖上面打开的设备树，
函数接受传入的设备名称，解析名称并在设备树中查找需要打开的设备，
如果配置中有使用插件，函数还需要解析插件，最终打开硬件设备。
注意`snd_pcm_open`函数最终返回的句柄`pcmp`其实就是此函数的返回的。

此函数会在后面文章继续分析。
```c
static int snd_pcm_open_noupdate(snd_pcm_t **pcmp, snd_config_t *root,
                 const char *name, snd_pcm_stream_t stream,
                 int mode, int hop)
{
    int err;
    snd_config_t *pcm_conf;
    const char *str;

    err = snd_config_search_definition(root, "pcm", name, &pcm_conf);
    if (err < 0) {
        SNDERR("Unknown PCM %s", name);
        return err;
    }
    if (snd_config_get_string(pcm_conf, &str) >= 0)
        err = snd_pcm_open_noupdate(pcmp, root, str, stream, mode,
                        hop + 1);
    else {
        snd_config_set_hop(pcm_conf, hop);
        err = snd_pcm_open_conf(pcmp, name, root, pcm_conf, stream, mode);
    }
    snd_config_delete(pcm_conf);
    return err;
}
```
