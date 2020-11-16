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

# 1. snd_config_hooks

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

    //在配置树中通过id寻找某个节点
    //见下文详细分析
    err = snd_config_search(config, "func", &c);
    if (err < 0) {
        SNDERR("Field func is missing");
        return err;
    }
    //功能及实现都很简单
    //返回string类型节点的string值
    //本质上就是直接把节点的值返回一下
    //见下文分析
    err = snd_config_get_string(c, &str);
    if (err < 0) {
        SNDERR("Invalid type for field func");
        return err;
    }
    assert(str);
    //配置树中查找"hook_func"节点
    //详细分析见下文
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
# 1.1 snd_config_search

在配置树中通过id查找一个子节点。id可以是一个或多个，中间以圆点(.)分隔。
如果是多个id的情况，则每个id需要依次指定前一级的复合节点。
比如在下面的配置树中，假设config是复合节点的句柄,
每个节点后的注释为找到这个节点需要用到的key
```bash
  config {
      a 42               # "a"
      b {                # "b"
          c "cee"        # "b.c"
          d {            # "b.d"
              e 2.71828  # "b.d.e"
          }
      }
  }
```
函数原型如下:
```c
int snd_config_search(snd_config_t *config, const char *key, snd_config_t **result)
{
    SND_CONFIG_SEARCH(config, key, result, );
}
```
实际主要是使用了`SND_CONFIG_SEARCH`宏，这类宏有多个，后面会对所有类型的宏都做详细的分析。

# 1.1.1 SND_CONFIG_SEARCH

此宏是相对来说最简单的宏，实现的目的比较单一，即通过Key查找节点。
其中主要调用了_snd_config_search函数，此函数在上一篇中已经分析过。
```c
#define SND_CONFIG_SEARCH(config, key, result, extra_code) \
{ \
    snd_config_t *n; \
    int err; \
    const char *p; \
    assert(config && key); \
    while (1) { \
        //如果不是复合节点直接报错。
        //这是因为传入的config本身即为父节点，如果不是复合节点则本身就不应该在一个单身节点下面查找子节点
        if (config->type != SND_CONFIG_TYPE_COMPOUND) \
            return -ENOENT; \
        //这里执行extra_code,这也是为什么宏中可以添加代码的原因。
        { extra_code ; } \
        //此函数返回key中第一次出现字符'.'的位置，如果每找到，则返回null
        p = strchr(key, '.'); \
        if (p) { \
            //如果找到,则返回(.)的位置,注意此处的p-key
            //由于返回的是.的位置，即.的地址，key为字符串最开头的地址
            //这样p-key即为字符串开始到.的字符的个数
            //于是搜索key字符串的前p-key个字符，则变成了搜索key字符串第一个点前的字符串
            //比如搜索a.b.c的话，此时相当于搜索a
            err = _snd_config_search(config, key, p - key, &n); \
            if (err < 0) \
                return err; \
            //注意这里，如果搜索到了返回n，则把n赋值为config,下个循环则从n开始搜索
            config = n; \
            //p+1的目的是跳过（.)，这里的1其实就是这个(.)
            //这样一来，在下个循环的时候，相当于从刚刚搜索到的节点开始，搜索(.)后面的内容
            key = p + 1; \
        } else \
            //如果没有(.)则传下来的key就是要搜索的内容
            return _snd_config_search(config, key, -1, result); \
    } \
}
```

# 1.2 snd_config_get_string

非常简单，返回string类型节点的string值。

```c
int snd_config_get_string(const snd_config_t *config, const char **ptr)
{
    assert(config && ptr);
    if (config->type != SND_CONFIG_TYPE_STRING)
        return -EINVAL;
    *ptr = config->u.string;
    return 0;
}
```

# 1.3 snd_config_search_definition

在配置树中查找节点，函数允许传入的参数为别名(alias),同时如果传入的参数为别名，函数会还把别名展开。
如果传入的名字中包含冒号(:),则冒号(:)后则为`snd_config_expand`展开所用的参数。

```c
int snd_config_search_definition(snd_config_t *config,
                 const char *base, const char *name,
                 snd_config_t **result)
{
    snd_config_t *conf;
    char *key;
    //查找":"
    //如果返回参数作为char*,则实际是找到的:的地址
    const char *args = strchr(name, ':');
    int err;
    if (args) {
        //如果找到了:,则自增1，目的是跳过:这个字符
        args++;
        //args - name则等于:前的字符长度+1,多出的1个字符刚好作为\0
        key = alloca(args - name);
        //注意这里需要把多出来的\0字符的位置减掉
        //实际刚好为:前的内容
        memcpy(key, name, args - name - 1);
        //最后的位置为\0
        key[args - name - 1] = '\0';
    } else {
        //找不到则直接就是key
        key = (char *) name;
    }
    /*
     *  if key contains dot (.), the implicit base is ignored
     *  and the key starts from root given by the 'config' parameter
     */
    snd_config_lock();
    //如果key中有(.),则传入的base会被忽略
    //否则如果没有找到(.)，说明没有指明base,则采用传入的base
    //函数查找子结点，如果传入的是别名(alias)则可以展开别名
    //详细见下文分析
    err = snd_config_search_alias_hooks(config, strchr(key, '.') ? NULL : base, key, &conf);
    if (err < 0) {
        snd_config_unlock();
        return err;
    }
    err = snd_config_expand(conf, config, args, NULL, result);
    snd_config_unlock();
    return err;
}
```

# 1.3.1 snd_config_search_alias_hooks

在配置树下使用别名及hooks查找节点。主要用来实现`snd_config_search_definition`的功能。
对别两个函数，`snd_config_search_definition`的第三个参数name可以包含':'，
如果有':'则':'后的内容为`snd_config_expand`的参数,而`snd_config_search_alias_hooks`的第三个参数更纯粹，
就是key,无法包含':'用于`snd_config_expand`。

```c
int snd_config_search_alias_hooks(snd_config_t *config,
                  const char *base, const char *key,
                  snd_config_t **result)
{
    SND_CONFIG_SEARCH_ALIAS(config, base, key, result,
                snd_config_searcha_hooks,
                snd_config_searchva_hooks);
}
```
这里出现了`SND_CONFIG_SEARCH_ALIAS`宏，与此类似的宏由多个，这些宏分别实现类似的功能，但是彼此之间有差异。
这些宏分析起来及其复杂，因为大部分都涉及到递归处理，以及相互嵌套。
这些函数中最基础的有两个，在此做介绍，其他类似的函数的函数只做功能说明.

# 1.3.2 snd_config_searcha

通过key在配置树中查找节点，展开别名。注意与1.1 snd_config_search的区别。
```bash
  config {
      a {
          b bb
      }
  }
  root {
      bb {
          c cc
      }
      cc ccc
      ccc {
          d {
              x "icks"
          }
      }
  }
```
在上面的配置树中，使用`snd_config_searcha(root, config, "a.b.c.d", &result);`则最终返回d节点。
```c
int snd_config_searcha(snd_config_t *root, snd_config_t *config, const char *key, snd_config_t **result)
{
    SND_CONFIG_SEARCHA(root, config, key, result, snd_config_searcha, );
}
```

# 1.3.2.1 SND_CONFIG_SEARCHA

此宏主要用来实现`snd_config_searcha`,使用key查找一个配置节点，同时在root下查找是否有别名并展开。
注意传入的fcn为调用者本身，意味着此处会有递归处理。

```c
#define SND_CONFIG_SEARCHA(root, config, key, result, fcn, extra_code) \
{ \
    snd_config_t *n; \
    int err; \
    const char *p; \
    assert(config && key); \
    while (1) { \
        //如果不是复合类型，通常意味着搜索结束或者错误
        if (config->type != SND_CONFIG_TYPE_COMPOUND) { \
            //获取string类型的字符串值
            if (snd_config_get_string(config, &p) < 0) \
                return -ENOENT; \
            //递归处理
            err = fcn(root, root, p, &config); \
            if (err < 0) \
                return err; \
        } \
        { extra_code ; } \
        //此处是查看key中是否有(.)
        p = strchr(key, '.'); \
        if (p) { \
            err = _snd_config_search(config, key, p - key, &n); \
            if (err < 0) \
                return err; \
            //把找到的n赋值给config,相当于从root逐步往下查找
            config = n; \
            key = p + 1; \
        } else \
            return _snd_config_search(config, key, -1, result); \
    } \
}
```

此类函数的功能，所使用的宏，以及主要作用总结在下表:


 | 函数名| 使用到的宏| 用到的函数 | 功能说明|
 | :- | :- | :- | :- |
 | snd_config_search | SND_CONFIG_SEARCH | \ |在配置树中根据key查找节点|
 | snd_config_searcha | SND_CONFIG_SEARCHA | snd_config_searcha | 在配置树中根据key查找节点，展开别名。别名从root下查找|
 | snd_config_searchv | SND_CONFIG_SEARCHV | snd_config_search | 在配置树中根据key查找节点；key可以是一系列的多个key|
 | snd_config_searchva | SND_CONFIG_SEARCHVA | snd_config_searcha | 在配置树中根据key查找节点，展开别名；key可以是连续多个key|
 | snd_config_search_alias | SND_CONFIG_SEARCH_ALIAS | snd_config_searcha <br> snd_config_searchva| 在配置树中根据key查找节点，展开别名.与snd_config_searcha类似，但是只能在config下查找。如果config下找不到id,则函数会尝试寻找base.id|
 | snd_config_search_hooks | SND_CONFIG_SEARCH | snd_config_hooks | 在配置树中根据key查找节点,并且展开hooks。与snd_config_search类似，但是搜索的任何包含hooks的节点都会被各自的hooks函数修改|
 | snd_config_searcha_hooks | SND_CONFIG_SEARCHA | snd_config_searcha_hooks <br> snd_config_hooks | 在配置树中根据key查找节点,并且展开alias与hooks|
 | snd_config_searchva_hooks | SND_CONFIG_SEARCHVA | snd_config_searcha_hooks | 在配置树中根据key查找节点,并且展开alias与hooks。与snd_config_searcha_hooks类似但是key可以是一系列的key|
 | snd_config_search_alias_hooks | SND_CONFIG_SEARCH_ALIAS |snd_config_searcha_hooks <br> snd_config_searchva_hooks |在配置树中根据key查找节点,并且展开alias与hooks。与snd_config_search_alias相似，并且展开hooks与snd_config_search_hooks相似|



# 1.3.2 snd_config_expand 

远远未结束,待续
