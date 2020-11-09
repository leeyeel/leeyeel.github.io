---
layout: post
title:  "linux下使用python-jenkins后台提交任务"
date:   2020-07-31 01:56:00
categories: 笔记心得
tags: linux python
excerpt: 本文重点是提供一个后台提交任务及查询的逻辑框架
mathjax: true
---

尽管python-jenkins提供了一系列的API，但是如何组合跟使用这些API特别是处理好排队还是需要费点精力，
这篇笔记是我实际使用中的处理逻辑，不是很友好不过使用过程中还是比较健壮，分享给大家。

### python-jenkins 离线安装

主要用的库就是`python-jenkins`库，目前(2020.07)最新版本是`1.7.0`,官网地址:[https://pypi.org/project/python-jenkins/](https://pypi.org/project/python-jenkins/)。
如果计算机可以联网，直接按照官方介绍的命令安装即可。
在计算机无法联网或者没有安装权限的情况下，安装jenkins要靠一部分运气，祈祷不会缺太多依赖，然后耐心一个一个装好就可以了。
这里提供一个离线状态下安装jenkins的大致思路:

- 根据自己linux发行版的时间选择python-jenkins的版本，比如我的发行版为centos 7,考虑到centos7的发行时间，最新版肯定无法支持，直接选择`0.4.16`版本。
更新的发行版比如ubuntu 19.04 或者ubuntu 20.04 可以尝试新版。

- 新版本的python-jenkins支持更新的API，且与更新的jenkins版本配套，在不使用这些新的API或功能时可忽略这些差异。

- 下载python库的源码编译安装，编译安装时使用`python setup.py install --prefix=/your/path`的方式。由于无法联网，过一段时间后会提示下载某个库超时，
此时可到[https://pypi.org/](https://pypi.org/)搜索提示下载失败的库，根据上面提高的方法选择大致的版本。

- 如果源码库中有`requirements.txt`文件，可先查看此文件，安装文档中提到的依赖库及版本，版本一般按照最低版本安装即可

- 安装依赖时还会出现缺少库，此时耐心根据提示逐个下载安装即可，一定要注意如果安装到固定目录，即安装时使用了`--prefix=/your/path`的话，
记得把安装后的`site-packages`的目录添加到`PYTHONPATH`环境变量中去

- python-jenkins是一定依赖`requests`库的，可以先从此依赖库开始。

- 验证某个库是否安装成功，只需要终端输入python后，使用`import xxxlib`测试是否报错即可。比如安装了`requests`库，则使用`import requests`。

- 某些库安装成功了但是依然提示找不到，这种情况多数是版本冲突，尝试安装其他版本。

### python-jenkins 介绍

python-jenkins的API介绍可参看官方网站:[https://ssbarnea-python-jenkins.readthedocs.io/en/latest/api.html](https://ssbarnea-python-jenkins.readthedocs.io/en/latest/api.html)。需要注意两个概念:

- job
    job是相对较大的概念，表示jenkins对一类工作的统称，一个jenkins上可以创建多个不同的job

- build
    build是个相对较小的概念，表示具体的某一次的构建。

使用python-jenkins的第一布是构造jenkins类:
```
classjenkins.Jenkins(url, username=None, password=None, timeout=<object object>)
```
其中参数`url`,`username`,`password`均为字符串,`timeout`为整型。使用API时如果不清楚参数，可使用浏览器的`F12`功能抓包分析下请求及响应的内容，查看参数.

### 实现逻辑

基于python-jenkins 0.4.16实现，由于这个版本缺少对queue的获取，所以当有多人提交任务或者队列中排队任务较多时，无法获取队列排队任务数。
实际实现时如果队列中有排队的任务，则会一直显示在等待队列中的任务，无法显示队列中还有几个任务，大概需要多久时间执行完毕。
工作的核心内容其实时返回构建当前任务的`build_num`,因为不管是后面的下载工作还是查看构建的信息，最终其实都是通过这个构建号来完成的，
知道了构建号，工作其实已经完成了，后面的下载工作就可以自由发挥了。

```python
import jenkins
import progressbar

jenkins_server_addr = 'http:1.2.3.4'
jenkins_user_name = 'test'
jenkins_password = '123456'
jenkins_job = 'testJob'
jenkins_timeout = 10 * 600

jenkins_server = jenkins.Jenkins(jenkins_server_addr, jenkins_user_name, jenkins_password)

try:
    jobInfo = jenkins_server.get_job_info(jenkins_job)
except Exception,e:
    print('error')
    sys.exit()

jenkins_server.build_job(jenkins_job)
last_build_num = jobInfo['lastBuild']['number']
next_build_num = jobInfo['nextBuildNumber']

if jobInfo['inQueue']:
    wait_build_widgets = ['waiting for the build in the queue:', 'progressbar.Bar('#'), '', progressbar.Timer()]
    wait_build_bar = progressbar.ProgressBar(widgets=wait_build_widgets, maxval = jenkins_timeout * 10).start()
    for i range(jenkins_timeout)
        try:
            build_info = jekins_server.get_build_info(jenkins_job, next_build_num)
        except Exception,e:
            wait_build_bar.update(10 * i + 1)
            time.sleep(1)
            continue
        if depend_info in build_info['actions'][0]['parameters'][0]['value']:
            wait_build_bar.finish()
            break
        next_build_num = build_info['number']
        next_build_num += 1
    build_info = jenkins_server.get_build_info(jenkins_job, last_build_num)
    if build_info['building'] == True:
        wait_build_widgets = ['waiting for the previous buildings: ', progressbar.Bar('#'), '', progressbar.Timer()]
        wait_build_bar = progressbar.ProgressBar(widgets=wait_build_widgets, maxval = jenkins_timeout * 10).start()
        for i in range(jenkins_timeout):
            build_info = jenkins_server.get_build_info(jenkins_job, next_build_num)
            if build_info['building'] = False:
                wait_build_bar.finish()
                break
            else:
                time.sleep(1)
    wait_build_widgets = ['waiting for the current building: ', progressbar.Bar('#'), '', progressbar.Timer()]
    wait_build_bar = progressbar.ProgressBar(widgets=wait_build_widgets, maxval=jenkins_timeout * 10).start()
    for i in range(jenkins_timeout):
        try:
            build_info = jenkins_server.get_build_info(jenkins_job, next_build_num)
        except Exception,e:
            wait_build_bar.update(10 * i  + 1)
            time.sleep(1)
            continue
        wait_build_bar.update(10 * i  + 1)
        if build_info['building'] == True and build_info['duration'] == 0: continue
        if build_info['result'] == 'SUCCESS':
            wait_build_bar.finish()
        else:
            print('JENKINS BUILDING FAILED!')
            sys.exit()
        break

return next_build_num
```
