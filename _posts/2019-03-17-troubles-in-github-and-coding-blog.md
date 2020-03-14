---
layout: post
title:  "github无法被百度收录解决笔记" 
date:   2019-03-17 18:42:00
categories: 笔记心得
tags: 笔记 github blog troubles
excerpt: 解决github博客无法被百度收录时遇到的一些问题,同时包含jekyll下使用liveRe评论系统的方法
mathjax: true
---

由于github禁止了百度爬虫，所以在github上搭建的博客内容就无法被百度收录了。解决这个问题的方法有很多，
我采用的方式是在coding上做一个镜像，让百度去去爬coding上的内容，在DNS解析的时候把国内访问统统指向coding,把国外访问指向github。
这个方法的实现方式网上也有很多讨论跟教程，在这里不做过多介绍，只说一下大致思路:

- 在coding上新建帐号，开启Page服务
- 创建工程选择从github导入
- 在DNS解析那里设定国内(或者指定baidu)访问到coding的Page,国外访问到github。

其中在我自己实现时遇到了几个问题，总结在下面:

1. 对大部分博客来说，面向的读者都是国内用户，在coding上做镜像其实相当于重新在coding上了部署了博客，github上相当于做了一个安全备份。
2. coding与github的Page功能几乎完全一致，甚至有些地方还做了简化处理，比如绑定自己域名。
3. 之前github博客没有绑定我自己的域名，因为使用github.io也挺简洁的。但是如果想实现在coding上做镜像让百度去爬coding内容这个功能的话，
就必须绑定自己的域名。否则百度爬的是coding.me，相当于与自己github内容完全一致的另一个网站。
4. github上绑定自己域名的方法是在自己博客项目的根目录下创建一个CNAME的文件，并在文件中写入自己的博客域名即可。如下图所示，
我的域名为blog.whatsroot.xyz,所以在CNAME中写入blog.whatsroot.xyz即可。
![]({{site.url}}assets/codingBlog/githubCNAME.png)
5. coding上绑定自己的域名只需要打开Page服务的设置选项,在绑定新域名处添加自己的域名即可。
6. 此时可以设置DNS解析，我使用的是ndspod,添加CNAME记录类型，如下图所示:
![]({{site.url}}assets/codingBlog/dnspod.png)
6. github上的Page服务默认是可以使用https访问的，coding上访问https则需要申请SSL证书，申请方法是点击Page服务的设置，在**SSL/TLS 安全证书**节中，点击申请即可。
这里需要特别注意，由于在第6步中设置国内跟国外指向了不同的Page，会导致coding在验证的时候得到两个ip地址，从而导致申请失败，
解决方法是去DNS解析那里暂停掉github的解析，等申请SSL证书成功后再启用即可。申请成功后有三个月有效期，到期后需要手动再次申请。
7. coding跟github均可以使用https访问之后可以去githunb以及coding设置强制使用https连接。
8. 由于disqus在国内无法使用，所以趁这次直接把评论系统修改了来必力(LiveRe)，由于我是用了[HyG](https://github.com/Gaohaoyang)的模板，
所以处理起来只需要把原来的duoshuo代码替换为来必力即可。
对于之前未安装过评论系统的用户可参照这里[jekyll + disqus的安装方法](https://poanchen.github.io/blog/2017/07/27/how-to-add-disqus-to-your-jekyll-site)
来实现 keyll + LiveRe(来必力)。
9. 使用百度统计或者google分析时需要添加站点地图，jekyll添加sitemap也很简单，参考[github page的方法](https://help.github.com/en/articles/sitemaps-for-github-pages),
只要在_config.yml文件中添加sitemap插件即可，如下:
```
plugins:
  - jekyll-sitemap
```
10. 如果之前已经使用了jekyll的插件，再添加插件时只需要按照上面的格式继续添加就好了，比如我之前已经使用了jekyll-paginate,并且有用到`paginate: 6`这个参数，
则两个插件同时使用时，如下即可:
```
plugins:
  - jekyll-sitemap
  - jekyll-paginate
paginate: 6
```
