---
layout: post
title:  "ffmpeg从入门到放弃(二):编解码器是如何生效的"
date:   2021-10-07 17:01:00
categories: 总结
tags: ffmpeg 
excerpt: ffmpeg中的编码器是如何生效的，包括软件编码及硬件编解码器的原理
mathjax: true
---
* TOC
{:toc}
ffmpeg 编解码器介绍(ffmpeg 版本n4.5-dev)
### ffmpeg查找编解码器流程

ffmpeg中获取编解码器的函数主要是用`avcodec_find_encoder/decoder`,`avcodec_find_encoder/decoder_by_name`这几个函数，
我们以解码为例，来分析下是如何找到解码器的。先来分析`avcodec_find_decoder`函数。源码如下:
```c
AVCodec *avcodec_find_decoder(enum AVCodecID id)
{
    return find_codec(id, av_codec_is_decoder);
}

static AVCodec *find_codec(enum AVCodecID id, int (*x)(const AVCodec *))
{
    const AVCodec *p, *experimental = NULL;
    void *i = 0;

    id = remap_deprecated_codec_id(id);

    while ((p = av_codec_iterate(&i))) {
        if (!x(p))
            continue;
        if (p->id == id) {
            if (p->capabilities & AV_CODEC_CAP_EXPERIMENTAL && !experimental) {
                experimental = p;
            } else
                return (AVCodec*)p;
        }
    }

    return (AVCodec*)experimental;
}
```

这里的`find_codec`既可以用于解码器，也可以用于编码器，这里面的`remap_deprecated_codec_id`没有做任何工作，
只是为了以后如果有废弃的编码器可以用于重新映射。函数的整体思路是通过`av_codec_iterate`逐个查找所有的编解码器，
然后比较每个编解码器的ID是否与输入的id一致，直到找到与id一致的那个编解码器并返回。

至此用户便通过传入的AVCodecID得到了编解码器，那到底有哪些编解码器，或者说这些编解码器是哪里来的？继续来看`av_codec_iterate`函数:
```c
const AVCodec *av_codec_iterate(void **opaque)
{
    uintptr_t i = (uintptr_t)*opaque;
    const AVCodec *c = codec_list[i];

    ff_thread_once(&av_codec_static_init, av_codec_init_static);

    if (c)
        *opaque = (void*)(i + 1);

    return c;
}
```
其中的codec_list是个全局数组，所以获取编解码器仅仅是根据输入的索引值从这个大数组中返回一个编解码器，
这个codec_list又是来自于codec_list.c,而codec_list.c是在编译ffmpeg前执行`./configure`命令时configure脚本生成的。
之所以采用configure脚本生成，是因为很多编解码器是跟平台相关的，特别是硬件编解码器是与平台强相关的，
比如nvidia的硬件编解码器与amd的硬件编解码器肯定不一样，hisi的硬件变解码器跟RK的肯定不一样，
这些区别都是在编译前用户通过配置参数输入的，因为跟用户输入有关，所以codec_list是会变化的，
用configure脚本生成的方式会更方便。

### codec_list生成过程

codec_list.c中生成了codec_list[]这个大数组，其中的元素是预先使用`extern AVCodec ff_xxx_decoder`的格式在allcodecs.c文件声明好的，
但是决定哪些解码器真正的放入codec_list.c中则是由configure脚本决定的。configure脚本中有`CODEC_LIST`这个变量:
```bash
CODEC_LIST="
    $ENCODER_LIST
    $DECODER_LIST
"
```
只看解码器它是由`DECODER_LIST`来的，而`DECODER_LIST`又是来自于这条命令:
```bash
DECODER_LIST=$(find_things_extern decoder AVCodec libavcodec/allcodecs.c)
```
其中`find_things_extern`源码:
```bash
find_things_extern(){
    thing=$1
    pattern=$2
    file=$source_path/$3
    out=${4:-$thing}
    sed -n "s/^[^#]*extern.*$pattern *ff_\([^ ]*\)_$thing;/\1_$out/p" "$file"
}
```
这个函数的前三条命令很好理解不做解释，
第四行`out=${4:-$thing}`使用了bash的扩展表达式的这个语法[${parameter:-word}](https://www.gnu.org/software/bash/manual/bash.html):
```bash
${parameter:-word}
If parameter is unset or null, the expansion of word is substituted. Otherwise, the value of parameter is substituted.
```
在这里只传入了三个参数，所以4属于未设置的参数，所以out返回的是thing的内容，即decoder。接下来的一行使用了sed命令，
功能是取出libavcodec/allcodecs.c中所有开头不是`#`符号且满足`extern AVCodec ff_xxxx_decoder;`
格式的xxxx这个内容并添加上`_$out`即`_decoder`后输出。举例来说libavcodec/allcodecs.c中有`extern AVCodec ff_aasc_decoder;`则输出内容为`aasc_decoder`。
sed命令中`-n`为安静模式，只打印相关的那行,`^[^#]`表示开头但是排除#开头, `extern.`表示extern后至少有一个字符，
`ff_\([^ ]*\`表示ff_后面内容作为一个整体且不能为空，`\1_$out`中1表示前面`ff_\([^ ]*\`括号内的内容，最后的p为打印。

语法方面感兴趣可以参考[bash手册](https://www.gnu.org/software/bash/manual/bash.html)以及[sed手册](https://www.gnu.org/software/sed/manual/sed.html)。特别是sed那个，里面又用了正则表达式。

在获取到`CODEC_LIST`之后，又通过`print_enabled_components libavcodec/codec_list.c AVCodec codec_list $CODEC_LIST`这条命令把开启解码器写到codec_list.c中。
```bash
print_enabled_components(){
    file=$1
    struct_name=$2
    name=$3
    shift 3
    echo "static const $struct_name * const $name[] = {" > $TMPH
    for c in $*; do
        if enabled $c; then
            case $name in
                filter_list)
                    eval c=\$full_filter_name_${c%_filter}
                ;;
                indev_list)
                    c=${c%_indev}_demuxer
                ;;
                outdev_list)
                    c=${c%_outdev}_muxer
                ;;
            esac
            printf "    &ff_%s,\n" $c >> $TMPH
        fi
    done
    if [ "$name" = "filter_list" ]; then
        for c in asrc_abuffer vsrc_buffer asink_abuffer vsink_buffer; do
            printf "    &ff_%s,\n" $c >> $TMPH
        done
    fi
    echo "    NULL };" >> $TMPH
    cp_if_changed $TMPH $file
}
```
此处先写入一行`static const $struct_name * const $name[] = {`,之后对传入的每个参数做for循环，
在循环内逐个追加使能过的`&ff_%s,\n`到temp文件中，接着if判断跳过，最终追加`    NULL };`到temp文件。
最终生成了codec_list.c文件。感兴趣可以通过手动或开启某个解码器，看下生成的codec_list.c是否会有不同。

### 硬件编解码器的生效流程

我们以h264解码器为例，首先看下codec_list.c中h264解码器的结构体定义:
```c
AVCodec ff_h264_decoder = {
    .name                  = "h264",
    .long_name             = NULL_IF_CONFIG_SMALL("H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10"),
    .type                  = AVMEDIA_TYPE_VIDEO,
    .id                    = AV_CODEC_ID_H264,
    .priv_data_size        = sizeof(H264Context),
    .init                  = h264_decode_init,
    .close                 = h264_decode_end,
    .decode                = h264_decode_frame,
    .capabilities          = /*AV_CODEC_CAP_DRAW_HORIZ_BAND |*/ AV_CODEC_CAP_DR1 |
                             AV_CODEC_CAP_DELAY | AV_CODEC_CAP_SLICE_THREADS |
                             AV_CODEC_CAP_FRAME_THREADS,
    .hw_configs            = (const AVCodecHWConfigInternal *const []) {
#if CONFIG_H264_DXVA2_HWACCEL
                               HWACCEL_DXVA2(h264),
#endif
#if CONFIG_H264_D3D11VA_HWACCEL
                               HWACCEL_D3D11VA(h264),
#endif
#if CONFIG_H264_D3D11VA2_HWACCEL
                               HWACCEL_D3D11VA2(h264),
#endif
#if CONFIG_H264_NVDEC_HWACCEL
                               HWACCEL_NVDEC(h264),
#endif
#if CONFIG_H264_VAAPI_HWACCEL
                               HWACCEL_VAAPI(h264),
#endif
#if CONFIG_H264_VDPAU_HWACCEL
                               HWACCEL_VDPAU(h264),
#endif
#if CONFIG_H264_VIDEOTOOLBOX_HWACCEL
                               HWACCEL_VIDEOTOOLBOX(h264),
#endif
                               NULL
                           },
    .caps_internal         = FF_CODEC_CAP_INIT_THREADSAFE | FF_CODEC_CAP_EXPORTS_CROPPING |
                             FF_CODEC_CAP_ALLOCATE_PROGRESS | FF_CODEC_CAP_INIT_CLEANUP,
    .flush                 = h264_decode_flush,
    .update_thread_context = ONLY_IF_THREADS_ENABLED(ff_h264_update_thread_context),
    .profiles              = NULL_IF_CONFIG_SMALL(ff_h264_profiles),
    .priv_class            = &h264_class,
};
```
其中name及id字段是编解码器器的标识，之前介绍的`avcodec_find_encoder/decoder`,`avcodec_find_encoder/decoder_by_name`
函数就是通过这两个字段去匹配找到对应的编解码器的。decode字段为函数指针，默认情况下使用软解码。
hw_configs表明了支持的硬件加速方案，只不过configure脚本执行时若没有指定编解码器，hw_configs内的这些宏都是关闭的，
相当于AVCodecHWConfigInternal是个空数组。如果configure脚本执行时启用了对应的硬件解码器，则最终宏会变为开启状态，
用户就可以使用硬件解码器，这里以nvidia硬件解码来举例这个流程是如何生效的。

(未完待续）
