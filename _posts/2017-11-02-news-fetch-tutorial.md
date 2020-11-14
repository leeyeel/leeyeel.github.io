---
layout: post
title:  "linux下calibre使用http代理" 
date:   2017-11-02 12:12:12
categories: 笔记心得
tags: calibre linux ubuntu kindle 代理
excerpt: 利用calibre抓取《经济学人》等杂志并自动推送到kindle
mathjax: true
---
* TOC
{:toc}

前两部分已经设置过的读者直接跳到第三部分阅读即可.

* [1. kindle以及amazon帐号设置](#1) 
这部分主要是为calibre抓取新闻后可以直接推送到kindle,不需要推送到Kindle的用户可以略过此步骤。
* [2.calibre的安装与基本应用](#2)
这部分为calibre基本的应用
* [3.windows以及Linux下代理设置](#3)
这部分主要为如何获取一些被GFW屏蔽掉的内容

<h2 id="1">1.kindle以及amazon帐号设置</h2>    

这部分比较简单，网络上已经有大量优秀的教程，我就不多说了，不知道的搜索一下即可。这里说明几个注意事项:  

1. 在amazon官网绑定自己的设备后，amazon会给你一个'xxx@kinlde.cn'格式的邮箱，发送到这个邮箱的内容会被同步到Kindle设备上。
这个邮箱ID可以自己编辑，只要不跟别人重复即可。记住这个邮箱，后面会用到。

2. 添加的amazon设备只能接受受信任的邮箱的推送，所以我们要在**内容与设备**菜单的**设置**子菜单里把自己的邮箱添加进去。
建议申请个专用的邮箱，比较方便。我申请的是网易邮箱，亲测可用。

3. 到自己的Kindle上登录自己的amazon帐号.


<h2 id="2">2.calibre的基本应用</h2>    

可以直接访问calibre官网进行下载安装，或者参考书伴上的[这个教程](https://bookfere.com/tools#calibre),
Linux用户可能安装速度很慢，嫌弃太慢可以架梯子，不过这又是另一个话题了。

这部分可以参考书伴的这篇文章[Calibre 使用教程之邮件一键推送电子书](https://bookfere.com/post/11.html).
另外，还需要注意一点，如果你使用网易邮箱，默认客户端授权是关闭的，需要开启后才能正常发送邮件。否则calibre会提示你权限问题。
使用网易邮箱时填写的密码是授权码，不是网易邮箱密码，这个需要注意。开启方法参考[网易帮助](http://help.163.com/14/0923/22/A6S1FMJD00754KNP.html).


<h2 id="3">3. windows以及Linux下代理设置</h2>    

windows下参考[Calibre抓取《经济学人》杂志教程](https://www.itengli.com/calibre/)。

Linux下跟windows下类似，大家梯子大部分都用shadowsocks,但是ss是socks5，calibre只支持http代理，因此需要把socks5转为http,
方法可以参考这篇博客[用polipo将shadowsocks转换为http代理](http://blog.csdn.net/zcq8989/article/details/50545078)。
但是有一点需要注意，配置`http_proxy`这个环境变量时，写到.bashrc里我用ubuntu 16.04测试不可行。
所以保险期间推荐直接写到系统环境变量中，在`/etc/profile`文件最后一行添加  

```
http_proxy=http://127.0.0.1:8787
```

后重启系统，使此环境变量生效。重启后启动ss以及polipo,再运行calibre,calibre会自动检测到环境变量生效。
运行calibre后在**Preference**--**Miscellaneous**界面可以看到代理已生效。
![]({{site.url}}assets/calibre/calibre.png)
