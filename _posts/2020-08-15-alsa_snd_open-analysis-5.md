---
layout: post
title:  "linux alsa-lib snd_pcm_open函数源码分析（五)"
date:   2020-08-15 00:56:00
categories: 音视频 
tags: alsa 驱动 音频
excerpt: snd_pcm_open分析系列的第五篇，介绍alsa的插件系统是如何被调用的
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
# 1 _snd_pcm_plug_open

创建一个新的plug,
重要入口函数，打开插件，注意函数前的'_'前缀，表示是真正打开plug的前戏。
看似一个简单的函数，其实只是冰山一角。

```c
int _snd_pcm_plug_open(snd_pcm_t **pcmp, const char *name,
               snd_config_t *root, snd_config_t *conf,
               snd_pcm_stream_t stream, int mode)
{
    snd_config_iterator_t i, next;
    int err;
    snd_pcm_t *spcm;
    snd_config_t *slave = NULL, *sconf;
    snd_config_t *tt = NULL;
    enum snd_pcm_plug_route_policy route_policy = PLUG_ROUTE_POLICY_DEFAULT;
    snd_pcm_route_ttable_entry_t *ttable = NULL;
    unsigned int csize, ssize;
    unsigned int cused, sused;
    snd_pcm_format_t sformat = SND_PCM_FORMAT_UNKNOWN;
    int schannels = -1, srate = -1;
    const snd_config_t *rate_converter = NULL;

    //对conf进行遍历，注意这里的conf为查找到plug的节点
    snd_config_for_each(i, next, conf) {
        snd_config_t *n = snd_config_iterator_entry(i);
        const char *id;
        //获取id
        if (snd_config_get_id(n, &id) < 0)
            continue;
        //此函数实际是个宏，实现也很简单
        //函数的目的是id是否是属于"comment", "type", "hint"这三个中的一个
        //如果是这三个中的一个，则返回ture,否则返回0
        if (snd_pcm_conf_generic_id(id))
            continue;
        //找到plug子节点id是否为slave,如果是则找到的为slave子节点
        //根据我们的配置文件，slave是有的
        //所以此处找到slave
        if (strcmp(id, "slave") == 0) {
            slave = n;
            continue;
        }
#ifdef BUILD_PCM_PLUGIN_ROUTE
        //我们的配置文件中没有ttable，ttable的具体含义会在下文中说明
        if (strcmp(id, "ttable") == 0) {
            route_policy = PLUG_ROUTE_POLICY_NONE;
            if (snd_config_get_type(n) != SND_CONFIG_TYPE_COMPOUND) {
                SNDERR("Invalid type for %s", id);
                return -EINVAL;
            }
            tt = n;
            continue;
        }
        //我们的配置文件中没有route_policy，具体含义会在下文中说明
        if (strcmp(id, "route_policy") == 0) {
            const char *str;
            if ((err = snd_config_get_string(n, &str)) < 0) {
                SNDERR("Invalid type for %s", id);
                return -EINVAL;
            }
            if (tt != NULL)
                SNDERR("Table is defined, route policy is ignored");
            if (!strcmp(str, "default"))
                route_policy = PLUG_ROUTE_POLICY_DEFAULT;
            else if (!strcmp(str, "average"))
                route_policy = PLUG_ROUTE_POLICY_AVERAGE;
            else if (!strcmp(str, "copy"))
                route_policy = PLUG_ROUTE_POLICY_COPY;
            else if (!strcmp(str, "duplicate"))
                route_policy = PLUG_ROUTE_POLICY_DUP;
            continue;
        }
#endif
#ifdef BUILD_PCM_PLUGIN_RATE
        //我们的配置文件没有rate_converter，具体含义会在下文中说明
        if (strcmp(id, "rate_converter") == 0) {
            rate_converter = n;
            continue;
        }
#endif
        SNDERR("Unknown field %s", id);
        return -EINVAL;
    }
    //最终跳出遍历，此时找到slave
    if (!slave) {
        SNDERR("slave is not defined");
        return -EINVAL;
    }
    //读取slave节点的配置，第三个参数为出参,即读取到的slave节点信息
    //此函数是个不定参数的函数，第四个参数为参数组的个数，每个参数组又有三个参数
    //此函数通过读取slave节点并解析，返回slave节点的信息比如格式，采样率，或者通道数等信息
    //详细见下文分析
    err = snd_pcm_slave_conf(root, slave, &sconf, 3,
                 SND_PCM_HW_PARAM_FORMAT, SCONF_UNCHANGED, &sformat,
                 SND_PCM_HW_PARAM_CHANNELS, SCONF_UNCHANGED, &schannels,
                 SND_PCM_HW_PARAM_RATE, SCONF_UNCHANGED, &srate);
    if (err < 0)
        return err;
#ifdef BUILD_PCM_PLUGIN_ROUTE
    //由于没有ttable,所以此处tt为null,分支内是对于tttable的处理
    if (tt) {
        err = snd_pcm_route_determine_ttable(tt, &csize, &ssize);
        if (err < 0) {
            snd_config_delete(sconf);
            return err;
        }
        ttable = malloc(csize * ssize * sizeof(*ttable));
        if (ttable == NULL) {
            snd_config_delete(sconf);
            return err;
        }
        err = snd_pcm_route_load_ttable(tt, ttable, csize, ssize, &cused, &sused, -1);
        if (err < 0) {
            snd_config_delete(sconf);
            return err;
        }
    }
#endif
#ifdef BUILD_PCM_PLUGIN_RATE
    //由于没有定义rate_converter，所以此处的值为null,会进入分支
    if (! rate_converter)
        //此时会返回默认的converter
        //用户需要在配置文件中配置默认的converter插件
        //函数会搜索‘defaults.pcm.rate_converter’这个节点
        //如果找不到，则返回null
        //见下文分析
        rate_converter = snd_pcm_rate_get_default_converter(root);
#endif

    //这里打开slave
    //又是一个非常重要的函数入口
    //注意这里的第一个参数，返回的实际是slave_pcm,
    //详细见下文分析
    err = snd_pcm_open_slave(&spcm, root, sconf, stream, mode, conf);
    snd_config_delete(sconf);
    if (err < 0)
        return err;
    err = snd_pcm_plug_open(pcmp, name, sformat, schannels, srate, rate_converter,
                route_policy, ttable, ssize, cused, sused, spcm, 1);
    if (err < 0)
        snd_pcm_close(spcm);
    return err;
}
```

# 1.1 snd_pcm_slave_conf

解析slave节点，并返回读取到的信息

```c
int snd_pcm_slave_conf(snd_config_t *root, snd_config_t *conf,
               snd_config_t **_pcm_conf, unsigned int count, ...)
{
    snd_config_iterator_t i, next;
    const char *str;
    //每个count对应四个字段，其中最后一个是函数自己控制
    struct {
        unsigned int index;
        int flags;
        void *ptr;
        int present;
    } fields[count];
    unsigned int k;
    snd_config_t *pcm_conf = NULL;
    int err;
    int to_free = 0;
    va_list args;
    assert(root);
    assert(conf);
    assert(_pcm_conf);
    //获取string类型节点的字符串,我们配置文件中没有
    if (snd_config_get_string(conf, &str) >= 0) {
        //查找pcm_slave,我们配置文件中没有
        err = snd_config_search_definition(root, "pcm_slave", str, &conf);
        if (err < 0) {
            SNDERR("Invalid slave definition");
            return -EINVAL;
        }
        to_free = 1;
    }
    //是复合节点
    if (snd_config_get_type(conf) != SND_CONFIG_TYPE_COMPOUND) {
        SNDERR("Invalid slave definition");
        err = -EINVAL;
        goto _err;
    }
    va_start(args, count);
    //解析传入的参数
    for (k = 0; k < count; ++k) {
        fields[k].index = va_arg(args, int);
        fields[k].flags = va_arg(args, int);
        fields[k].ptr = va_arg(args, void *);
        fields[k].present = 0;
    }
    va_end(args);
    snd_config_for_each(i, next, conf) {
        snd_config_t *n = snd_config_iterator_entry(i);
        const char *id;
        if (snd_config_get_id(n, &id) < 0)
            continue;
        //没有comment
        if (strcmp(id, "comment") == 0)
            continue;
        //这个有
        if (strcmp(id, "pcm") == 0) {
            if (pcm_conf != NULL)
                snd_config_delete(pcm_conf);
            //拷贝到pcm_conf
            if ((err = snd_config_copy(&pcm_conf, n)) < 0)
                goto _err;
            continue;
        }
        for (k = 0; k < count; ++k) {
            //这里idx即是传入参数，即每组参数的第一个
            //具体到传入的参数
            //则第一组为SND_PCM_HW_PARAM_FORMAT, SCONF_UNCHANGED, &sformat,
            //idx为SND_PCM_HW_PARAM_FORMAT
            //name 为静态数组
            //static const char *const names[SND_PCM_HW_PARAM_LAST_INTERVAL + 1] = {
            //  [SND_PCM_HW_PARAM_FORMAT] = "format",
            //  [SND_PCM_HW_PARAM_CHANNELS] = "channels",
            //  [SND_PCM_HW_PARAM_RATE] = "rate",
            //  [SND_PCM_HW_PARAM_PERIOD_TIME] = "period_time",
            //  [SND_PCM_HW_PARAM_PERIOD_SIZE] = "period_size",
            //  [SND_PCM_HW_PARAM_BUFFER_TIME] = "buffer_time",
            //  [SND_PCM_HW_PARAM_BUFFER_SIZE] = "buffer_size",
            //  [SND_PCM_HW_PARAM_PERIODS] = "periods"
            //};
            //name[idx]实际返回的为字符串

            unsigned int idx = fields[k].index;
            long v;
            assert(idx < SND_PCM_HW_PARAM_LAST_INTERVAL);
            assert(names[idx]);
            //获取到的字符串与idx对应的字符串对比
            if (strcmp(id, names[idx]) != 0)
                continue;
            switch (idx) {
            case SND_PCM_HW_PARAM_FORMAT:
            {
                snd_pcm_format_t f;
                //比如此时id为format,则获取到的字符串str为format对应的值
                err = snd_config_get_string(n, &str);
                if (err < 0) {
                _invalid:
                    SNDERR("invalid type for %s", id);
                    goto _err;
                }
                if ((fields[k].flags & SCONF_UNCHANGED) &&
                    strcasecmp(str, "unchanged") == 0) {
                    *(snd_pcm_format_t*)fields[k].ptr = (snd_pcm_format_t) -2;
                    break;
                }
                //从字符串返回一个对应的枚举量
                f = snd_pcm_format_value(str);
                if (f == SND_PCM_FORMAT_UNKNOWN) {
                    SNDERR("unknown format %s", str);
                    err = -EINVAL;
                    goto _err;
                }
                *(snd_pcm_format_t*)fields[k].ptr = f;
                break;
            }
            default:
                if ((fields[k].flags & SCONF_UNCHANGED)) {
                    err = snd_config_get_string(n, &str);
                    if (err >= 0 &&
                        strcasecmp(str, "unchanged") == 0) {
                        *(int*)fields[k].ptr = -2;
                        break;
                    }
                }
                //获取整数值，比如channel或者rate为整数
                err = snd_config_get_integer(n, &v);
                if (err < 0)
                    goto _invalid;
                *(int*)fields[k].ptr = v;
                break;
            }
            fields[k].present = 1;
            break;
        }
        if (k < count)
            continue;
        SNDERR("Unknown field %s", id);
        err = -EINVAL;
        goto _err;
    }
    if (!pcm_conf) {
        SNDERR("missing field pcm");
        err = -EINVAL;
        goto _err;
    }
    for (k = 0; k < count; ++k) {
        if ((fields[k].flags & SCONF_MANDATORY) && !fields[k].present) {
            SNDERR("missing field %s", names[fields[k].index]);
            err = -EINVAL;
            goto _err;
        }
    }
    //返回节点信息
    *_pcm_conf = pcm_conf;
    pcm_conf = NULL;
    err = 0;
 _err:
    if (pcm_conf)
        snd_config_delete(pcm_conf);
    if (to_free)
        snd_config_delete(conf);
    return err;
}
```
# 1.2 snd_pcm_rate_get_default_converter

打开默认的converter,实际就是从设备树中查找'defaults.pcm.rate_converter'节点，
找不到则返回null

```c
const snd_config_t *snd_pcm_rate_get_default_converter(snd_config_t *root)
{
    snd_config_t *n;
    /* look for default definition */
    //search函数前面已经分析过
    if (snd_config_search(root, "defaults.pcm.rate_converter", &n) >= 0)
        return n;
    return NULL;
}
```
# 1.3 snd_pcm_open_slave

非常重要的函数入口，打开从设备，从设备可能还有从设备，我们的配置比较简单，
从设备直接为hw硬件设备，所以比较快的可以分析到打开硬件设备。

如果从设备还是其他插件，则需要使用递归武器层层递归，并且每次从设备打开的插件还不一样，
分析会更加复杂，这也是我们只采用了一个插件的原因。
```c
static inline int
snd_pcm_open_slave(snd_pcm_t **pcmp, snd_config_t *root,
           snd_config_t *conf, snd_pcm_stream_t stream,
           int mode, snd_config_t *parent_conf)
{
    return snd_pcm_open_named_slave(pcmp, NULL, root, conf, stream,
                    mode, parent_conf);
}
```
# 1.3.1 snd_pcm_open_named_slave

打开‘named'从设备,snd_pcm_open_named_slave其实是个宏，运行是会被替换为snd1_pcm_open_named_slave。
函数在这里检查hop,不能大于SND_CONF_MAX_HOPS,本质是对递归层数的限制

这里由于我们传入的配置文件中，plug下面的slave即为hw设备，
所以在执行一次`snd_pcm_open_named_slave`后即可通过`snd_pcm_open_conf`函数找到hw设备并打开，
如果使用了多个插件，也就是说slave设备不是hw设备，则在`snd_pcm_open_conf`的过程中会再次解析并打开新的插件，
直到最后到达hw设备,此时从递归的`snd_pcm_open_conf`中返回。

注意这里的pcmp参数，实际最终返回的是slave设备的handle,在本例配置中就是hw设备的handle,
执行过程中，`snd_pcm_open_conf`会先查找符号`_snd_pcm_hw_open',再执行`snd_pcm_hw_open`函数真正打开硬件设备，
即给最终的slave设备的结构体赋值。

```c
int snd_pcm_open_named_slave(snd_pcm_t **pcmp, const char *name,
                 snd_config_t *root,
                 snd_config_t *conf, snd_pcm_stream_t stream,
                 int mode, snd_config_t *parent_conf)
{
    const char *str;
    int hop;

    if ((hop = snd_config_check_hop(parent_conf)) < 0)
        return hop;
    //通常由于是复合类型，这里不会获取到string,但是如果到hw从设备，则会获取到str
    if (snd_config_get_string(conf, &str) >= 0)
        return snd_pcm_open_noupdate(pcmp, root, str, stream, mode,
                         hop + 1);
    //如果不是hw设备，则会根据配置参数再次进入解析配置，根据配置查找函数，执行函数的流程
    //详细前上一篇对此函数的详细分析，本质上是递归执行，直到打开硬件设备
    //此处传入的name为NULL,在`snd_pcm_open_conf`中回去读取字符串，获取到字符串为hw
    //在函数内部拼接出_snd_pcm_hw_open并执行，最终打开硬件设备
    return snd_pcm_open_conf(pcmp, name, root, conf, stream, mode);
}
```
# 1.4 snd_pcm_plug_open

真正的打开plug PCM设备,给plug设备的snd_pcm_t结构体赋值。
这里pcmp的返回值就是最终`snd_pcm_open`返回的设备handle。

注意传入的倒数第二个参数slave,实际为上一步`snd_pcm_open_slave`返回的slave设备。

```c
int snd_pcm_plug_open(snd_pcm_t **pcmp,
              const char *name,
              snd_pcm_format_t sformat, int schannels, int srate,
              const snd_config_t *rate_converter,
              enum snd_pcm_plug_route_policy route_policy,
              snd_pcm_route_ttable_entry_t *ttable,
              unsigned int tt_ssize,
              unsigned int tt_cused, unsigned int tt_sused,
              snd_pcm_t *slave, int close_slave)
{
    snd_pcm_t *pcm;
    snd_pcm_plug_t *plug;
    int err;
    assert(pcmp && slave);

    plug = calloc(1, sizeof(snd_pcm_plug_t));
    if (!plug)
        return -ENOMEM;
    plug->sformat = sformat;
    plug->schannels = schannels;
    plug->srate = srate;
    //注意这里的slave的赋值，为`snd_pcm_open_slave`返回的slave设备,
    //通过这种方法，最终返回的设备handle中，可以依次找到所有的slave设备
    plug->gen.slave = plug->req_slave = slave;
    plug->gen.close_slave = close_slave;
    plug->route_policy = route_policy;
    plug->ttable = ttable;
    plug->tt_ssize = tt_ssize;
    plug->tt_cused = tt_cused;
    plug->tt_sused = tt_sused;

    //分配pcm内存，创建最终返回的句柄
    //详见下文分析
    err = snd_pcm_new(&pcm, SND_PCM_TYPE_PLUG, name, slave->stream, slave->mode);
    if (err < 0) {
        free(plug);
        return err;
    }
    //注意此处的两个ops,实际为最终snd_pcm_open返回的handle的操作函数
    pcm->ops = &snd_pcm_plug_ops;
    //特别注意此处的fast_ops,实际为slave传进的fast_ops;所以具体传入的是什么值
    //还需要具体分析在递归时打开slave设备中的执行过程
    //此过程后续可单独写一篇文章详细分析
    pcm->fast_ops = slave->fast_ops;
    pcm->fast_op_arg = slave->fast_op_arg;
    if (rate_converter) {
        err = snd_config_copy(&plug->rate_converter,
                      (snd_config_t *)rate_converter);
        if (err < 0) {
            snd_pcm_free(pcm);
            free(plug);
            return err;
        }
    }
    pcm->private_data = plug;
    pcm->poll_fd = slave->poll_fd;
    pcm->poll_events = slave->poll_events;
    pcm->mmap_shadow = 1;
    pcm->tstamp_type = slave->tstamp_type;
    snd_pcm_link_hw_ptr(pcm, slave);
    snd_pcm_link_appl_ptr(pcm, slave);
    *pcmp = pcm;

    return 0;
}
```
# 1.4.1 snd_pcm_new

创建一个新的pcm设备。由于在此分配内存，所以无论是slave还是主设备，最终都要调到此函数，
但是传入的参数不同，使得有些创建出来的pcm设备其实是从设备.

```c
#ifndef DOC_HIDDEN
int snd_pcm_new(snd_pcm_t **pcmp, snd_pcm_type_t type, const char *name,
        snd_pcm_stream_t stream, int mode)
{
    snd_pcm_t *pcm;
#ifdef THREAD_SAFE_API
    pthread_mutexattr_t attr;
#endif
    //分配内存，给各个成员变量赋值
    pcm = calloc(1, sizeof(*pcm));
    if (!pcm)
        return -ENOMEM;
    pcm->type = type;
    if (name)
        pcm->name = strdup(name);
    pcm->stream = stream;
    pcm->mode = mode;
    pcm->poll_fd_count = 1;
    pcm->poll_fd = -1;
    pcm->op_arg = pcm;
    pcm->fast_op_arg = pcm;
    INIT_LIST_HEAD(&pcm->async_handlers);
#ifdef THREAD_SAFE_API
    pthread_mutexattr_init(&attr);
#ifdef HAVE_PTHREAD_MUTEX_RECURSIVE
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
#endif
    pthread_mutex_init(&pcm->lock, &attr);
    /* use locking as default;
     * each plugin may suppress this in its open call
     */
    pcm->need_lock = 1;
    if (mode & SND_PCM_ASYNC) {
        /* async handler may lead to a deadlock; suppose no MT */
        pcm->lock_enabled = 0;
    } else {
        /* set lock_enabled field depending on $LIBASOUND_THREAD_SAFE */
        static int do_lock_enable = -1; /* uninitialized */

        /* evaluate env var only once at the first open for consistency */
        if (do_lock_enable == -1) {
            char *p = getenv("LIBASOUND_THREAD_SAFE");
            do_lock_enable = !p || *p != '0';
        }
        pcm->lock_enabled = do_lock_enable;
    }
#endif
    *pcmp = pcm;
    return 0;
}
```

# 2. _snd_pcm_plug_open总结

通过上面零散的分析，插件的打开过程大概可以总结如下:

首先根据配置参数拼接符号，根据拼接出来的符号去查找函数，第一个拼接出来的函数为`_snd_pcm_plug_open`，
在此函数中，会继续解析配置文件，打开配置文件中配置的slave设备。在我们当前的配置例子中，
slave设备即为hw设备，返回hw设备的句柄，并把这个句柄作为参数传入`snd_pcm_plug_open`,在`snd_pcm_plug_open`函数中，
去真正的创建一个plug的pcm设备，同时原先传入的slave的句柄也会被保留。

对于有多个插件的配置，情况要复杂的多，在打开slave设备的过程中，需要通过递归去分析配置文件，逐个打开slave设备，
所有打开的插件pcm设备都会得到保留，并最终通过函数指针串联起来。

后面文章会详细分析slave设备被打开的过程，以此更清楚slave设备时如何被连接起来的。
