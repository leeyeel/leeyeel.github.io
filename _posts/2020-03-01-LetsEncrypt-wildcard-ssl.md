---
layout: post
title:  "LetsEncrypt申请泛域名" 
date:   2020-03-01 20:56:00
categories: 笔记心得
tags: 网络
excerpt: VPS上的上网服务以及申请ssl证书中查阅到的一些文档及方法总结
mathjax: true
---
* TOC
{:toc}

#### 1. certbot客户端申请泛域名
以前用的`acme.sh`客户端，不过这次申请泛域名的时候有个SOURCEIP的参数实在不知道是干嘛的，尝试了好几个都报错，
然后换了certbot,发现这个更简单更方便。

域名就以本网站的域名`whatsroot.xyz`为例。

- 使用git下载客户端:
`git clone https://github.com/certbot/certbot.git`

- 生成证书：
`./certbot-auto certonly --manual --preferred-challenges=dns  --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d *.whatsroot.xyz`

大部分参数的解释`certbot-auto -h`一下就能找到，其中`certonly`表示仅仅获取或更新证书，但是不安装证书, `--manual`表示使用交互模式或使用shell脚本,
`--preferred-challenges`表示使用dns的方式验证域名，在[这里有说明](https://certbot.eff.org/docs/using.html#changing-the-acme-server),Getting certificates章节。
`--server` 的作用是指定证书生产的服务器，[这里有说明](https://certbot.eff.org/docs/using.html#changing-the-acme-server)，在Changing the ACME Server章节有介绍。
注意文档里说，如果使用`--server`指定一个较新的证书颁发机构地址，可能会获取到泛域名证书。所以如果不指定acme-v02而是使用默认的acme-v01就无法获取泛域名？
我没测试，有兴趣的可以测试下。`--agree-tos`是同意ACME服务器的订阅，所以交互的时候还会让你输入Email地址。`-d` 后面即为域名，注意书写格式，表示泛域名。

- 交互过程
上一步回车之后会进入几个交互界面，询问是否可以绑定IP,可能还有让你输入联系的Email等，主要注意的是在类似于`Please deploy a DNS TXT record under the name...`
即需要你在DNS中添加TXT记录这一步，需要先去DNS那里添加一个记录。比如我用的namecheap的DNS，进到域名设置这里添加一个记录，类型选txt，域名填`_acme-challenge`,
之后把下面的那传值填好，保存即可。注意添加域名时只需要填`_acme-challenge`就好了，不要把`_acme-challenge.whatsroot.xyz`全都填上。然后稍等几分钟，
我的namecheap亲测几秒后就可以，国内的可能稍有延迟。之后继续，直到出现"congratulations !..."说明证书申请成功。

#### 2. 自动更新

到目前为止证书申请成功，由于certbot申请泛域名证书时有一步是在dns中添加txt记录，这一步需要手动去DNS提供商那里去添加，所以没法直接添加corntab中直接自动更新。
当然也有解决办法，就是利用DNS提供商那里的API，然后实现自动更新。开启DNS API可能需要申请，
比如我用的namecheap家的还需要账户要大于50刀余额或者近两年消费满50刀才能申请开启,不过即便我开启了API我也没找到具体是哪个API可以直接添加一个txt记录。
实在想使用自动更新的小伙伴可以去看看github上这个项目(https://github.com/ywdblog/certbot-letencrypt-wildcardcertificates-alydns-au)。

手动更新只需要`certbot-auto renew`即可。

#### 3. 安装证书

使用certbot安装证书非常简单，比如我用nginx的话，直接在certbot文件夹下执行:`certbot-auto --nginx`即可,剩下的按照提示来就可以了。
由于申请了泛域名，所以可以给多个域名及二级域名安装证书。安装好证书后，启动nginx，设置好dns在chrome浏览器访问下就能看到是否成功了。

还需要注意:生成的证书默认在`/etc/letsencrypt/live/你的域名/` 文件夹下,同时在`/etc/letsencrypt/live/`目录下有个README文件，可以打开看下，
里面有对各个文件的说明:
```
`[cert name]/privkey.pem`  : the private key for your certificate.
`[cert name]/fullchain.pem`: the certificate file used in most server software.
`[cert name]/chain.pem`    : used for OCSP stapling in Nginx >=1.3.7.
`[cert name]/cert.pem`     : will break many server configurations, and should not be used
```
所以常用的就是证书文件`[cert name]/fullchain.pem`及key文件`[cert name]/privkey.pem`,你的key文件应该保密且备份好。
但是`/etc/letsencrypt/`下的文件在不了解的情况下不要移动，否则可能导致找不到证书。

如果申请了多个证书，想安装某个域名的证书时也可以直接用`certbot-auto --nginx -d your-domain`的方式。

#### 4. github博客

这个博客就是用github pages + Jekyll 搭建的，然后使用了namecheap家的域名。由于github禁止了百度的爬虫，所以在CODING上做了镜像，
使用DNSPod国内IP走CODING，国外IP走github，但是CODING的pages服务升级，个人域名改变，加上namecheap家的DNS服务太弱了，
没法区分国内国外IP，所以没办法添加两条解析,目前使用的为couldflare的免费cdn,效果不明显，且好像没有解决百度搜索的问题。 

#### 5. 一些其他上网服务

能申请证书之后其他在vps上的服务就顺利多了，教程也非常多，就不介绍了。
