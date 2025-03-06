---
layout: post
title:  "ffmpeg历史垃圾桶中的AVFifoBuffer源码分析"
date:   2023-01-02 13:44:00
categories: 音视频 
tags: ffmpeg
excerpt: ffmpeg n4.4版本的AVFifoBuffer实现源码解析
mathjax: true
---

### AVFifoBuffer历史变更

今天阅读ffmpeg n5.2-dev代码时发现ffplay.c中的AVPacket缓冲队列的实现做了较多改动，原来的AVFifoBuffer已经被新的AVFifo所取代，今后代码中就没有AVFifoBuffer了。

ffplay.c中的AVPacket缓冲在n4.4之前一直使用链表实现的，最早可追溯到上古版本n1.1，链表实现用了十几年,直到2021年 n4.4的时候改用了ffmpeg自己的实现AVFifoBuffer,然后在2022年在n5.1版本中改为了AVFifo，AVFifoBuffer也就用了一年左右的时间就被扫进历史垃圾桶，为了防止被遗忘，今天就以n4.4.3版本分析下AVFifoBuffer源码。

### 源码分析

AVFifoBuffer使用的是环形队列，数据结构定义如下：

```c
typedef struct AVFifoBuffer {
    uint8_t *buffer;//缓冲区地址
    uint8_t *rptr, *wptr, *end;//读指针，写指针，以及尾巴
    uint32_t rndx, wndx;//用于记录写了多少个字节，读了多少个字节
} AVFifoBuffer;
```

可参考下面的示意图：
![]({{site.url}}assets/ffmpeg/avfifobuffer-1.png) 


下面分析他的实现源码，主要是下面的接口：

- av_fifo_alloc
- av_fifo_alloc_array
- av_fifo_free
- av_fifo_freep
- av_fifo_size
- av_fifo_space
- av_fifo_grow
- av_fifo_generic_read
- av_fifo_drain
- av_fifo_generic_peek
- av_fifo_generic_peek_at
- av_fifo_generic_write

下面逐个分析每个接口:

1. av_fifo_alloc

```c
/* 初始化一个 AVFifoBuffer

@参数 size: FIFO的尺寸，实际是FIFO中buffer的大小

@返回值 成功则返回指向 AVFifoBuffer的指针，否则返回NULL

*/

AVFifoBuffer *av_fifo_alloc(unsigned int size)
{
    //可以看出是先分配buffer的内存，然后再分配AVFifoBuffer内存
    //原因可能是考虑到buffer内存有可能会很大，
    //存在更多分配失败的可能，便于错误处理
    //注意av_malloc与malloc的区别，av_malloc会进行内存对齐
    void *buffer = av_malloc(size);
    return fifo_alloc_common(buffer, size);
}

//主要分配AVFifoBuffer本身内存，及部分参数赋值
//独立出此函数，是为了与接下来的av_fifo_alloc_array复用部分代码
//参数buffer表示已分配的buffer指针，size为传入的FIFO大小参数
static AVFifoBuffer *fifo_alloc_common(void *buffer, size_t size)
{
    AVFifoBuffer *f; 
    if (!buffer)
        return NULL;
    f = av_mallocz(sizeof(AVFifoBuffer));
    if (!f) {
        av_free(buffer);
        return NULL;
    }
    f->buffer = buffer;        //size字节的buffer
    f->end    = f->buffer + size;  //buffer一共size个字节，所以end指向了buffer的尾巴
    av_fifo_reset(f);        //部分参数初始化
    return f;
}
void av_fifo_reset(AVFifoBuffer *f)
{
    //初始化参数，此时没有任何数据，所以读指针，写指针与buffer一致
    f->wptr = f->rptr = f->buffer;
    //初始时没读也没写，均为0
    f->wndx = f->rndx = 0;
}
```

2. av_fifo_alloc_array

```c
/**  * 初始化一个AVFifoBuffer，区别是此时的buffer大小不是直接使用size来分配，而是使用单个元素大小乘以元素个数的方式.

* @param nmemb:元素个数

* @param size :单个元素的字节数

* @返回值 成功则返回指向 AVFifoBuffer的指针，否则返回NULL

*/

AVFifoBuffer *av_fifo_alloc_array(size_t nmemb, size_t size)
{
    //先来看av_malloc_array
    void *buffer = av_malloc_array(nmemb, size);
    return fifo_alloc_common(buffer, nmemb * size);
}
//本质还是调用的av_malloc,区别是多了个av_size_mult操作
void *av_malloc_array(size_t nmemb, size_t size)
{
    size_t result;
    //重点看这个函数
    if (av_size_mult(nmemb, size, &result) < 0)
        return NULL;
    return av_malloc(result);
}

//检查两个数字相乘会不会溢出
//因为比较复杂，在正文中分析
static inline int av_size_mult(size_t a, size_t b, size_t *r)
{
    size_t t = a * b;
    /* Hack inspired from glibc: don't try the division if nelem and elsize
     * are both less than sqrt(SIZE_MAX). */
    if ((a | b) >= ((size_t)1 << (sizeof(size_t) * 4)) && a && t / a != b)
        return AVERROR(EINVAL);
    *r = t;
    return 0;
}
```

ffmpeg中如果在内部函数中见到注释，通常开心不起来，因为每个有注释的地方都很复杂。

上面注释表示这段是受glibc的启发，当两个乘数都小于sqrt(SIZE_MAX)时不进行除法操作，为什么不进行除法操作，因为没必要，两个乘数都小于最大值的开方，说明乘积一定小于最大值，同时除法又是个相对耗时的操作，省掉这个除法操作可以提高一点性能。

现在主要看这个判断条件：if ((a | b) >= ((size_t)1 << (sizeof(size_t) * 4)) && a && t / a != b) 这里的后半部分是比较好理解的，a && t / a != b如果a不是0,则用这两个乘积处以其中一个乘数，如果不等于另一个乘数，则说明发生了溢出。

前半部分中先看，size_t的长度与操作系统有关，64位下是8字节，32位下是4字节，这样每个字节8位，这样sizeof(size_t) * 4 就刚好是最大移位距离的一半，((size_t)1 << (sizeof(size_t) * 4))这样就刚好是size_t最大值的平方根。比如64位下，sizeof(size_t)为8, 8×4=32, size_t长度64位，两个1<<32相乘就是1<<64,所以((size_t)1 << (sizeof(size_t) * 4))是size_t最大值的平方根。glibc的方法是，a跟b均小于最大数的平方根就不需要除法，即a跟b至少有一个大于最大树平方根才去做除法，因为size_t是无符号数，直接按位或运算就能判断是否有任何一个数值大于最大数的平方根。

再回到av_fifo_alloc_array，它跟av_fifo_alloc有什么本质区别吗？没有本质的区别，只不过方便了一点点而已，比如我们想分配10k的buffer，我们可以用av_fifo_alloc(10*1024),也可以用av_fifo_alloc_array(10,1024)，区别是av_fifo_alloc_array会进行是否溢出的检查。

3. av_fifo_free 与 av_fifo_freep

两者作用一致，av_fifo_freep多了指针置null的操作

```c
void av_fifo_free(AVFifoBuffer *f)
{
    if (f) {
      //释放buffer内存，并把buffer指针置null
      //这里重点看下到底是怎么把buffer指针置null的
        av_freep(&f->buffer);
        av_free(f);      //释放AVFifoBuffer内存
    }
}
//注意这里传入的是个二级指针，即指向指针的指针
void av_freep(void *arg)
{
    void *val;

    memcpy(&val, arg, sizeof(val));
    //这里用到了C99的语法，Compound Literals
    memcpy(arg, &(void *){ NULL }, sizeof(val));
    av_free(val);
}

void av_fifo_freep(AVFifoBuffer **f)
{
    if (f) {
        av_fifo_free(*f);  //调用av_fifo_free
        *f = NULL;      //多了一个指针置null的操作
    }
}
```

这里面主要有几个问题，第一个是av_freep接受的是二级指针，这里为什么参数可以是(void *)而不是(void**)? 首先当然是void*可以指代任何指针，所以可以用void*,为什么不用viod**? 是因为void**就不能指代任何指针，这里只有void*才能兼容一切。

第二个问题是，上面第17行的那段代码是个什么东西？这是个叫compound literals的东西，简单的说就是允许一个匿名的数组或结构，并且这个匿名的数组或结构是个左值，可以取地址。可参考公众号内另一篇《c99 复合字面量介绍》的笔记。总之这句代码就是把指向NULL的，一个指针个长度的数据拷贝到arg，实际就是*arg = NULL,那为甚么还要这样绕来绕去，不干脆使用*arg = NULL？实际上ffmpeg在九年之前的n2.6之前都是用的*arg = NULL这种方式，之所以改成现在的版本，从提交记录上看是为了修复编译器的指针别名冲突问题，但这里我也不懂,后面搞懂了再来介绍。

4. av_fifo_size

```c
/**  * 返回buffer中还有多少字节可以读  */

int av_fifo_size(const AVFifoBuffer *f)
{
    //看图就好了，表示写了还没读的，就是有多少字节可以读
    return (uint32_t)(f->wndx - f->rndx);
}
```

5. av_fifo_space

```c
/** 返回还有多少字节可用来写  */

int av_fifo_space(const AVFifoBuffer *f)
{
    //f->end - f->buffer是buffer的总大小
    //av_fifo_size(f)是多少字节可读，即已经写进去的字节数
    //总的减去已经写进去多少，等于还有多少可以写
    return f->end - f->buffer - av_fifo_size(f);
}
```

6. av_fifo_grow

```c
/**  * 扩充一个AVFifoBuffer.

* 为防止重新分配内存失败, 老的fifo保持不变.

* 扩充大小有一定的规则，所以新的fifo大小可能大于需要的大小.

* @param f :待扩充的AVFifoBuffer

* @param additional_space，需要额外扩充的字节数

 * @return <0 for failure, >=0 otherwise

*/
int av_fifo_grow(AVFifoBuffer *f, unsigned int size)
{
    //old_size实际为原来可用的总空间
    unsigned int old_size = f->end - f->buffer;
    if(size + (unsigned)av_fifo_size(f) < size) //防止超过u32范围
        return AVERROR(EINVAL);
    //入参size为需要扩充的字节数，新的空间大小 = size + 已经写入了的字节数
    size += av_fifo_size(f);

    //比如原来有120字节空间，已经写了30个，希望扩展60个，此时一共需要90个字节，
    //但是原来就有120个了，此时就不需要再扩展了，如果希望扩展100个字节
    //此时一同需要130个字节，原来的空间120个是不够的，则进入重新分配内存的流程
    if (old_size < size)
        //原来的总空间小于扩展后的总空间,则需要重新分配内存
        return av_fifo_realloc2(f, FFMAX(size, 2*old_size));
    //若原来的总空间就比新空间大，则不需要分配内存,直接返回即可
    return 0;
}
```

这里主要关注old_size < size的情况，之所以需要这个判断，大概率还是出于效率的考虑, 这样某些情况下就不需要重新分配内存。重新分配内存的操作见av_fifo_realloc2，先看入参，size与2*old_size之间的最大值，size是已使用的空间加上要扩展的空间大小，old_size是原来总的可用空间，比如原来总的是120个字节，已经写入30个，想要扩展100个，此时size为130，2*old_size为240。也就是说实际扩展到了240个字节，这就是为什么注释中说新的fifo大小可能会大于需要的大小。

为什么要这样扩展？还是效率的问题的，就是为了避免某些情况下频繁的扩容。

```c
//修改AVFifoBuffer的大小
//传入的参数new_size是希望AVFifoBuffer变成的大小
int av_fifo_realloc2(AVFifoBuffer *f, unsigned int new_size)
{
    //之前的总大小
    unsigned int old_size = f->end - f->buffer;
    //通常都是小于new_size,否则的话直接不需要扩容
    if (old_size < new_size) {
        //已经写入的大小，也就是可以读取的大小
        int len          = av_fifo_size(f);
        //按照新的大小分配一个新的
        AVFifoBuffer *f2 = av_fifo_alloc(new_size);
        if (!f2)
            return AVERROR(ENOMEM);
        //把原来f中的已经写入的拷贝到新的buffer中
        av_fifo_generic_read(f, f2->buffer, len, NULL);
        f2->wptr += len;
        f2->wndx += len;
        //这里把原来的buffer释放掉
        av_free(f->buffer);
        //这里直接把新分配的AVFifoBuffer替换掉了原来的AVFifoBuffer，
        //用户看着好像什么都没发生，其实已经被偷偷换成了复制品
        *f = *f2;
        //把AVFifoBuffer本身的内存释放掉，不会影响到buffer
        av_free(f2);
    }
    return 0;
}
```

7. av_fifo_generic_read

```c
/**  

* 从一个AVFifoBuffer中把buffer取出buf_size的长度交给func回调处理，如果func为空就直接复制到dest中  

* @param f:要读取的AVFifoBuffer  

* @param 将要读取的数据大小  

* @param func 用户自定义的回调函数   

* @param dest 目标内存地址  

*/ 
int av_fifo_generic_read(AVFifoBuffer *f, void *dest, int buf_size,
                         void (*func)(void *, void *, int))
{
// Read memory barrier needed for SMP here in theory
    do {
        //取两者之间较小值是为了防止读时越界，
        //这里越界是不要越过0点位置，0点前后分开处理
        //原因是两个地址不一样，需要手动拨回
        int len = FFMIN(f->end - f->rptr, buf_size);
        //只有在func有定义的时候才执行，且跟memcpy是互斥的
        if (func)
            func(dest, f->rptr, len);
        else {
            //直接拷贝len长度数据过去
            memcpy(dest, f->rptr, len);
            //这里只为循环服务，在这里修改dest只是修改入参的副本
            dest = (uint8_t *)dest + len;
        }
// memory barrier needed for SMP here in theory
        //已经拷贝走的数据就读出来扔掉
        av_fifo_drain(f, len);
        //也是为循环服务
        buf_size -= len;
        //如果len等于buf_size,此时循环结束，
        //什么时候buf_size > 0成立？
        //就是f->end - f->rptr，要小于要读取的大小buf_size，
        //即数据越过0边界的s以后，就需要跟多次处理
    } while (buf_size > 0);
    return 0;
}
```

8. av_fifo_drain

```c
/**

* 从AVFifoBuffer读取一定数量的数据然后抛弃掉

* @param f 要读取的AVFifoBuffer

* @param size 要读取的字节数

*/

void av_fifo_drain(AVFifoBuffer *f, int size)
{
    //无法只剩十个字节可读取时还要读取十一个字节，
    //但实际上这行代码只是调试代码，实际中由于编译选项
    //assert-level默认为0，所以av_assert2
    //并没有任何作用，可认为不存在
    av_assert2(av_fifo_size(f) >= size);
    //读指针后移动size个字节
    f->rptr += size;
    //读到边界了或者超过了边界
    if (f->rptr >= f->end)
        //读指针往前移动整个长度
        f->rptr -= f->end - f->buffer;
    //因为是读操作所以加法运算
    f->rndx += size;
}
```

av_fifo_drain这部分代码大概来源于2006年，虽然年代久远，但是基本保持了原来的思路。不要被av_assert2(av_fifo_size(f) >= size)这个判断条件影响到，因为它只存在于开发调试阶段，可以认为它完全不存在。在av_fifo_generic_read中调用av_fifo_drain,由于对size做了限制， 不会有f->rptr 大于f->end的情况，但在直接调用av_fifo_drain时，由于rptr是先移动size个单位，就很难保证他俩的大小关系。这里的

f->rptr -= f->end - f->buffer相当往回拨了一圈。

9. av_fifo_generic_peek

```c
/**

* 从AVFifoBuffer中读取数据进行用户自定义的处理，与av_fifo_gereric_read相似，

* 但是读取之后不会把数据舍弃.

* @param f 待读取的AVFifoBuffer

* @param buf_size 要读取的字节数

* @param func 用户自定义的方法，用于处理读取到的数据

*@param dest 目标数据区域

*/
int av_fifo_generic_peek(AVFifoBuffer *f, void *dest, int buf_size,
                         void (*func)(void *, void *, int))
{
    // Read memory barrier needed for SMP here in theory
    uint8_t *rptr = f->rptr;

    do {
        int len = FFMIN(f->end - rptr, buf_size);
        if (func)
            func(dest, rptr, len);
        else {
            memcpy(dest, rptr, len);
            dest = (uint8_t *)dest + len;
        }
        // memory barrier needed for SMP here in theory
        // 与av_fifo_gereric_read的唯一区别，就是增加的指针的副本，
        // 而不是直接对指针操作
        rptr += len;
        if (rptr >= f->end)
            rptr -= f->end - f->buffer;
        buf_size -= len;
    } while (buf_size > 0);

    return 0;
}
```

上面这段代码与av_fifo_gereric_read流程一致，唯一的区别在18行-20行，av_fifo_drain的操作修改指针本身指向的内容，但这里只是修改了指针的副本，不会影响原指针，即AVFifoBuffer自己并不能意识到自己被读了。

10. av_fifo_generic_peek_at

```c
/**  * 从AVFifoBuffer中读取数据进行用户自定义的处理， 

* 与av_fifo_generic_peek类似， 

* 唯一的区别是可以从指定的偏移量开始读取 

* @param offset：从当前读取位置开始的偏移量

*/


int av_fifo_generic_peek_at(AVFifoBuffer *f, void *dest, int offset, int buf_size, void (*func)(void*, void*, int))
{
    uint8_t *rptr = f->rptr;

    av_assert2(offset >= 0);

    /*
     * *ndx are indexes modulo 2^32, they are intended to overflow,
     * to handle *ndx greater than 4gb.
     */
    av_assert2(buf_size + (unsigned)offset <= f->wndx - f->rndx);

    if (offset >= f->end - rptr)
        rptr += offset - (f->end - f->buffer);
    else
        rptr += offset;

    while (buf_size > 0) {
        int len;

        if (rptr >= f->end)
            rptr -= f->end - f->buffer;

        len = FFMIN(f->end - rptr, buf_size);
        if (func)
            func(dest, rptr, len);
        else {
            memcpy(dest, rptr, len);
            dest = (uint8_t *)dest + len;
        }

        buf_size -= len;
        rptr     += len;
    }

    return 0;
}

```

这个函数从代码风格上看各种无必要的空格，函数内容也无必要，因为用户是很容易通过修改自己的自定义函数来实现这个功能。虽然但是，还是分析一下，首先这两个av_assert2忽略掉，因为不起任何作用。再看下13-14行的处理，offset >= f->end - rptr这个判断是防止offset比当前剩余空间还要大，就认为这时候是因为多了一圈，所以减去了(f->end - f->buffer)，即整个buffer的长度。

11. av_fifo_generic_write

```c
/**
*  经过用户自定义的回调从src读取数据填充到AVFifoBuffer
* @param f 待写的AVFifoBuffer
* @param src：源数据，不能是const指针，因为自定义回调中可能会更改数据
* @param size：即将要写的字节数
* @param func：写回调函数，第一个参数是源，第二个是目标buf，第三个是目标buf字节数
* 函数必须返回写入到目标buf的字节数，如果没有足够的数据可写，返回值 <= 0
* 如果用户自定义回调是空，则直接拷贝src中的数据到AVFifoBuffer
* @返回值: 写到目标buf中的字节数
*/
int av_fifo_generic_write(AVFifoBuffer *f, void *src, int size,
                          int (*func)(void *, void *, int))
{
    int total = size;
    //几乎是读数据的镜像过程
    uint32_t wndx= f->wndx;
    uint8_t *wptr= f->wptr;
    do {
        //f->end - wptr 即为还没被写的空间
        int len = FFMIN(f->end - wptr, size);
        if (func) {
            len = func(src, wptr, len);
            if (len <= 0)
                break;
        } else {
            memcpy(wptr, src, len);
            src = (uint8_t *)src + len;
        }
// Write memory barrier needed for SMP here in theory
        wptr += len;
        if (wptr >= f->end)
            //此时转了一圈，写满了，wptr强制归位
            wptr = f->buffer;
        wndx    += len;
        size    -= len;
    } while (size > 0);
    //这里最后再更新，是为了防止中间处理到一半中断了，虽然并不能从根本上防止
    f->wndx= wndx;
    f->wptr= wptr;
    //如果刚好写完，此时size应为0，total即为最开始的要写入的全部数据
    //当需要写入的空间大于剩余的空间时，size即为剩余的那几个字节，total-size即为已经写入的数据

    return total - size;
}
```

写的过程与读几乎是镜像关系，且更好的诠释了环形buffer的概念，比如整个buffer大小是100字节，此时已经写入10个字节，读了3个字节，我想写404个字节，第一圈执行时FFMIN(f->end - wptr, size)即FFMIN(90,404) 也就是 90,拷贝结束后，wptr += len移动90个字节到f->end处，wptr = f->buffer即初始位置，wndx += len即 3+90=93, size -=len 即404 - 90 = 314，此时size >0 ,继续FFMIN(f->end - wptr, size)即FFMIN(100, 314)也就是100， 拷贝100字节后，wptr +=len 移动100个字节，又到f->end处，wptr = f->buffer即再回初始位置，此时wndx 一直在增加，size此时应为size - len = 314 - 100 = 214, size还是大于0，再进行循环，这样实际404个字节只有最后100个字节，也就是buffer大小被最终保留到AVFifoBuffer中了，其他都被覆盖掉了。


### 其他

首先这是个无锁实现，所以在使用时是需要注意多线程场景的。

注意write及read中的注释，有提到类似`// Write memory barrier needed for SMP here in theory`等理论上需要添加读写内存屏障的提示，但最终代码中没有考虑这个问题，不知道是出于什么原因，关于内存屏障的使用可参考linux kernel 2.6版本中的kfifo，同样这也是我的知识盲区。ffmpeg这个版本的fifo实现还是非常精简且典型的，真正有效的数据只有buffer,rptr,wprt,end四个指针，中间为了性能也做了很多优化，是可以单独移植出来放在自己项目中使用的。下次分析AVFifo的实现。
