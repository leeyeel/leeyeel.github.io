---
layout: post
title:  "linux alsa-lib snd_pcm_open函数源码分析（三)"
date:   2020-08-13 00:56:00
categories: 笔记心得
tags: audio linux alsa
excerpt: snd_pcm_open源码分析的第三篇，对子函数snd_config_update_ref的分析，其中主要是对snd_config_update_ref的子函数snd_config_hooks函数的分析。
mathjax: true
---
* TOC
{:toc}

解析配置的最后一个超复杂子函数

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
    //实际通常这里func后会跟一个load,比如alsa.conf中的func load
    //目的是加载其他配置
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
        //这里即可拼接出函数的名字
        snprintf(buf, len, "snd_config_hook_%s", str);
        buf[len-1] = '\0';
        func_name = buf;
    }
    //对dlopen的包装，打开库，如果指定的库不存在，则打开默认的库
    h = snd_dlopen(lib, RTLD_NOW);
    //对dlsym的包装，从动态库中解析函数符号，即通过字符串查找到函数
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
        //这里执行了根据字符串查找出来的函数
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
    //展开节点，并执行对应的函数
    //见下文分析
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


 | 函数名| 功能说明 | 使用到的宏| 
 | :- | :- | :- | :- |
 | snd_config_search | 在配置树中根据key查找节点|SND_CONFIG_SEARCH |
 | snd_config_searcha | 在配置树中根据key查找节点，展开别名。别名从root下查找|SND_CONFIG_SEARCHA |
 | snd_config_searchv | 在配置树中根据key查找节点；key可以是一系列的多个key|SND_CONFIG_SEARCHV | 
 | snd_config_searchva | 在配置树中根据key查找节点，展开别名；key可以是连续多个key|SND_CONFIG_SEARCHVA |
 | snd_config_search_alias |在配置树中根据key查找节点，展开别名.与snd_config_searcha类似，但是只能在config下查找。如果config下找不到id,则函数会尝试寻找base.id| SND_CONFIG_SEARCH_ALIAS |
 | snd_config_search_hooks |在配置树中根据key查找节点,并且展开hooks。与snd_config_search类似，但是搜索的任何包含hooks的节点都会被各自的hooks函数修改| SND_CONFIG_SEARCH|
 | snd_config_searcha_hooks |在配置树中根据key查找节点,并且展开alias与hooks| SND_CONFIG_SEARCHA |
 | snd_config_searchva_hooks | 在配置树中根据key查找节点,并且展开alias与hooks。与snd_config_searcha_hooks类似但是key可以是一系列的key|SND_CONFIG_SEARCHVA |
 | snd_config_search_alias_hooks |在配置树中根据key查找节点,并且展开alias与hooks。与snd_config_search_alias相似，并且展开hooks与snd_config_search_hooks相似| SND_CONFIG_SEARCH_ALIAS |


# 1.3.2 snd_config_expand 

使用参数及函数展开一个配置节点。如果传入的这个节点中有参数(通过一个id为@args的子节点定义),
则这个函数会用各自的参数值,或默认的参数值或者空来取代任何以$开头的string节点。
而且任何函数都会被评估（参考`snd_config_evaluate`),结果的副本将会在result中返回。
这里评估(evaluated)的意思比较模糊，从代码分析上看应该是所有的函数都被执行了。

```c
int snd_config_expand(snd_config_t *config, snd_config_t *root, const char *args,
              snd_config_t *private_data, snd_config_t **result)
{
    int err;
    snd_config_t *defs, *subs = NULL, *res;
    //寻找参数
    //前面已分析过
    err = snd_config_search(config, "@args", &defs);
    if (err < 0) {
        if (args != NULL) {
            SNDERR("Unknown parameters %s", args);
            return -EINVAL;
        }
        //创建config的副本到res,注意是深层拷贝
        //也就是说如果config是复合节点
        //它的子节点也会被拷贝
        //详细见下文分析
        err = snd_config_copy(&res, config);
        if (err < 0)
            return err;
    } else {
        //如果找到参数，则直接创建一个top节点
        //前文已分析
        err = snd_config_top(&subs);
        if (err < 0)
            return err;
        //把defs里面的"default“节点添加到空的subs里面
        //详细见下文分析
        err = load_defaults(subs, defs);
        if (err < 0) {
            SNDERR("Load defaults error: %s", snd_strerror(err));
            goto _end;
        }
        //解析参数args
        //太太太复杂
        err = parse_args(subs, args, defs);
        if (err < 0) {
            SNDERR("Parse arguments error: %s", snd_strerror(err));
            goto _end;
        }
        //在运行时评估一个配置节点
        err = snd_config_evaluate(subs, root, private_data, NULL);
        if (err < 0) {
            SNDERR("Args evaluate error: %s", snd_strerror(err));
            goto _end;
        }             }
        err = snd_config_walk(config, root, &res, _snd_config_expand, subs);
        if (err < 0) {
            SNDERR("Expand error (walk): %s", snd_strerror(err));
            goto _end;
        }
    }
    err = snd_config_evaluate(res, root, private_data, NULL);
    if (err < 0) {
        SNDERR("Evaluate error: %s", snd_strerror(err));
        snd_config_delete(res);
        goto _end;
    }
    *result = res;
    err = 1;
 _end:
    if (subs)
        snd_config_delete(subs);
    return err;
}
```

# 1.3.2.1 snd_config_evaluate

在运行时评估一个函数，此函数会评估配置树中的任何一个函数(@func)，
并用各自函数的结果替换这些节点。这里的评估应该时计算的意思。

```c
int snd_config_evaluate(snd_config_t *config, snd_config_t *root,
                snd_config_t *private_data, snd_config_t **result)
{
    /* FIXME: Only in place evaluation is currently implemented */
    assert(result == NULL);
    return snd_config_walk(config, root, result, _snd_config_evaluate, private_data);
}
```

# 1.3.2.2 snd_config_walk

这里面传入的回调函数为`_snd_config_evaluate`,函数本身又会有递归，
大概目的就是一步一步查找func，找到并执行，并且由于创建了新的配置树，
会把执行函数后的节点信息替换掉原来的节点。

```c
static int snd_config_walk(snd_config_t *src,
               snd_config_t *root,
               snd_config_t **dst,
               snd_config_walk_callback_t callback,
               snd_config_t *private_data)
{
    int err;
    snd_config_iterator_t i, next;

    switch (snd_config_get_type(src)) {
    case SND_CONFIG_TYPE_COMPOUND:
        err = callback(src, root, dst, SND_CONFIG_WALK_PASS_PRE, private_data);
        if (err <= 0)
            return err;
        snd_config_for_each(i, next, src) {
            snd_config_t *s = snd_config_iterator_entry(i);
            snd_config_t *d = NULL;

            err = snd_config_walk(s, root, (dst && *dst) ? &d : NULL,
                          callback, private_data);
            if (err < 0)
                goto _error;
            if (err && d) {
                err = snd_config_add(*dst, d);
                if (err < 0)
                    goto _error;
            }
        }
        err = callback(src, root, dst, SND_CONFIG_WALK_PASS_POST, private_data);
        if (err <= 0) {
        _error:
            if (dst && *dst)
                snd_config_delete(*dst);
        }
        break;
    default:
        err = callback(src, root, dst, SND_CONFIG_WALK_PASS_LEAF, private_data);
        break;
    }
    return err;
}
```
# 1.3.2.2 _snd_config_evaluate

具体执行函数，太复杂,即有循环，又有递归，注意里面的`snd_dlopen`
及`snd_dlsym`,会从动态库中根据func符号找到函数，并且执行。
所以func其实是执行了，evaluate可以理解为计算的意思。

```c
static int _snd_config_evaluate(snd_config_t *src,
                snd_config_t *root,
                snd_config_t **dst ATTRIBUTE_UNUSED,
                snd_config_walk_pass_t pass,
                snd_config_t *private_data)
{
    int err;
    if (pass == SND_CONFIG_WALK_PASS_PRE) {
        char *buf = NULL;
        const char *lib = NULL, *func_name = NULL;
        const char *str;
        int (*func)(snd_config_t **dst, snd_config_t *root,
                snd_config_t *src, snd_config_t *private_data) = NULL;
        void *h = NULL;
        snd_config_t *c, *func_conf = NULL;
        err = snd_config_search(src, "@func", &c);
        if (err < 0)
            return 1;
        err = snd_config_get_string(c, &str);
        if (err < 0) {
            SNDERR("Invalid type for @func");
            return err;
        }
        assert(str);
        err = snd_config_search_definition(root, "func", str, &func_conf);
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
            int len = 9 + strlen(str) + 1;
            buf = malloc(len);
            if (! buf) {
                err = -ENOMEM;
                goto _err;
            }
            snprintf(buf, len, "snd_func_%s", str);
            buf[len-1] = '\0';
            func_name = buf;
        }
        h = snd_dlopen(lib, RTLD_NOW);
        if (h)
            func = snd_dlsym(h, func_name, SND_DLSYM_VERSION(SND_CONFIG_DLSYM_VERSION_EVALUATE));
        err = 0;
        if (!h) {
            SNDERR("Cannot open shared library %s", lib);
            err = -ENOENT;
            goto _errbuf;
        } else if (!func) {
            SNDERR("symbol %s is not defined inside %s", func_name, lib);
            snd_dlclose(h);
            err = -ENXIO;
            goto _errbuf;
        }
           _err:
        if (func_conf)
            snd_config_delete(func_conf);
        if (err >= 0) {
            snd_config_t *eval;
            err = func(&eval, root, src, private_data);
            if (err < 0)
                SNDERR("function %s returned error: %s", func_name, snd_strerror(err));
            snd_dlclose(h);
            if (err >= 0 && eval) {
                /* substitute merges compound members */
                /* we don't want merging at all */
                err = snd_config_delete_compound_members(src);
                if (err >= 0)
                    //替换节点
                    err = snd_config_substitute(src, eval);
            }
        }
           _errbuf:
        free(buf);
        if (err < 0)
            return err;
        return 0;
    }
    return 1;
}
```

至此，`snd_config_expand`的功能为展开节点，从节点中搜索函数，逐个执行，并最终用执行结果替换掉原来的节点。
`snd_config_search_definition`则查找某个定义，查找到后使用`snd_config_expand`去展开执行。
根据读取alsa的默认配置文件alsa.conf,通常会构建一个func load函数，再用构造出的函数去load配置文件。
里面又是一大堆递归。总之alsa配置的目的就是通过在配置文件中修改配置，即可控制运行时的函数执行。
为了实现这个目标，alsa丧心病狂的实现了众多嵌套，递归，为了实现代码复用，采用了众多的宏，整体让alsa变得及其复杂。

比如alsa.conf中的配置:

```bash
@hooks [
    {
        func load
        files [
            "/etc/alsa/conf.d"
            "/etc/asound.conf"
            "~/.asoundrc"
        ]
        errors false
    }
]
```

通过这个hooks，实际上构造了`snd_config_hooks_load`函数,运行时会解析符号并从动态库中找到此函数，
用来加载接下来的三个配额文件，`"/etc/alsa/conf.d"`及`"/etc/asound.conf"`,`"~/.asoundrc"`。

至此`snd_config_update_r`的大致功能已经比较清晰了，从配置文件中读取配置文件，解析为配置树，
执行所有的hooks，其中可能又会包含读取配置文件，解析为配置树。执行所有的hooks函数，重新更新配置树。
返回最后的配置树。
