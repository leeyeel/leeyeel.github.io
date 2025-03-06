---
layout: post
title:  "linux alsa-lib snd_pcm_open函数源码分析（二)"
date:   2020-08-12 23:56:00
categories: 音视频 
tags: alsa 驱动 音频
excerpt: snd_pcm_open源码分析的第二篇，对子函数snd_config_update_ref的分析，其中主要是对snd_config_update_ref的子函数snd_config_load函数的分析。
mathjax: true
---
* TOC
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

### 1.1 sndconfig_topdir

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

### 1.2 snd_user_file

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

### 1.3 snd_config_top

创建一个top配置节点，返回内容是个空的复合节点，既没有父节点也没有ID。

```c
int snd_config_top(snd_config_t **config)
{
    assert(config);
    return _snd_config_make(config, 0, SND_CONFIG_TYPE_COMPOUND);
}
```
### 1.3.1 _snd_config_make

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
### 1.4 snd_input_stdio_open

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

### 1.4.1 snd_input_stdio_open

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
    //注意这里的ops字段即private_data字段，后面分析会用到
    input->ops = &snd_input_stdio_ops;
    input->private_data = stdio;
    *inputp = input;
    return 0;
}
```

### 1.5 snd_config_load

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

### 1.5.1 snd_config_load1

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

### 1.5.1.1 struct filedesc

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

### 1.5.1.2 parse_defs

读取配置文件并解析为配置树的形式

```c
static int parse_defs(snd_config_t *parent, input_t *input, int skip, int override)
{
    int c, err;
    //注意这里的循环，理想情况下在此可解析全部置文件
    while (1) {
        //获取一个非空的字符，非空表示不是空格或制表符这类的字符
        //实现原理见下文的详细分析
        c = get_nonwhite(input);
        if (c < 0)
            return c == LOCAL_UNEXPECTED_EOF ? 0 : c;
        //此函数的实际目的不是很清楚
        //unget_char与get_char对应，实际unget_char并未做任何读取的操作
        //unget_char只是对输入参数input的赋值，特别是赋值了unget这个字段为1
        //这个字段的作用是会在下一次的读取中，直接跳过读取，返回当前的字符c
        //所以在某处使用了unget_char之后，
        //通过alsa的接口再次获取字符时，获取到的字符依然是c,而不是文件真实的下一个字符
        //这么做的目的不清楚，如果有小伙伴了解请告诉我
        unget_char(c, input);
        if (c == '}')
            return 0;
        //核心函数，解析读出来的具体的某个关键字并解析
        //详细分析见下文
        err = parse_def(parent, input, skip, override);
        if (err < 0)
            return err;
    }
    return 0;
}
```

### 1.5.1.2.1 get_nonwhite

从文件中读取一个字符，如果遇到空格或者制表符,回车等空字符则跳过，实际返回一个非空字符

```c
tatic int get_nonwhite(input_t *input)
{
    int c;
    while (1) {
        //跳过注释，见下文分析
        c = get_char_skip_comments(input);
        //从代码中可以看到，如果读取到的为' ','\f','\t','\n','\r'等字符则会跳出switch语句，
        //但是仍在while中，所以会继续读取字符,再次判断
        switch (c) {
        case ' ':
        case '\f':
        case '\t':
        case '\n':
        case '\r':
            break;
        default:
            return c;
        }
    }
}
```

### 1.5.1.2.1.1 get_char_skip_comments

从文件中读取一个字符，但是会跳过注释行。也就是说此函数会返回一个不是注释的字符。

```c
static int get_char_skip_comments(input_t *input)
{
    int c;
    while (1) {
        //从输入文件中读取一个字符，最终会调用C库的getc接口读取字符
        //详细分析见下文
        c = get_char(input);
        //实际中未发现有'<'符号，此语法不详
        //从代码分析上看，如果遇到'<'则读取'<'与'>'之间的内容
        //最后调用snd_input_stdio_open返回出参input
        //之后继续读取字符。推测'< >'之间为配置searchdir即configdir的语法
        if (c == '<') {
            char *str;
            snd_input_t *in;
            struct filedesc *fd;
            DIR *dirp;
            //如果读取到字符为'<',表示后面可能还有'>'与之配对
            //再次读取时要把这对括号之间的内容全部读取
            //详细分析见下文
            int err = get_delimstring(&str, '>', input);
            if (err < 0)
                return err;

            //判断是否有"searchdir:"，如果有，则此目录为头文件的搜索目录
            //采用默认值时没有设置此路径,不会进入分支
            if (!strncmp(str, "searchdir:", 10)) {
                /* directory to search included files */
                //如果有searchdir:，则把:后的路径，及top路径组合起来，返回给tmp
                //具体实现见下文
                char *tmp = _snd_config_path(str + 10);
                free(str);
                if (tmp == NULL)
                    return -ENOMEM;
                str = tmp;

                //打开目录，目的是判断目录是否存在是否可用
                dirp = opendir(str);
                if (!dirp) {
                    SNDERR("Invalid search dir %s", str);
                    free(str);
                    return -EINVAL;
                }
                closedir(dirp);

                //把上面拼接好的路径添加到搜索链表中
                //具体实现见下文分析
                err = add_include_path(input->current, str);
                if (err < 0) {
                    SNDERR("Cannot add search dir %s", str);
                    free(str);
                    return err;
                }
                continue;
            }

            //与上面searchdir:同理
            //默认没有confdir,会进入else分支
            if (!strncmp(str, "confdir:", 8)) {
                /* file in the specified directory */
                //与searchdir同理
                char *tmp = _snd_config_path(str + 8);
                free(str);
                if (tmp == NULL)
                    return -ENOMEM;
                str = tmp;
                //见前面分析,打开一个配置文件，返回输入文件对象
                err = snd_input_stdio_open(&in, str, "r");
            } else { /* absolute or relative file path */
                //查找并打开一个文件，功能与snd_input_stdio_open类似
                //通过从文件读取内容创建一个新的输入文件对象
                //详细实现见下文分析
                err = input_stdio_open(&in, str,
                        &input->current->include_paths);
            }

            if (err < 0) {
                SNDERR("Cannot access file %s", str);
                free(str);
                return err;
            }
            fd = malloc(sizeof(*fd));
            if (!fd) {
                free(str);
                return -ENOMEM;
            }
            fd->name = str;
            fd->in = in;
            fd->next = input->current;
            fd->line = 1;
            fd->column = 0;
            INIT_LIST_HEAD(&fd->include_paths);
            input->current = fd;
            continue;
        }
        //如果不为'#'则break退出，否则进入下面的while直到\n换行
        //即如果开头是'#',则把剩余的读完，
        //直到读到一行开头不是'#'的字符并返回此字符
        if (c != '#')
            break;
        while (1) {
            c = get_char(input);
            if (c < 0)
                return c;
            if (c == '\n')
                break;
        }
    }

    return c;
}
```

### 1.5.1.2.1.1.1 get_char

从文件中读取一个字符

```c 
static int get_char(input_t *input) {
    int c;
    struct filedesc *fd;
    //注意此处对unget的判断
    //如果之前使用了unget_char，则会把unget置为1
    //此时这里会直接返回input->ch，即使用unget_char之前时读到的字符
    if (input->unget) {
        input->unget = 0;
        return input->ch;
    }       
 again:
    //前面在snd_config_load1中把fd赋值给input->current
    fd = input->current;
    //从输入文件中读取一个字符
    //注意此处的fd->in,fd来自于input->current; input来自于get_char_skip_comments,
    //而get_char_skip_comments又来自于`get_nonwhite`,来自于`parse_defs`，来自于`snd_config_load1`,
    //在snd_config_load1`中，fd->in来自于`snd_config_load1`的入参，
    //最终来自于snd_input_stdio_open的出参
    //详见下文分析
    c = snd_input_getc(fd->in);
    switch (c) {

    //如果读到\n换行符则行数加1，列数变为0
    case '\n':  
        fd->column = 0;
        fd->line++;
        break;  

    //如果读到\t换行符则列数补足到8的倍数列
    //比如原来column为2,遇到\t,则column变为8
    //比如原来column为9,遇到\t,则column变为16
    case '\t':  
        fd->column += 8 - fd->column % 8;
        break;  

    //文件结束,则判断是否还有其他文件
    //如果还有其他文件，则释放当前文件的内存
    //打开后面的文件继续读取
    //如果没有其他文件则返回错误码
    case EOF:       
        if (fd->next) {
            snd_input_close(fd->in);
            free(fd->name);
            input->current = fd->next;
            free(fd);
            goto again;
        }
        return LOCAL_UNEXPECTED_EOF;

    //默认情况下列数加1，表示读取到一个字符
    default:
        fd->column++;
        break;
    }
    return (unsigned char)c;
}
```
### 1.5.1.2.1.1.1.1 snd_input_getc

从打开的文件中读取一个字符。
这里函数开始使用了函数指针，全都一样的面具，所以要深入分析到底是哪个函数。
```c
int snd_input_getc(snd_input_t *input)
{
    return input->ops->getch(input);
}
```
逐一向上追溯入参input,可以发现`snd_input_getc`中的参数来源于`get_char中`的`fd->in`,
根据`get_char`函数中的分析，`fd->in`是来自于`snd_input_stdio_open`的出参，
参考前面的`snd_input_stdio_open`的分析，in参数在`snd_input_stdio_attach`被赋值，
其ops字段为`&snd_input_stdio_ops`,此结构体定义如下:
```c
    static const snd_input_ops_t snd_input_stdio_ops = {                                                                                
    .close      = snd_input_stdio_close,                                                                                            
    .scan       = snd_input_stdio_scan,                                                                                             
    .gets       = snd_input_stdio_gets,                                                                                             
    .getch      = snd_input_stdio_getc,                                                                                             
    .ungetch    = snd_input_stdio_ungetc,                                                                                           
}; 
```
分析其中的`getch`函数为`snd_input_stdio_getc`,具体定义为:
```
static int snd_input_stdio_getc(snd_input_t *input)
{
    snd_input_stdio_t *stdio = input->private_data;
    return getc(stdio->fp);
}
```
再分析input参数中的private_data字段,与ops字段一样，在`snd_input_stdio_attach`被赋值，
其值为`snd_input_stdio_t *stdio`,stdio的fp字段为在`snd_input_stdio_open`中打开的文件描述符`fp`,
也就是打开的配置文件的描述符，至此可以发现，读取字符最终使用的还是c库提供的接口`getc`。

### 1.5.1.2.1.1.1.2 get_delimstring

按照分割符读取字符串，即读取分割符之间的字符串

```c
static int get_delimstring(char **string, int delim, input_t *input)
{
    struct local_string str;
    int c;

    //初始化为0
    init_local_string(&str);
    while (1) {
        //获取一个字符
        c = get_char(input);
        if (c < 0)
            break;
        if (c == '\\') {
            //获取一个反转字符
            //这是由于反转字符的ascii码需要一个'\'加一个字符表示，
            //字节读取ascii字符无法准确获取反转字符
            //具体实现方式见下文分析
            c = get_quotedchar(input);
            if (c < 0)
                break;
            if (c == '\n')
                continue;
        } else if (c == delim) {
            //把str中的字符串拷贝到从堆中分配的内存中，
            //并返回堆的地址
            //所以返回的字符串需要手动释放内存
            *string = copy_local_string(&str);
            if (! *string)
                c = -ENOMEM;
            else
                c = 0;
            break;
        }
        //把字符添加到本地string中
        //如果字符超出了string预定义的大小
        //则扩展字符串大小为原来的两倍后再添加
        //具体实现方式见下文分析
        if (add_char_local_string(&str, c) < 0) {
            c = -ENOMEM;
            break;
        }
    }
     free_local_string(&str);
     return c;
}
```
### 1.5.1.2.1.1.1.2.1 get_quotedchar

解析带有转义字符的字符,需要注意的是如果是转义字符+数字的组合，
表示后面是三位八进制数字。函数会读取三位并转换为十进制数字返回。
```c
static int get_quotedchar(input_t *input)
{
    int c;
    //读取一个字符
    c = get_char(input);
    switch (c) {
    //换行
    case 'n':
        return '\n';
    //制表
    case 't':
        return '\t';
    //垂直制表
    case 'v':
        return '\v';
    //退格
    case 'b':
        return '\b';
    //回车
    case 'r':
        return '\r';
    //换页
    case 'f':
        return '\f';
    //三位八进制数
    case '0' ... '7':
    {
        int num = c - '0';
        int i = 1;
        do {
            c = get_char(input);
            if (c < '0' || c > '7') {
                unget_char(c, input);
                break;
            }
            //转换为十进制
            num = num * 8 + c - '0';
            i++;
        } while (i < 3);
        return num;
    }
    default:
        return c;
    }
}
```

### 1.5.1.2.1.1.1.2.2 add_char_local_string

添加一个字符到字符串后面。每读到一个字符，就添加到字符串后面，最终字符组成字符串返回。
需要注意local string在初始化时有个默认的大小为64个字节。如果添加字符后长度超出范围，
则函数会先把大小变为原来的两倍，再添加字符。有点类似与c++中的vector。
```c
static int add_char_local_string(struct local_string *s, int c)
{
    //索引值大于等于分配的大小，则需要重新分配大小
    if (s->idx >= s->alloc) {
        //注意这里，新的大小变为原来的两倍
        size_t nalloc = s->alloc * 2;
        if (s->buf == s->tmpbuf) {
            s->buf = malloc(nalloc);
            if (s->buf == NULL)
                return -ENOMEM;
            memcpy(s->buf, s->tmpbuf, s->alloc);
        } else {
            char *ptr = realloc(s->buf, nalloc);
            if (ptr == NULL)
                return -ENOMEM;
            s->buf = ptr;
        }
        s->alloc = nalloc;
    }
    s->buf[s->idx++] = c;
    return 0;
}
```
### 1.5.1.2.1.1.2 _snd_config_path

生成一个绝对路径。采用的方式拼接top目录及name
```c
static char *_snd_config_path(const char *name)
{
    //获取top目录，前面已分析过
    const char *root = snd_config_topdir();
    char *path = malloc(strlen(root) + strlen(name) + 2);
    if (!path)
        return NULL;
    sprintf(path, "%s/%s", root, name);
    return path;
}
```

### 1.5.1.2.1.1.3 add_include_path

把路径添加到include搜索路径的链表中。根据前面的分析，此路径是由top路径加名称拼接的，
所以此目录一定在top目录下。
```c
static int add_include_path(struct filedesc *fd, char *dir)
{
    struct include_path *path;

    path = calloc(1, sizeof(*path));
    if (!path)
        return -ENOMEM;

    path->dir = dir;
    list_add_tail(&path->list, &fd->include_paths);
    return 0;
}
```

### 1.5.1.2.1.1.4 input_stdio_open

目的依然是打开一个配置文件，并返回一个snd_input_t类型，与snd_input_stdio_open功能一致，
区别是input_stdio_open传入的参数file可以是绝对路径，也可以是相对top的相对路径，
函数如果打开绝对路径失败，则会继续打开相对路径，如果相对路径也失败，则判断第三个参数
include_paths是否有配置，如果有配置则继续从include_paths下查找是否有file，有则打开执行。

```c
static int input_stdio_open(snd_input_t **inputp, const char *file,
                struct list_head *include_paths)
{
    struct list_head *pos, *base;
    struct include_path *path;
    char full_path[PATH_MAX + 1];
    int err = 0;
    //返回一个输入文件对象，输入的配置文件为file
    //file可以是绝对路径，也可以是相对于top目录的相对路径
    //如果是绝对路径，则此处顺利的话可以执行成功，err为0，跳转到out
    //如果是相对路径，则此处执行失败，继续下面file[0] ==  '/'的判断
    err = snd_input_stdio_open(inputp, file, "r");
    if (err == 0)
        goto out;

    //如果执行到此说明前面snd_input_stdio_open函数执行失败
    //执行失败可能是因为输入的路径是相对路径
    //此处如果输入的file为绝对路径，
    //说明前面snd_input_stdio_open执行失败的原因是找不到此文件或文件有问题
    //此时应该返回错误直接退出
    //如果路径不是绝对路径，说明此时传入的可能是相对top的相对路径
    //则继续下面的流程
    if (file[0] == '/') /* not search file with absolute path */
        return err;

    /* search file in top configuration directory /usr/share/alsa */
    //snd_config_topdir 返回默认的配置顶层目录，即/usr/share/alsa
    //最终full_path返回file的绝对路径
    snprintf(full_path, PATH_MAX, "%s/%s", snd_config_topdir(), file);
    //继续打开配置文件，执行到此处说明传入的file参数是个相对路径
    err = snd_input_stdio_open(inputp, full_path, "r");
    if (err == 0)
        goto out;

    /* search file in user specified include paths. These directories
     * are subdirectories of /usr/share/alsa.
     */
    if (include_paths) {
        base = include_paths;
        list_for_each(pos, base) {
            path = list_entry(pos, struct include_path, list);
            if (!path->dir)
                continue;

            //返回的是path->dir下file的路径，即在path->dir下查找file
            snprintf(full_path, PATH_MAX, "%s/%s", path->dir, file);
            err = snd_input_stdio_open(inputp, full_path, "r");
            if (err == 0)
                goto out;
        }
    }

out:
    return err;
}
```

### 1.5.1.2.2 parse_def

具体执行解析读取的内容，读取，并解析。
```c
static int parse_def(snd_config_t *parent, input_t *input, int skip, int override)
{
    char *id = NULL;
    int c;
    int err;
    snd_config_t *n;
    enum {MERGE_CREATE, MERGE, OVERRIDE, DONT_OVERRIDE} mode;
    while (1) {
        //读取一个非空字符
        c = get_nonwhite(input);
        if (c < 0)
            return c;
        //比如通常重定义使用的!,即在此实现
        switch (c) {
        case '+':
            mode = MERGE_CREATE;
            break;
        case '-':
            mode = MERGE;
            break;
        case '?':
            mode = DONT_OVERRIDE;
            break;
        case '!':
            mode = OVERRIDE;
            break;
        default:
            mode = !override ? MERGE_CREATE : OVERRIDE;
            unget_char(c, input);
        }
        //读取配置中的字符串，读取到的字符串在id中保存
        //如果遇到'"',则读取两个'"'之间的内容
        //否则读取普通字符，直到遇到' ',',','.','='等特殊的字符为止
        //具体实现见下文分析
        err = get_string(&id, 1, input);
        if (err < 0)
            return err;
        //读取非空白字符
        c = get_nonwhite(input);
        //如果不是'.'则break
        //如果是'.',说明是类似于defaults.pcm.device 0这种
        //需要继续读取
        if (c != '.')
            break;
        if (skip) {
            free(id);
            continue;
        }
        //查找配置树中是否有id
        //如果找到了，则返回0，判断mode的值，
        //通常第一次读取时由于配置树是空的，这里肯定找不到
        if (_snd_config_search(parent, id, -1, &n) == 0) {
            if (mode == DONT_OVERRIDE) {
                skip = 1;
                free(id);
                continue;
            }
            if (mode != OVERRIDE) {
                if (n->type != SND_CONFIG_TYPE_COMPOUND) {
                    SNDERR("%s is not a compound", id);
                    return -EINVAL;
                }
                n->u.compound.join = 1;
                parent = n;
                free(id);
                continue;
            }
            snd_config_delete(n);
        }
        if (mode == MERGE) {
            SNDERR("%s does not exists", id);
            err = -ENOENT;
            goto __end;
        }
        //生成一个复合配置节点,并且添加到parant的配置树链表中。
        //生成配置文件使用的关键信为id
        //具体详见下文分析
        err = _snd_config_make_add(&n, &id, SND_CONFIG_TYPE_COMPOUND, parent);
        if (err < 0)
            goto __end;
        n->u.compound.join = 1;
        parent = n;
    }
    if (c == '=') {
        c = get_nonwhite(input);
        if (c < 0)
            return c;
    }
    if (!skip) {
        if (_snd_config_search(parent, id, -1, &n) == 0) {
            if (mode == DONT_OVERRIDE) {
                skip = 1;
                n = NULL;
            } else if (mode == OVERRIDE) {
                snd_config_delete(n);
                n = NULL;
            }
        } else {
            n = NULL;
            if (mode == MERGE) {
                SNDERR("%s does not exists", id);
                err = -ENOENT;
                goto __end;
            }
        }
    }
    switch (c) {
    case '{':
    case '[':
    {
        char endchr;
        if (!skip) {
            if (n) {
                if (n->type != SND_CONFIG_TYPE_COMPOUND) {
                    SNDERR("%s is not a compound", id);
                    err = -EINVAL;
                    goto __end;
                }
            } else {
                err = _snd_config_make_add(&n, &id, SND_CONFIG_TYPE_COMPOUND, parent);
                if (err < 0)
                    goto __end;
            }
        }
        //这里如果遇到'{',则表示需要递归的解析
        if (c == '{') {
            err = parse_defs(n, input, skip, override);
            endchr = '}';
        } else {
            //如果遇到'['，则表示为一个数组类型的参数，需要逐个去解析
            //详见下文具体分析
            err = parse_array_defs(n, input, skip, override);
            endchr = ']';
        }
        c = get_nonwhite(input);
        if (c != endchr) {
            if (n)
                snd_config_delete(n);
            err = LOCAL_UNEXPECTED_CHAR;
            goto __end;
        }
        break;
    }
    default:
        unget_char(c, input);
        err = parse_value(&n, parent, input, &id, skip);
        if (err < 0)
            goto __end;
        break;
    }
    c = get_nonwhite(input);
    switch (c) {
    case ';':
    case ',':
        break;
    default:
        unget_char(c, input);
    }
      __end:
    free(id);
    return err;
}
```
### 1.5.1.2.2.1 get_string

```c
static int get_string(char **string, int id, input_t *input)
{
    int c = get_nonwhite(input), err;
    if (c < 0)
        return c;
    switch (c) {
    //注意，这些特殊字符里面包括'.'
    //特殊字符返回错误玛
    case '=':
    case ',':
    case ';':
    case '.':
    case '{':
    case '}':
    case '[':
    case ']':
    case '\\':
        return LOCAL_UNEXPECTED_CHAR;
    case '\'':
    //此函数上文已分析国
    //则会读取两个'"'之间的内容,保存在string中
    case '"':
        err = get_delimstring(string, c, input);
        if (err < 0)
            return err;
        return 1;
    default:
        unget_char(c, input);
        //默认情况下返回freestring,即一直读取，直到遇到空格前的字符串
        //详细见下文分析
        err = get_freestring(string, id, input);
        if (err < 0)
            return err;
        return 0;
    }
}
```
### 1.5.1.2.2.1.1 get_freestring

获取连续的字符，并把连续的字符存储到string中。连续字符的意思是连续的字母及数字的字符串，
里面不能包括特殊字符，比如'.',' ','?','='等等，读字符串时遇到这些字符则截断，返回之前的字符串。
```c
static int get_freestring(char **string, int id, input_t *input)
{
    struct local_string str;
    int c;

    //初始化为0，分配字符串大小为64字节
    init_local_string(&str);
    while (1) {
        //读取一个字符
        c = get_char(input);
        //如果返回值<0,正常的原因就是因为到了文件结尾
        //如果不是文件结尾，则是其他未知情况，break掉
        if (c < 0) {
            //此时表示读到文件结尾
            if (c == LOCAL_UNEXPECTED_EOF) {
                //把已经读取到的str拷贝到string中
                *string = copy_local_string(&str);
                //如果第一次就读到了文件结尾，则*string为空
                if (! *string)
                    c = -ENOMEM;
                else
                    c = 0;
            }
            break;
        }
        switch (c) {
        case '.':
            //此处传下的参数id为1，不会进入break分支
            if (!id)
                break;
        case ' ':
        case '\f':
        case '\t':
        case '\n':
        case '\r':
        case '=':
        case ',':
        case ';':
        case '{':
        case '}':
        case '[':
        case ']':
        case '\'':
        case '"':
        case '\\':
        case '#':
            //遇到., ' '等不是正常a-z,0-9这种字符则进行拷贝动作
            //正常拷贝则c为0，拷贝时str还为空则c为错误码
            //拷贝后跳转到_out
            *string = copy_local_string(&str);
            if (! *string)
                c = -ENOMEM;
            else {
                unget_char(c, input);
                c = 0;
            }
            goto _out;
        default:
            break;
        }
        //把读取到的字符添加到str中，所以str会存储着读取到的字符串
        if (add_char_local_string(&str, c) < 0) {
            c = -ENOMEM;
            break;
        }
    }
 _out:
    //释放str内存
    free_local_string(&str);
    return c;
}
```
### 1.5.1.2.2.1.2 _snd_config_search

从配置树中查找一个配置，查找的依据为id,即名字。
如果传入的参数len为负数，则直接比较id,如果len为正数，则表示只希望比较len长度的id。
查找的配置树节点保存在result中。

```c
static int _snd_config_search(snd_config_t *config,
                  const char *id, int len, snd_config_t **result)
{
    snd_config_iterator_t i, next;
    snd_config_for_each(i, next, config) {
        snd_config_t *n = snd_config_iterator_entry(i);
        if (len < 0) {
            //如果len为负数，则直接比较id
            if (strcmp(n->id, id) != 0)
                continue;
        //如果len为正数，则只比较len长度的id
        } else if (strlen(n->id) != (size_t) len ||
               memcmp(n->id, id, (size_t) len) != 0)
                continue;
        //找到匹配一致的则返回当前节点
        if (result)
            *result = n;
        return 0;
    }
    return -ENOENT;
}
```
### 1.5.1.2.2.3 _snd_config_make_add
生成一个配置节点，并且把新生成的配置节点加到配置树的链表中去。
功能与前面介绍的_snd_config_make类似，只不过会添加到配置树链表中
```c
static int _snd_config_make_add(snd_config_t **config, char **id,
                snd_config_type_t type, snd_config_t *parent)
{
    snd_config_t *n;
    int err;
    assert(parent->type == SND_CONFIG_TYPE_COMPOUND);
    err = _snd_config_make(&n, id, type);
    if (err < 0)
        return err;
    n->parent = parent;
    list_add_tail(&n->list, &parent->u.compound.fields);
    *config = n;
    return 0;
}
```
### 1.5.1.2.2.4 parse_array_defs 

解析'[]'数组中多个值，方法时逐个解析数组中内容。

```c
static int parse_array_defs(snd_config_t *parent, input_t *input, int skip, int override)
{
    int idx = 0;
    while (1) {
        int c = get_nonwhite(input), err;
        if (c < 0)
            return c;
        unget_char(c, input);
        if (c == ']')
            return 0;
        //解析数组中的其中一个

        err = parse_array_def(parent, input, idx++, skip, override);
        if (err < 0)
            return err;
    }
    return 0;
}
```
### 1.5.1.2.2.4.1 parse_array_def
解析'['中数组的内容，如果'[]'之间有'{}',则继续递归解析，
如果有'[]'则表示数组中有数组，也需要递归解析。
最终都需要使用parse_value来解析,其中的id即为数组的索引
```c
static int parse_array_def(snd_config_t *parent, input_t *input, int idx, int skip, int override)
{
    char *id = NULL;
    int c;
    int err;
    snd_config_t *n = NULL;

    if (!skip) {
        char static_id[12];
        snprintf(static_id, sizeof(static_id), "%i", idx);
        id = strdup(static_id);
        if (id == NULL)
            return -ENOMEM;
    }
    c = get_nonwhite(input);
    if (c < 0) {
        err = c;
        goto __end;
    }
    switch (c) {
    case '{':
    case '[':
    {
        char endchr;
        if (!skip) {
            if (n) {
                if (n->type != SND_CONFIG_TYPE_COMPOUND) {
                    SNDERR("%s is not a compound", id);
                    err = -EINVAL;
                    goto __end;
                }
            } else {
                err = _snd_config_make_add(&n, &id, SND_CONFIG_TYPE_COMPOUND, parent);
                if (err < 0)
                    goto __end;
            }
        }
        //即便在数组中遇到'{'依然要递归处理
        if (c == '{') {
            err = parse_defs(n, input, skip, override);
            endchr = '}';
        } else {
            //数组里面可以嵌套数组，需要递归处理
            err = parse_array_defs(n, input, skip, override);
            endchr = ']';
        }
        c = get_nonwhite(input);
        if (c < 0) {
            err = c;
            goto __end;
        }
        if (c != endchr) {
            if (n)
                snd_config_delete(n);
            err = LOCAL_UNEXPECTED_CHAR;
            goto __end;
        }
        break;
    }
    default:
        unget_char(c, input);
        //最终都要走到这里，解析值
        //详见下文分析
        err = parse_value(&n, parent, input, &id, skip);
        if (err < 0)
            goto __end;
        break;
    }
    err = 0;
      __end:
    free(id);
        return err;
}
```
### 1.5.1.2.2.4.1.1 parse_value 

真正去解析配置文件中的某个值，如果是字符串则解析为string类型，
如果是数字则解析为数值。解析完成后把解析出来的节点类型添加到配置树链表中。

```c
static int parse_value(snd_config_t **_n, snd_config_t *parent, input_t *input, char **id, int skip)
{
    snd_config_t *n = *_n;
    char *s;
    int err;

    //获取字符串
    err = get_string(&s, 0, input);
    if (err < 0)
        return err;
    if (skip) {
        free(s);
        return 0;
    }
    //如果正确得到字符串且范围时数字范围
    if (err == 0 && ((s[0] >= '0' && s[0] <= '9') || s[0] == '-')) {
        long long i;
        errno = 0;
        //转换为long long类型
        err = safe_strtoll(s, &i);
        //转换失败
        if (err < 0) {
            double r;
            //转换为double类型
            err = safe_strtod(s, &r);
            if (err >= 0) {
                free(s);
                if (n) {
                    if (n->type != SND_CONFIG_TYPE_REAL) {
                        SNDERR("%s is not a real", *id);
                        return -EINVAL;
                    }
                } else {
                    //生成配置节点，并添加到配置树链表
                    //类型为double
                    err = _snd_config_make_add(&n, id, SND_CONFIG_TYPE_REAL, parent);
                    if (err < 0)
                        return err;
                }
                n->u.real = r;
                *_n = n;
                return 0;
            }
        } else {
            free(s);
            if (n) {
                if (n->type != SND_CONFIG_TYPE_INTEGER && n->type != SND_CONFIG_TYPE_INTEGER64) {
                    SNDERR("%s is not an integer", *id);
                    return -EINVAL;
                }
            } else {
                if (i <= INT_MAX)
                    //整数类型节点
                    err = _snd_config_make_add(&n, id, SND_CONFIG_TYPE_INTEGER, parent);
                else
                    //长整型数字节点
                    err = _snd_config_make_add(&n, id, SND_CONFIG_TYPE_INTEGER64, parent);
                if (err < 0)
                    return err;
            }
            if (n->type == SND_CONFIG_TYPE_INTEGER)
                n->u.integer = (long) i;
            else
                n->u.integer64 = i;
            *_n = n;
            return 0;
        }
    }
    if (n) {
        if (n->type != SND_CONFIG_TYPE_STRING) {
            SNDERR("%s is not a string", *id);
            free(s);
            return -EINVAL;
        }
    } else {
        //如果是字符串类型,则生成string类型节点
        err = _snd_config_make_add(&n, id, SND_CONFIG_TYPE_STRING, parent);
        if (err < 0)
            return err;
    }
    free(n->u.string);
    n->u.string = s;
    *_n = n;
    return 0;
}
```
至此,`snd_config_load`函数流程完成。`snd_config_load`通过逐个字符读取配置文件，
遇到字符串则解析为字符串，遇到数字则解析为数字，遇到'{'则递归解析，遇到'['则按照数组逐个解析，
并且'{','['均可嵌套，此时同样需要递归解析。每解析完成一个则生成一个配置节点，并添加到配置树链表中。
从顶层的配置树入口，即可访问整个配置数。

再次回到`snd_config_update_r`函数，在调用`snd_config_load`把配置文件加载解析为配置树之后，
剩下的另一个重要函数为`snd_config_hooks`。由于篇幅原因，`snd_config_hooks`将在下一篇分析。
