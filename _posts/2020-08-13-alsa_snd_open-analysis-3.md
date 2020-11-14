---
layout: post
title:  "linux alsa-lib snd_pcm_open源代码详细分析（三)"
date:   2020-08-13 00:56:00
categories: 笔记心得
tags: audio linux alsa
excerpt: snd_pcm_open源码分析的第三篇，对子函数snd_config_update_ref的分析，其中主要是对snd_config_update_ref的子函数snd_config_hooks函数的分析。
mathjax: true
---
* TOC
{:toc}

解析配置的最后一个复杂函数子函数

# 1.snd_config_hooks

核心函数之一，配置hooks功能，其中使用hooks功能加载并解析了配置文件中引用的其他配置文件。
所谓的其他配置文件通常为"/etc/asound.conf"及"~/.asoundrc"，也就是用户经常自定义修改的配置文件。

```c
static int snd_config_hooks_call(snd_config_t *root, snd_config_t *config, snd_config_t *private_data)
{
    void *h = NULL;
    snd_config_t *c, *func_conf = NULL;
    char *buf = NULL;
    const char *lib = NULL, *func_name = NULL;
    const char *str;
    int (*func)(snd_config_t *root, snd_config_t *config, snd_config_t **dst, snd_config_t *private_data) = NULL;
    int err;

    err = snd_config_search(config, "func", &c);
    if (err < 0) {
        SNDERR("Field func is missing");
        return err;
    }
    err = snd_config_get_string(c, &str);
    if (err < 0) {
        SNDERR("Invalid type for field func");
        return err;
    }
    assert(str);
    err = snd_config_search_definition(root, "hook_func", str, &func_conf);
    if (err >= 0) {
        snd_config_iterator_t i, next;
        if (snd_config_get_type(func_conf) != SND_CONFIG_TYPE_COMPOUND) {
            SNDERR("Invalid type for func %s definition", str);
            err = -EINVAL;
            goto _err;
        }
        snd_config_for_each(i, next, func_conf) {
            snd_config_t *n = snd_config_iterator_entry(i);
            const char *id = n->id;
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
            if (strcmp(id, "func") == 0) {
                err = snd_config_get_string(n, &func_name);
                if (err < 0) {
                    SNDERR("Invalid type for %s", id);
                    goto _err;
                }
                continue;
            }
            SNDERR("Unknown field %s", id);
        }
    }
    if (!func_name) {
        int len = 16 + strlen(str) + 1;
        buf = malloc(len);
        if (! buf) {
            err = -ENOMEM;
            goto _err;
        }
        snprintf(buf, len, "snd_config_hook_%s", str);
        buf[len-1] = '\0';
        func_name = buf;
    }
    h = snd_dlopen(lib, RTLD_NOW);
    func = h ? snd_dlsym(h, func_name, SND_DLSYM_VERSION(SND_CONFIG_DLSYM_VERSION_HOOK)) : NULL;
    err = 0;
    if (!h) {
        SNDERR("Cannot open shared library %s", lib);
        err = -ENOENT;
    } else if (!func) {
        SNDERR("symbol %s is not defined inside %s", func_name, lib);
        snd_dlclose(h);
        err = -ENXIO;
    }
    _err:
    if (func_conf)
        snd_config_delete(func_conf);
    if (err >= 0) {
        snd_config_t *nroot;
        err = func(root, config, &nroot, private_data);
        if (err < 0)
            SNDERR("function %s returned error: %s", func_name, snd_strerror(err));
        snd_dlclose(h);
        if (err >= 0 && nroot)
            err = snd_config_substitute(root, nroot);
    }
    free(buf);
    if (err < 0)
        return err;
    return 0;
}
```

未完待续
