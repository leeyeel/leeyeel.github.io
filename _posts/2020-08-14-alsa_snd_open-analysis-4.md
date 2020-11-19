---
layout: post
title:  "linux alsa-lib snd_pcm_open函数源码分析（五)"
date:   2020-08-15 23:56:00
categories: 笔记心得
tags: audio linux alsa
excerpt: snd_pcm_open分析系列的第五篇，介绍snd_pcm_open_noupdate子函数
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
使用不同的插件，函数的执行流程也会不同，为了方便说明插件的使用流程同时又不至于太过复杂，
这里以一个非常简单的重采样插件为例，其他插件同理，只不过更多的递归与嵌套调用。

```bash
pcm.rate16k {
    type plug
        slave {
            pcm "hw:0,0"
            rate 16000
        }
}
```

# 1. snd_pcm_open_noupdate

此函数才是`snd_pcm_open`主要的执行函数，前半部分`snd_config_update_ref`其实主要是用来更新配置树，
在这部分中，根据配置的参数调用相应的函数，层层递进最终打开硬件设备。

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
    //获取string类型节点,由于上面配置文家没有string类型节点此处结果<0
    if (snd_config_get_string(pcm_conf, &str) >= 0)
        err = snd_pcm_open_noupdate(pcmp, root, str, stream, mode,
                        hop + 1);
    else {
        //只是进行了conf->hop = hop的设置,具体作用会在后面递归时用到，用作对递归层数的限制
        snd_config_set_hop(pcm_conf, hop);
        //这里是重要入口，打开配置文件,在打开配置文件过程中逐渐执行了所有的函数
        //详细见下文分析
        err = snd_pcm_open_conf(pcmp, name, root, pcm_conf, stream, mode);
    }
    snd_config_delete(pcm_conf);
    return err;
}
```
# 1.1. snd_pcm_open_conf

此函数是打开设备过程中最重要的函数入口，所有的插件系统都是从此处进入，
根据配置树中节点的类型拼接出函数符号，在动态库中查找到函数并调用。
打开的插件最终都会通过链表的形式链接起来，最终返回的pcmp即是所有设备链表的入口。

```c
static int snd_pcm_open_conf(snd_pcm_t **pcmp, const char *name,
                 snd_config_t *pcm_root, snd_config_t *pcm_conf,
                 snd_pcm_stream_t stream, int mode)
{
    const char *str;
    char *buf = NULL, *buf1 = NULL;
    int err;
    snd_config_t *conf, *type_conf = NULL, *tmp;
    snd_config_iterator_t i, next;
    const char *id;
    const char *lib = NULL, *open_name = NULL;
    //声明函数指针
    //这个地方用函数指针，是因为通过配置参数能查找到不同的函数
    int (*open_func)(snd_pcm_t **, const char *,
             snd_config_t *, snd_config_t *,
             snd_pcm_stream_t, int) = NULL;
#ifndef PIC
    extern void *snd_pcm_open_symbols(void);
#endif
    //判断是否是复合类型，通常第一次执行都是复合类型，
    //非复合类型比如浮点数，整数，字符串等
    if (snd_config_get_type(pcm_conf) != SND_CONFIG_TYPE_COMPOUND) {
        char *val;
        id = NULL;
        snd_config_get_id(pcm_conf, &id);
        val = NULL;
        snd_config_get_ascii(pcm_conf, &val);
        SNDERR("Invalid type for PCM %s%sdefinition (id: %s, value: %s)", name ? name : "", name ? " " : "", id, val);
        free(val);
        return -EINVAL;
    }
    //查找type,根据我们传入的配置参数，有type节点,值为plug
    err = snd_config_search(pcm_conf, "type", &conf);
    if (err < 0) {
        SNDERR("type is not defined");
        return err;
    }
    //id即是type
    err = snd_config_get_id(conf, &id);
    if (err < 0) {
        SNDERR("unable to get id");
        return err;
    }
    //获取type节点的字符串，即为plug
    err = snd_config_get_string(conf, &str);
    if (err < 0) {
        SNDERR("Invalid type for %s", id);
        return err;
    }
    //在pcm_root节点，也就是总配置树下查找base为pcm_type，名称为plug的节点
    //可见pcm_type也是alsa 插件的一种内置语法，实际搜索没有，此处err为负数错误码
    err = snd_config_search_definition(pcm_root, "pcm_type", str, &type_conf);
    if (err >= 0) {
        //顺便分析下如果找到了怎么处理
        //首先判断是否为复合类型，通常是复合类型
        if (snd_config_get_type(type_conf) != SND_CONFIG_TYPE_COMPOUND) {
            SNDERR("Invalid type for PCM type %s definition", str);
            err = -EINVAL;
            goto _err;
        }
        //然后遍历查找到的这个pcm_type节点
        //之所以获取id,comment,lib这些，是因为pcm_type节点的语法如下:
        //pcm_type.NAME {
        //  [lib STR]     # Library file (default libasound.so)
        //  [open STR]        # Open function (default _snd_pcm_NAME_open)
        //  [redirect {       # Redirect this PCM to an another
        //  [filename STR] # Configuration file specification
        //   name STR       # PCM name specification
        //  }]  
        //}
        snd_config_for_each(i, next, type_conf) {
            snd_config_t *n = snd_config_iterator_entry(i);
            const char *id;
            if (snd_config_get_id(n, &id) < 0)
                continue;
            if (strcmp(id, "comment") == 0)
                continue;
            if (strcmp(id, "lib") == 0) {
                err = snd_config_get_string(n, &lib);
                if (err < 0) {
                    SNDERR("Invalid type for %s", id);
                    goto _err;
                }
                continue;
            }
            if (strcmp(id, "open") == 0) {
                err = snd_config_get_string(n, &open_name);
                if (err < 0) {
                    SNDERR("Invalid type for %s", id);
                    goto _err;
                }
                continue;
            }
            SNDERR("Unknown field %s", id);
            err = -EINVAL;
            goto _err;
        }
    }
    //由于上面pcm_type找不到，此处open_name为null,进入分支
    if (!open_name) {
        //分配内存
        buf = malloc(strlen(str) + 32);
        if (buf == NULL) {
            err = -ENOMEM;
            goto _err;
        }
        open_name = buf;
        //此处根据传入的配置树中的参数生成不同的buf
        //本例中传入的str为plug，则此处buf即为 _snd_pcm_plug_open
        sprintf(buf, "_snd_pcm_%s_open", str);
    }
    //pcm_type为null时，lib自然为null
    if (!lib) {
        //build_in_pcms中保存着内置插件的名字，比如dmix,plug等,
        //它的具体定义在alsa-lib/src/pcm/pcm.c中
        const char *const *build_in = build_in_pcms;
        //此处循环的目的时判断输入的类型是否在内置的插件范围中
        while (*build_in) {
            if (!strcmp(*build_in, str))
                break;
            build_in++;
        }
        //build_in的最后一个元素为NULL,若执行到此，说明不再内置插件中
        if (*build_in == NULL) {
            //分配字符串的内存空间
            buf1 = malloc(strlen(str) + sizeof(ALSA_PLUGIN_DIR) + 32);
            if (buf1 == NULL) {
                err = -ENOMEM;
                goto _err;
            }
            lib = buf1;
            //从这段代码可以发现，
            //若不是内置插件时，用户应把动态库以这种规则命名并放置到ALSA_PLUGIN_DIR目录下
            //命名应该以libasound_module_pcm_%s.so的格式
            sprintf(buf1, "%s/libasound_module_pcm_%s.so", ALSA_PLUGIN_DIR, str);
        }
    }
#ifndef PIC
    snd_pcm_open_symbols(); /* this call is for static linking only */
#endif
    //打开动态库，最终根据名字返回函数
    //具体实现见下文
    //此处传入的名字为_snd_pcm_plug_open,最终返回的就是_snd_pcm_plug_open,
    open_func = snd_dlobj_cache_get(lib, open_name,
            SND_DLSYM_VERSION(SND_PCM_DLSYM_VERSION), 1);
    if (open_func) {
        //执行_snd_pcm_plug_open,
        //详细见下文分析
        err = open_func(pcmp, name, pcm_root, pcm_conf, stream, mode);
        if (err >= 0) {
            if ((*pcmp)->open_func) {
                /* only init plugin (like empty, asym) */
                //放入链表中，下次可直接从链表获取
                snd_dlobj_cache_put(open_func);
            } else {
                (*pcmp)->open_func = open_func;
            }
            err = 0;
        } else {
            snd_dlobj_cache_put(open_func);
        }
    } else {
        err = -ENXIO;
    }
    if (err >= 0) {
        //查找其他节点,对本例来说这些统统找不到
        err = snd_config_search(pcm_root, "defaults.pcm.compat", &tmp);
        if (err >= 0) {
            long i;
            if (snd_config_get_integer(tmp, &i) >= 0) {
                if (i > 0)
                    (*pcmp)->compat = 1;
            }
        } else {
            char *str = getenv("LIBASOUND_COMPAT");
            if (str && *str)
                (*pcmp)->compat = 1;
        }
        err = snd_config_search(pcm_root, "defaults.pcm.minperiodtime", &tmp);
        if (err >= 0)
            snd_config_get_integer(tmp, &(*pcmp)->minperiodtime);
        err = 0;
    }
       _err:
    if (type_conf)
        snd_config_delete(type_conf);
    free(buf);
    free(buf1);
    return err;
}
```

# 1.2 snd_dlobj_cache_get

从动态库中查找函数，并把查找到的函数添加到链表中。

```c
void *snd_dlobj_cache_get(const char *lib, const char *name,
              const char *version, int verbose)
{
    struct list_head *p;
    struct dlobj_cache *c;
    void *func, *dlobj;

    snd_dlobj_lock();
    list_for_each(p, &pcm_dlobj_list) {
        c = list_entry(p, struct dlobj_cache, list);
        //查看链表中是否有与要查找的库名字一致的库
        if (c->lib && lib && strcmp(c->lib, lib) != 0)
            continue;
        if (!c->lib && lib)
            continue;
        if (!lib && c->lib)
            continue;
        //查看链表中是否有与要查找的函数名字一致的函数
        //如果找到则直接返回函数指针
        if (strcmp(c->name, name) == 0) {
            c->refcnt++;
            func = c->func;
            snd_dlobj_unlock();
            return func;
        }
    }
    //打开动态库，本质是对C库函数dlopen的包装
    //分析见下文
    dlobj = snd_dlopen(lib, RTLD_NOW);
    if (dlobj == NULL) {
        if (verbose)
            SNDERR("Cannot open shared library %s",
                        lib ? lib : "[builtin]");
        snd_dlobj_unlock();
        return NULL;
    }
    //在上面的动态库中查找符号，返回函数
    //本质是对c库函数dlsym的包装，详细分析见下文
    func = snd_dlsym(dlobj, name, version);
    if (func == NULL) {
      if (verbose)
            SNDERR("symbol %s is not defined inside %s",
                    name, lib ? lib : "[builtin]");
        goto __err;
    }
    c = malloc(sizeof(*c));
    if (! c)
        goto __err;
    c->refcnt = 1;
    c->lib = lib ? strdup(lib) : NULL;
    c->name = strdup(name);
    if ((lib && ! c->lib) || ! c->name) {
        free((void *)c->name);
        free((void *)c->lib);
        free(c);
          __err:
        snd_dlclose(dlobj);
        snd_dlobj_unlock();
        return NULL;
    }
    c->dlobj = dlobj;
    c->func = func;
    //加入链表,方便下次查找时不需要再打开动态库，直接从链表中找到
    list_add_tail(&c->list, &pcm_dlobj_list);
    snd_dlobj_unlock();
    //最终返回的是函数指针
    return func;
}
```
# 1.2.1 snd_dlopen 

对c库函数dlopen的包装，用于打开某个动态库

```c
void *snd_dlopen(const char *name, int mode)
{
#ifndef PIC //不走此分支
    if (name == NULL)
        return &snd_dlsym_start;
#else
#ifdef HAVE_LIBDL
    if (name == NULL) {
        static const char * self = NULL;
        if (self == NULL) {
            Dl_info dlinfo;
            //此处获取当前函数的信息，
            //这时认为要查找的库跟当前函数在一个库中
            if (dladdr(snd_dlopen, &dlinfo) > 0)
                //默认情况下self = "/usr/lib64/libasound.so.2"
                self = dlinfo.dli_fname;
        }
        name = self;
    }
#endif
#endif
#ifdef HAVE_LIBDL
    /*
     * Handle the plugin dir not being on the default dlopen search
     * path, without resorting to polluting the entire system namespace
     * via ld.so.conf.
     */
    //handle为null
    void *handle = NULL;
    char *filename;

    if (name && name[0] != '/') {
        //名字当中第一个字符不是'/',则认为是相对路径
        //一通操作把相对路径转换为绝对路径
        filename = malloc(sizeof(ALSA_PLUGIN_DIR) + 1 + strlen(name) + 1);
        strcpy(filename, ALSA_PLUGIN_DIR);
        strcat(filename, "/");
        strcat(filename, name);
        handle = dlopen(filename, mode);
        free(filename);
    }
    if (!handle)
        //最终通过C库的dlopen打开动态库
        handle = dlopen(name, mode);
    return handle;
#else
    return NULL;
#endif
}
```

# 1.2.2 snd_dlsym

对C库dlsym的包装，根据符号查找函数

```c
void *snd_dlsym(void *handle, const char *name, const char *version)
{
    int err;

#ifndef PIC
    if (handle == &snd_dlsym_start) {
        /* it's the funny part: */
        /* we are looking for a symbol in a static library */
        struct snd_dlsym_link *link = snd_dlsym_start;
        while (link) {
            if (!strcmp(name, link->dlsym_name))
                return (void *)link->dlsym_ptr;
            link = link->next;
        }
        return NULL;
    }
#endif
#ifdef HAVE_LIBDL
#ifdef VERSIONED_SYMBOLS
    //如果定义了版本要验证版本
    if (version) {
        err = snd_dlsym_verify(handle, name, version);
        if (err < 0)
            return NULL;
    }
#endif
    //最终通过dlsym返回函数句柄
    return dlsym(handle, name);
#else
    return NULL;
#endif
}
```
函数通过配置文件拼接并查找到_snd_pcm_plug_open函数，之后执行，
看似一个普通的函数执行，实际是个非常重要的函数入口，从此打开的alsa的插件系统。
露出了插件系统的冰山一角。

后续的文章会继续对插件的加载做详细分析

