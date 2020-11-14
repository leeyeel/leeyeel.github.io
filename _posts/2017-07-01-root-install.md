---
layout: post
title:  "Linux下安装CERN ROOT全过程"
date:   2014-11-20 16:54:39
categories: 高能物理
tags: cern root install 教程
excerpt: cern root6 的安装教程
mathjax: true
---
* TOC
{:toc}

### 说明

本次更新是因为当前ROOT6已经抛弃原来的`./configure && make`的安装方式,改用cmake安装．所以之前的安装教程不再适用．

如果是新手的话，建议直接从ROOT6开始学习．

本教程的测试系统为Ubuntu 16.04 LTS,如果是其他发行版本，请注意把`apt-get`改为`yum`或其他对应的命令．

以后可能不再更新了，毕竟已经转行．不过有问题的可以直接留言，我会尽量给大家解答．如果没法留言，你可能需要科学上网.

### 准备工作

安装ROOT需要先补充一些依赖的包或库，ROOT官网上详细的列出了具体需要哪些依赖，你可以访问[root-prerequisites](https://root.cern.ch/build-prerequisites)来查看，
网站对不同的系统需要哪些依赖都做作了说明．包括必须包，以及一些可选包．这里保守一些我们把必须包以及可选包全部安装．

如果你的linux发行版是 Fedora 18, 19 and 20; Scientific Linux 5, 6; CentOS 6, 7 :

```bash
sudo yum install git cmake gcc-c++ gcc binutils  libX11-devel \  
         libXpm-devel libXft-devel libXext-devel gcc-gfortran openssl-devel pcre-devel \
         mesa-libGL-devel mesa-libGLU-devel glew-devel ftgl-devel mysql-devel \
         fftw-devel cfitsio-devel graphviz-devel \
         avahi-compat-libdns_sd-devel libldap-dev python-devel \
         libxml2-devel gsl-static
```
如果你的linux发行版是 Ubuntu 10, 12 , 14 and 16:

```bash
sudo apt-get install git dpkg-dev cmake g++ gcc binutils libx11-dev libxpm-dev \
         libxft-dev libxext-dev
         gfortran libssl-dev libpcre3-dev \
         xlibmesa-glu-dev libglew1.5-dev libftgl-dev \
         libmysqlclient-dev libfftw3-dev libcfitsio-dev \
         graphviz-dev libavahi-compat-libdnssd-dev \
         libldap2-dev python-dev libxml2-dev libkrb5-dev \
         libgsl0-dev libqt4-dev
```

其他发行版可以自己看一下上面提供的网址，这里不再重复．

安装好依赖之后就可以下载源文件了，访问[root-downloads](https://root.cern.ch/downloading-root)下载自己喜欢的版本，新手推荐直接下载Pro版本．
点击Pro版本后进入下载页面后，选择`Source distribution`下面的链接，点一下会自动下载．这一段也可以直接依次运行下面的命令,如果速度太慢，换成手动下载试试．

```bash
git clone https://github.com/root-project/root.git $HOME/root
```

### 使用CMAKE安装

原理是首先创建一个root6-build文件夹，然后进入root6-build文件夹后使用cmake指定一些参数，最后make安装．跟`./configure && make `的方式稍有不同，好象是更科学．

```bash
mkdir $HOME/root6-build  && cd $HOME/root6-build  
cmake ../root  
make -j8
```

最后make 的过程可能比较久，视计算机性能而定，如果make的过程没有报错直到结束，则表示一切正常．　
之后运行一下环境变量之后即可打开root．  
```bash
source $HOME/root6-build/bin/thisroot.sh  
root
```

### 其他说明

好像Ubuntu`./configure && make`的安装方法仍然可用，我在Centos7上测试会提示此方法已被弃用．

每次运行root前都要执行一遍source那行命令，如果不想每次都运行，可以把这行写到环境变量里．
```bash
echo
echo '#ROOT'
echo 'source $HOME/root6-build/bin/thisroot.sh' >> $HOME/.bashrc
```
详细安装说明请仔细阅读README.md以及README文件内的INSTALL
