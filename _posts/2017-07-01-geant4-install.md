---
layout: post
title:  "linux下安装Geant4.10全过程"
date: 2014-10-07 15:12:10
categories: 高能物理
tags: geant4 install 教程
excerpt: geant4 的安装教程
mathjax: true
---
### 说明
这个教程的起因是当初刚入学的时候(14年左右)学习Geant4,加上那时候还没接触过Linux,安装过程耗费了师兄跟我差不多一整天的时间，
之后我又在不同的发行版上安装了多次，踩了好多雷也排了雷，便写了一个安装的过程. 没想到这三年来帮助很多新手安装了Geant4,
同时也不断收到邮件咨询安装过程。
现在已经毕业转行不做科研了，这里做最后一次更新，也尽量写的全面一些，后面还有一些常见问题的解决方法，所以如果安装过程有问题，
请至少先把此教程读一遍,可能就发现解决方法啦.

### 准备工作

Geant4跟ROOT有很多共同的依赖，所以可以首先安装一下ROOT所需的依赖，里面有好多是ROOT需要但是Geant4并不需要的，
如果你有精力可以一个一个挑出来，这里直接全部安装．
(可以访问[root-prerequisites](https://root.cern.ch/build-prerequisites)来查看ROOT的依赖包.)

如果你的linux发行版是 Fedora 18, 19 and 20; Scientific Linux 5, 6; CentOS 6, 7 :
(`$`符号是终端命令提示符，不要把这个符号复制到终端)  
```
$ sudo yum install git cmake gcc-c++ gcc binutils  libX11-devel \  
         libXpm-devel libXft-devel libXext-devel gcc-gfortran openssl-devel pcre-devel \
         mesa-libGL-devel mesa-libGLU-devel glew-devel ftgl-devel mysql-devel \
         fftw-devel cfitsio-devel graphviz-devel \
         avahi-compat-libdns_sd-devel libldap-dev python-devel \
         libxml2-devel gsl-static
```
如果你的linux发行版是 Ubuntu 10, 12 , 14 and 16:

```
$ sudo apt-get install git dpkg-dev cmake g++ gcc binutils libx11-dev libxpm-dev \
         libxft-dev libxext-dev
         gfortran libssl-dev libpcre3-dev \
         xlibmesa-glu-dev libglew1.5-dev libftgl-dev \
         libmysqlclient-dev libfftw3-dev libcfitsio-dev \
         graphviz-dev libavahi-compat-libdnssd-dev \
         libldap2-dev python-dev libxml2-dev libkrb5-dev \
         libgsl0-dev libqt4-dev
```

其他发行版可以自己看一下上面提供的网址，这里不再重复．
除此之外还需要安装cmake,以及X11,需要说明的是10.1.2以后的版本cmake需要3.3版本以上，所以你可以先在终端输入
`cmake --version`看一下cmake版本，如果版本太低的话需要手动安装一个高版本的cmake. X11跟图形显示有关系:

```
$ sudo apt-get install cmake libx11-dev libxext-dev libxtst-dev libxrender-dev libxmu-dev  libxmuu-dev #安装需要的工具
$ sudo apt-get install qt4
```
#### 下载主程序
Geant4需要下载主程序以及数据包，并且数据包要与主程序的版本对应．
下载Geant4的地址[geant4-downloads](http://geant4.cern.ch/support/download.shtml),下载 Source files 中那个GNU or Linux tar format即可，
没错，就是只有三十几M,我第一次安装的时候还以为下载错了．．．下载之后解压到某目录，为了方便，我们直接放在用户home目录下，下载后解压．
并且创建名为geant4-build的文件夹.上面这段可以用下面这段代码实现:
```
$ wget http://geant4.web.cern.ch/geant4/support/source/geant4.10.03.p01.tar.gz -O  $HOME/geant4.10.03.p01.tar.gz #下载源程序
$ cd $HOME
$ tar xvzf geant4.10.03.p01.tar.gz
```

### 下载data文件
data文件是geant4运行所需要的各种数据文件，用户可以在编译的时候用参数指定下载，但是速度可能会很慢，建议直接用浏览器下载好拷贝过去．
下载地址仍然是上面下载主程序的地址[geant4-downloads](http://geant4.cern.ch/support/download.shtml),如果不清楚以后会用到哪些数据文件，
可以把所有数据文件都下载，点击`Data files`下载所有数据文件并解压，新建一个名为data的文件夹并把之后把所有解压后的数据文件移动到data文件夹.

### 使用cmake安装

原理是首先创建一个geant4-build文件夹，然后进入geant4-build文件夹后使用cmake指定一些参数，最后make安装.
注意:如果先要qt界面，确保你的计算机内安装好了qt,懒得一个一个装可以直接:
```
$ sudo apt-get install qt4*
```
下面为安装geant4过程:
```
$ mkidr geant4-build && cd geant4-build
$ cmake  -DCMAKE_INSTALL_PREFIX=$HOME/geant4-install/  -DGEANT4_USE_OPENGL_X11=ON 
\ -DGEANT4_USE_RAYTRACER_X11=ON -DGEANT4_USE_QT=ON 
\ GEANT4_BUILD_MULTITHREADED=ON $HOME/geant4.10.03.p01
$ make -j8
$ make install -j8
```
其中：
`-DCMAKE_INSTALL_PREFIX=$HOME/geant4-install/` 参数表示安装的位置  
`-DGEANT4_USE_OPENGL_X11=ON  -DGEANT4_USE_RAYTRACER_X11=ON` 表示开启图形可视化  
`-DGEANT4_USE_QT=ON` 表示开启Qt（不需要Qt界面的可以不加此参数）  
`GEANT4_BUILD_MULTITHREADED=ON` 为开启多线程  
`$HOME/geant4.10.03.p01` 表示源程序,如果下载的不同版本记得更改为解压后的文件夹名字.  
`make -j8 or make install -j8`中的`-j8`表示八个线程运行．如果计算机有更多核心可用`-j16`或更多．
cmake结束后，如果没有提示错误，终端出现类似如下:
```
--Configuring done
--Generating done
--Build files have been written to: /home/xxx
```
则表示成功

### 运行及栗子

1）以上过程结束后，会在home目录下看到geant4.10.03.p01，geant4-build,geant4-install三个文件夹，把之前准备好的data文件夹移动到geant4.9-install/share/Geant4-10.03下
（可以看到此文件夹下有名为geant4make的文件夹）。

2）进到刚才提到的geant4make文件夹,会看到名为geant4make.sh的文件。
终端切换到目录并执行：
```
$ source geant4make.sh
```
每次使用geant4都必须运行此环境变量，不想每次都运行可以把该命令写到.bashrc中．
```
$ echo 'source $HOME/geant4-install/share/Geant4-10.03.p01/geant4make/geant4make.sh' >> $HOME/.bashrc
```
3)运行栗子
上面前两步执行成功后，可以切换到栗子目录，具体可以在源程序文件夹下找到，里面有有个examples文件夹.
```
$ cd $HOME/geant4.10.03.p01/examples/basic/B1
$ make -j8
```
看到类似:
```
LinkingexampleB1
...Done!
```
表示编译成功
然后终端输入命令：
```
$ exampleB1
```
运行最简单的栗子．

### 其他说明
其他linux发行版比如scientificlinux，fedora，RedHat等，如果不是最新版本，由于自带的软件包版本比较旧或者缺少运行库，可能会提示各种各样的错误，
遇到提示错误一定仔细阅读错误提示,之后去搜索相应的解决办法。这里列举scientificlinux6.5，fedora19出现的问题的解决方法。

安装geant4最可能遇到的问题是X11 Xmu问题，这种问题，如果是Ubuntu 等就按照上面讲过的：
```
$ sudo apt-get install libx11-dev libxext-dev libxtst-dev libxrender-dev libxmu-dev  libxmuu-dev
```
如果是sl,fedora,redhat等就执行 
```
$ sudo yum search X11 | grep Xmu
```
一般会出现：
```
libXmu.i686 : X.Org X11 libXmu/libXmuu runtime libraries
libXmu.x86_64 : X.Org X11 libXmu/libXmuu runtime libraries
libXmu-devel.i686 : X.Org X11 libXmu development package
libXmu-devel.x86_64 : X.Org X11 libXmu development package
```
如果你是64位系统，直接把有 x86_64的装上
```
$ sudo yum install libXmu.x86_64 libXmu-devel.x86_64 
```
即可解决问题，如果无效，可以尝试下面的方法。
```
$ sudo yum install expat-devel mesa* freeglut-devel
$ sudo yum groupinstall “X software Development”
```
(此命令用来解决找不到X11的问题，scientificlinux 下使用 sudo yum install X*)

如有其他问题，欢迎留言，我会尽可能详细的给每个师弟师妹讲清楚.
