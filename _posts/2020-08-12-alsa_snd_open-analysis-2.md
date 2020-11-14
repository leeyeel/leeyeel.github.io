---
layout: post
title:  "linux alsa-lib snd_pcm_open函数详细分析（二)"
date:   2020-08-11 11:56:00
categories: 笔记心得
tags: audio linux alsa
excerpt: alsa-lib 读取更新配置树函数snd_config_update_ref的分析
mathjax: true
---

{:toc}

`snd_config_update_ref`函数的目的是更新配置树，第一次调用时，实际上主要是解析并加载配置文件。
函数的原型已经在[上一篇]({{site.url}}/2020/08/11/alsa_snd_open-analysis-1)中介绍过，
`snd_config_update_ref`主要是调用了`snd_config_update_r`函数，本篇我们会详细分析此函数。

### 1.snd_config_update_r 

函数原型如下:
```c
/**
 * \brief 更新配置树，如果需要则会读取配置树.
 * \param _top 顶层节点指针的地址，是个二级指针，用作输出.
 * \param _update 私有更新信息指针的地址
 * \param cfgs 一系列使用':'分割的配置文件名称，如果这里的参数为null，则会使用默认的全局配置文件.
 * \return 0: _top 已更新到最新; 1: 配置文件已被重新读取;其他情况则返回一个负数错误码
 *
 * 在第一次调用此函数之前，_top 和 _update 指向的变量可以被初始化为Null,
 * 第二个参数，私有信息保存着所有用过的配置信息，函数用这些信息来检测是否需要更新配置。
 * 释放这些信息的内存可以使用snd_config_update_free函数
 *
 * 全局配置文件由环境变量ALSA_CONFIG_PATH指定
 *
 * \warning 如果配置树被重新读取，所有的从这棵树上获取的字符串以及配置节点都会实效。
 *
 * \par Errors: 解析输入或者运行hooks或者函数时遇到错误均会返回
 */
int snd_config_update_r(snd_config_t **_top, snd_config_update_t **_update, const char *cfgs)
{
    int err;
    const char *configs, *c;
    unsigned int k;
    size_t l;
    snd_config_update_t *local;
    snd_config_update_t *update;
    snd_config_t *top;

    assert(_top && _update);
    top = *_top;
    //第一次调用时，在snd_config_update_ref传入的参数为snd_config_global_update,
    //这个参数被初始化为空指针
    update = *_update;
    //第一次调用时，在snd_config_update_ref传入的参数为NULL
    configs = cfgs;
    if (!configs) {//会进入分支
        //此处会读取环境变量ALSA_CONFIG_PATH_VAR
        //如果环境变量不存在，则返回NULL,默认情况下未配置此环境变量，所以此处会返回NULL
        configs = getenv(ALSA_CONFIG_PATH_VAR);
        if (!configs || !*configs) {
            //返回默认的顶层配置目录，详见下文分析
            const char *topdir = snd_config_topdir();
            char *s = alloca(strlen(topdir) +
                     strlen("alsa.conf") + 2);
            sprintf(s, "%s/alsa.conf", topdir);
            //这里默认情况下config为:'/usr/share/alsa/alsa.conf'
            configs = s;
        }
    }
    //此处需要循环的原因是配置文件可能有多个，
    //即上面提到的环境变量ALSA_CONFIG_PATH_VAR可能有多个以`:`分割的配置文件
    //参考我们平时使用的PATH环境变量，也是有多个以`:`分割的变量
    //通常情况下如果环境变量中只有一个配置文件，则循环只需要执行一次
    //此处c库函数strcspn的目的是计算字符串c中连续有多少个字符都不属于字符串": "，
    //如果c中不含有": ",则返回的就是c字符串中字符的个数，也就是configs字符串的长度减1(由于字符串后有\0)。
    //此时l > 0, 满足循环条件，进入循环体
    //c += l, 即c偏移了整个字符串的长度-1，刚好到了末尾的\0
    //k++后为1，此时*C为0，!*c为1，进入分支，break退出
    for (k = 0, c = configs; (l = strcspn(c, ": ")) > 0; ) {
        c += l;
        k++;
        if (!*c)
            break;
        c++;
    }
    //根据前面分析k=1
    if (k == 0) {
        local = NULL;
        goto _reread;
    }
    //分配内存
    local = (snd_config_update_t *)calloc(1, sizeof(snd_config_update_t));
    if (!local)
        return -ENOMEM;
    local->count = k;
    local->finfo = calloc(local->count, sizeof(struct finfo));
    if (!local->finfo) {
        free(local);
       return -ENOMEM;
    }
    //与前面分析类似，循环只执行一次
    for (k = 0, c = configs; (l = strcspn(c, ": ")) > 0; ) {
        char name[l + 1];
        memcpy(name, c, l);
        name[l] = 0;
        //目的是把相对路径变为绝对路径，比如地址中如果有~/，则自动转换为/home/
        //详细实现见下文分析
        err = snd_user_file(name, &local->finfo[k].name);
        if (err < 0)
            goto _end;
        c += l;
        k++;
        if (!*c)
            break;
        c++;
    }
    for (k = 0; k < local->count; ++k) {
        struct stat st;
        struct finfo *lf = &local->finfo[k];
        //此处是获取配置文件的状态信息
        if (stat(lf->name, &st) >= 0) {
            lf->dev = st.st_dev;
            lf->ino = st.st_ino;
            lf->mtime = st.st_mtime;
        } else {
            SNDERR("Cannot access file %s", lf->name);
            free(lf->name);
            //这个地方的实现非常精巧，把数组后面的复制到前面
            //具体拷贝的内存数目与配置个数相关，如果只有一个配置文件，则拷贝大小为0，实际上并没有拷贝
            //如果有两个配置，第一个配置文件权限问题无法使用，则会把第二个拷贝到第一个的位置
            //拷贝完成后k--,然后再次检测第一个的配置文件，实际上是第二个配置文件。
            //多个配置文件同理，并对总数local->count--
            memmove(&local->finfo[k], &local->finfo[k+1], sizeof(struct finfo) * (local->count - k - 1));
            k--;
            local->count--;
        }
    }
    if (!update)
        goto _reread;
    if (local->count != update->count)
        goto _reread;
    for (k = 0; k < local->count; ++k) {
        struct finfo *lf = &local->finfo[k];
        struct finfo *uf = &update->finfo[k];
        if (strcmp(lf->name, uf->name) != 0 ||
            lf->dev != uf->dev ||
            lf->ino != uf->ino ||
            lf->mtime != uf->mtime)
            goto _reread;
    }
    err = 0;

 _end:
    if (err < 0) {
        if (top) {
            //释放一个配置节点以及它的所有子结点的内存
            //如果这个节点本身是个子节点，则释放时会首先从配置树中移除掉
            //此函数假设只用来删除本地的配置树，对于全局配置树
            //使用nd_config_update_ref取引用计数，并且使用snd_config_unref去引用计数才能删除
            snd_config_delete(top);
            *_top = NULL;
        }
        if (update) {
            //释放私有的update结构体的内存
            snd_config_update_free(update);
            *_update = NULL;
        }
    }
    if (local)
        snd_config_update_free(local);
    return err;

 _reread:
    *_top = NULL;
    *_update = NULL;
    //根据前面的分析此处为null,如果不为null,则把内存释放掉强制为null
    if (update) {
        snd_config_update_free(update);
        update = NULL;
    }
    //top同上
    if (top) {
        snd_config_delete(top);
        top = NULL;
    }
    //仅仅是创建了一个顶层的配置树，本质上创建了一个空的链表
    //详细分析见下文
    err = snd_config_top(&top);
    if (err < 0)
        goto _end;
    //local为malloc分配内存，正常运行则不进入分支
    if (!local)
        goto _skip;
    for (k = 0; k < local->count; ++k) {
        snd_input_t *in;
        //创建一个输入文件类型，其中包括了输入文件的各种操作。类似于c++中输入文件类
        //创建使用的参数是文件名称，第一个参数in是出参。此函数详见下文分析
        err = snd_input_stdio_open(&in, local->finfo[k].name, "r");
        if (err >= 0) {
            //把上一步获取到的输入类型作为参数，此函数的目的是解析并加载这个输入文件
            //加载整个配置树后，top便是整个配置树的入口
            //下文会对此函数作深入分析
            err = snd_config_load(top, in);
            snd_input_close(in);
            if (err < 0) {
                SNDERR("%s may be old or corrupted: consider to remove or fix it", local->finfo[k].name);
                goto _end;
            }
        } else {
            SNDERR("cannot access file %s", local->finfo[k].name);
        }
    }
 _skip:
    //此函数的功能是配置并执行了配置树中的hooks函数。
    //如果配置文件中引用了其他配置,则通过此函数最终层层加载到引用的配置，最终一并添加到配置树中
    //详细见下文分析
    err = snd_config_hooks(top, NULL);
    if (err < 0) {
        SNDERR("hooks failed, removing configuration");
        goto _end;
    }
    *_top = top;
    *_update = local;
    return 1;
}
```

##### 1.1 sndconfig_topdir

此函数的功能简单，返回默认的顶层配置目录。这里的顶层配置目录其实就是指配置文件的根目录。
函数以字符串的形式返回顶层配置目录，如果配置了环境变量ALSA_CONFIG_DIR，
且这个路径确实有效，则函数会返回这个环境变量的值，否则会返回默认值

```c
const char *snd_config_topdir(void)
{
    //注意是静态变量，所以如果第一次调用函数时获取到了值则下次会直接返回这个值
    static char *topdir;
    if (!topdir) {
        //获取环境变量
        topdir = getenv("ALSA_CONFIG_DIR");
        if (!topdir || *topdir != '/' || strlen(topdir) >= PATH_MAX)
            //默认值ALSA_CONFIG_DIR,具体定义可能有所不同
            topdir = ALSA_CONFIG_DIR;
    }
    return topdir;
}
```

##### 1.2 snd_user_file

函数的目的是展开环境变量中的相对路径，如果获取到的环境变量中有`~/`开头，则会展开为具体的绝对路径。

```c
int snd_user_file(const char *file, char **result)
{
    int err;
    size_t len;
    char *buf = NULL;

    assert(file && result);
    *result = NULL;

    /* expand ~/ if needed */
    // 如果开头有~/，则会去读HOME环境变量,如果读到，则用读到的值替换~/
    // 如果读取不到HOME,则会进一步读取linux的passwd文件，从中解析出目录
    if (file[0] == '~' && file[1] == '/') {
        const char *home = getenv("HOME");
        if (home == NULL) {
            struct passwd pwent, *p = NULL;
            //获取当前用户的uid
            uid_t id = getuid();
            size_t bufsize = 1024;

            buf = malloc(bufsize);
            if (buf == NULL)
                goto out;
            //返回ERANGE表示size太小,此时进入循环重新分配
            while ((err = getpwuid_r(id, &pwent, buf, bufsize, &p)) == ERANGE) {
                char *newbuf;
                bufsize += 1024;
                if (bufsize < 1024)
                    break;
                newbuf = realloc(buf, bufsize);
                if (newbuf == NULL)
                    goto out;
                buf = newbuf;
            }
            //找到匹配后返回当前用户的pw_dir
            home = err ? "" : pwent.pw_dir;
        }
        len = strlen(home) + strlen(&file[2]) + 2;
        *result = malloc(len);
        if (*result)
            snprintf(*result, len, "%s/%s", home, &file[2]);
    } else {
        //strdup拷贝file字符串到result
        *result = strdup(file);
    }

out:
    if (buf)
        free(buf);

    if (*result == NULL)
        return -ENOMEM;
    return 0;
}
```

##### 1.3 snd_config_top

创建一个top配置节点，返回内容是个空的复合节点，既没有父节点也没有ID。

```c
int snd_config_top(snd_config_t **config)
{
    assert(config);
    return _snd_config_make(config, 0, SND_CONFIG_TYPE_COMPOUND);
}
```
###### 1.3.1 _snd_config_make

```c
static int _snd_config_make(snd_config_t **config, char **id, snd_config_type_t type)
{
    snd_config_t *n;
    assert(config);
    //分配内存
    n = calloc(1, sizeof(*n));
    if (n == NULL) {
        if (*id) {
            free(*id);
            *id = NULL;
        }
        return -ENOMEM;
    }
    //top节点，传入的id为0，即没有id
    if (id) {
        n->id = *id;
        *id = NULL;
    }
    //传入type为SND_CONFIG_TYPE_COMPOUND
    n->type = type;
    //初始化复合类型节点链表
    //INIT_LIST_HEAD的工作只是把next及pre指针全部初始化为当前节点,即执行如下操作
    //n->u.compound.fields.next = n->u.compound.fields.pre = &n->u.compound.fields
    if (type == SND_CONFIG_TYPE_COMPOUND)
        INIT_LIST_HEAD(&n->u.compound.fields);
    *config = n;
    return 0;
}
```

#### 1.4 snd_input_stdio_open

通过打开文件来创建一个新的输入对象，
其中输入对象是alsa中的一个结构体，里面封装了输入对象的各种成员变量及方法。
此函数会打开文件，并把打开文件的句柄作为输入对象的成员变量。
```c
int snd_input_stdio_open(snd_input_t **inputp, const char *file, const char *mode)
{
    int err;
    //打开配置文件
    FILE *fp = fopen(file, mode);
    if (!fp) {
        //SYSERR("fopen");
        return -errno;
    }
    //创建新的输入对象
    //只不过不是通过打开文件，而是通过直接传入文件句柄
    err = snd_input_stdio_attach(inputp, fp, 1);
    if (err < 0)
        fclose(fp);
    return err;
}
```
###### 1.4.1 snd_input_stdio_open

主要功能是给snd_input_t这个结构体赋值
```c
int snd_input_stdio_attach(snd_input_t **inputp, FILE *fp, int _close)
{
    snd_input_t *input;
    snd_input_stdio_t *stdio;
    assert(inputp && fp);
    //分配内存
    stdio = calloc(1, sizeof(*stdio));
    if (!stdio)
        return -ENOMEM;
    input = calloc(1, sizeof(*input));
    if (!input) {
        free(stdio);
        return -ENOMEM;
    }
    //注意这里的fp,保存在stdio中，stdio又保存在input的private变量中
    //最终出参即为input
    stdio->fp = fp;
    //此处_close为1,表示需要调用者调用snd_input_close去关闭文件
    stdio->close = _close;
    input->type = SND_INPUT_STDIO;
    input->ops = &snd_input_stdio_ops;
    input->private_data = stdio;
    *inputp = input;
    return 0;
}
```

#### 1.5 snd_config_load

是本篇的核心，也是最复杂的函数。
加载一个配置树,注意这里传入的第二个参数in,即是snd_input_stdio_open的出参,
内部包含了输入文件的句柄。函数会读取并解析这个输入文件，最终把配置文件转变为配置树的形式。

```c
int snd_config_load(snd_config_t *config, snd_input_t *in)
{
    //snd_config_load1分析见下面函数
    return snd_config_load1(config, in, 0);
}
```

###### 1.5.1 snd_config_load1

比上面函数多了override参数

```c
static int snd_config_load1(snd_config_t *config, snd_input_t *in, int override)
{
    int err;
    input_t input;
    //结构体见1.5.1.1代码
    struct filedesc *fd, *fd_next;
    assert(config && in);
    //分配内存，
    fd = malloc(sizeof(*fd));
    if (!fd)
        return -ENOMEM;
    //注意这里in的参数传递给了fd
    fd->name = NULL;
    fd->in = in;
    fd->line = 1;
    fd->column = 0;
    fd->next = NULL;
    INIT_LIST_HEAD(&fd->include_paths);
    //这里fd被传递给了input的current字段
    input.current = fd;
    input.unget = 0;
    //解析配置文件，是本函数的核心函数
    //详细分析见 1.5.1.2
    err = parse_defs(config, &input, 0, override);
    fd = input.current;
    if (err < 0) {
        const char *str;
        switch (err) {
        case LOCAL_UNTERMINATED_STRING:
            str = "Unterminated string";
            err = -EINVAL;
            break;
        case LOCAL_UNTERMINATED_QUOTE:
                        str = "Unterminated quote";
            err = -EINVAL;
            break;
        case LOCAL_UNEXPECTED_CHAR:
            str = "Unexpected char";
            err = -EINVAL;
            break;
        case LOCAL_UNEXPECTED_EOF:
            str = "Unexpected end of file";
            err = -EINVAL;
            break;
        default:
            str = strerror(-err);
            break;
        }
        SNDERR("%s:%d:%d:%s", fd->name ? fd->name : "_toplevel_", fd->line, fd->column, str);
        goto _end;
    }
    if (get_char(&input) != LOCAL_UNEXPECTED_EOF) {
        SNDERR("%s:%d:%d:Unexpected }", fd->name ? fd->name : "", fd->line, fd->column);
        err = -EINVAL;
        goto _end;
    }
 _end:
    while (fd->next) {
        fd_next = fd->next;
        snd_input_close(fd->in);
        free(fd->name);
        free_include_paths(fd);
        free(fd);
        fd = fd_next;
    }

    free_include_paths(fd);
    free(fd);
    return err;
}
```

###### 1.5.1.1 struct filedesc

```c
struct filedesc {
    char *name;
    snd_input_t *in;
    unsigned int line, column;
    struct filedesc *next;

    /* list of the include paths (configuration directories),
     * defined by <searchdir:relative-path/to/top-alsa-conf-dir>,
     * for searching its included files.
     */
    struct list_head include_paths;
};
```

###### 1.5.1.2 parse_defs

读取配置文件并解析为配置树的形式

```c
static int parse_defs(snd_config_t *parent, input_t *input, int skip, int override)
{
    int c, err;
    while (1) {
        c = get_nonwhite(input);
        if (c < 0)
            return c == LOCAL_UNEXPECTED_EOF ? 0 : c;
        unget_char(c, input);
        if (c == '}')
            return 0;
        err = parse_def(parent, input, skip, override);
        if (err < 0)
            return err;
    }
    return 0;
}
```

未完代序，正文刚刚开始
