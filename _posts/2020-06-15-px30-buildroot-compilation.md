---
layout: post
title:  "rockchip px30 buildroot 编译修改说明"
date:   2020-06-15 01:56:00
categories: 笔记心得
tags: linux 
excerpt: rockchip px30 huildroot 在ubuntu 18.04 编译说明
mathjax: true
---

1. 编译需要`make`,`patchelf`, `wget`, `git`, `curl`等基础软件,也可以在找不到某些命令时根据需要安装.
2. 创建rockchip文件夹,实际目录机构为:
```
	├── app #存放app的目录
	├── buildroot   #buildroot下载目录
	├── external    #存放extern库的目录
	└── kernel  #存放kernel的目录
```	
3. 在rockchip文件夹内下载buildroot:https://github.com/rockchip-linux/buildroot(git@github.com:rockchip-linux/buildroot.git)
4. 在buildroot文件夹内执行menuconfig,查找并关闭:
    - qsetting:路径Target packages --> Rockchip BSP packages --> qsetting;原因是官方库为空(https://github.com/rockchip-linux/qsetting)
    - rkwifibt:路径Target packages --> Rockchip BSP packages --> rkwifibt;原因是找不到bluetooth\_bsa库
3. external

    |  名称 | github地址| git地址
    |  :-|:-|:-| 
    | alsa-config | https://github.com/rockchip-linux/alsa-config | git@github.com:rockchip-linux/alsa-config.git |
    | broadcom_bsa | https://github.com/rockchip-linux/broadcom_bsa | git@github.com:rockchip-linux/broadcom_bsa.git |
    | camera_engine_rkisp | https://github.com/rockchip-linux/camera_engine_rkisp | git@github.com:rockchip-linux/camera_engine_rkisp.git |
    | deviceio_release | https://github.com/rockchip-linux/deviceio_release | git@github.com:rockchip-linux/deviceio_release.git |
    | gstreamer-rockchip | https://github.com/rockchip-linux/gstreamer-rockchip | git@github.com:rockchip-linux/gstreamer-rockchip.git |
    | libmali | https://github.com/rockchip-linux/libmali | git@github.com:rockchip-linux/libmali.git |
    | linux-rga| https://github.com/rockchip-linux/linux-rga | git@github.com:rockchip-linux/linux-rga.git |
    | mpp | https://github.com/rockchip-linux/mpp | git@github.com:rockchip-linux/mpp.git |
    | rkscript| https://github.com/rockchip-linux/rkscript | git@github.com:rockchip-linux/rkscript.git |
    | rktoolkit| https://github.com/rockchip-linux/rktoolkit | git@github.com:rockchip-linux/rktoolkit.git |
    | rkwifibt| https://github.com/rockchip-linux/rkwifibt | git@github.com:rockchip-linux/rkwifibt.git |

4. app

    |  名称 | github地址| git地址
    |  :-|:-|:-| 
    | multivideoplayer | https://github.com/rockchip-linux/multivideoplayer | git@github.com:rockchip-linux/multivideoplayer.git | 
    | qcamera | https://github.com/rockchip-linux/qcamera | git@github.com:rockchip-linux/qcamera.git | 
    | qfm | https://github.com/rockchip-linux/qfm | git@github.com:rockchip-linux/qfm.git | 
    | QLauncher | https://github.com/rockchip-linux/QLauncher | git@github.com:rockchip-linux/QLauncher.git | 
    | qplayer | https://github.com/rockchip-linux/qplayer | git@github.com:rockchip-linux/qplayer.git | 

5. dl

	- acl-2.2.52.src.tar.gz
	- alsa-lib-1.1.5.tar.bz2
	- alsa-plugins-1.1.5.tar.bz2
	- alsa-utils-1.1.5.tar.bz2
	- android-tools\_4.2.2+git20130218-3ubuntu41.debian.tar.gz
	- android-tools\_4.2.2+git20130218.orig.tar.xz
	- attr-2.4.47.src.tar.gz
	- autoconf-2.69.tar.xz
	- automake-1.15.1.tar.xz
	- bash-4.4.12.tar.gz
	- binutils-2.29.1.tar.xz
	- bison-3.0.4.tar.xz
	- busybox-1.27.2.tar.bz2
	- cairo-1.14.10.tar.xz
	- cantarell-fonts-0.0.25.tar.xz
	- ccache-3.3.5.tar.xz
	- coreutils-8.30.tar.xz
	- dejavu-fonts-ttf-2.37.tar.bz2
	- dhcpcd-6.11.5.tar.xz
	- dhry-c
	- dnsmasq-2.78.tar.xz
	- dosfstools-4.1.tar.xz
	- dropbear-2019.78.tar.bz2
	- e2fsprogs-1.43.9.tar.xz
	- eudev-3.2.7.tar.gz
	- evtest-1.33.tar.gz
	- expat-2.2.5.tar.bz2
	- faad2-2.8.8.tar.gz
	- fakeroot\_1.20.2.orig.tar.bz2
	- fatresize-321973ba156bbf2489e82c47c94b2bca74b16316.tar.gz
	- ffmpeg-4.1.3.tar.xz
	- flex-2.6.4.tar.gz
	- font-awesome-v4.7.0.tar.gz
	- fontconfig-2.13.1.tar.bz2
	- frame\_length.diff
	- freetype-2.10.1.tar.xz
	- gawk-4.1.4.tar.xz
	- gcc-8.4.0.tar.xz
	- gettext-0.19.8.1.tar.xz
	- ghostscript-fonts-std-8.11.tar.gz
	- glib-2.54.2.tar.xz
	- glibc-2.29-11-ge28ad442e73b00ae2047d89c8cc7f9b2a0de5436.tar.gz
	- glmark2-9b1070fe9c5cf908f323909d3c8cbed08022abe8.tar.gz
	- gmp-6.1.2.tar.xz
	- gperf-3.0.4.tar.gz
	- gst-plugins-bad-1.14.4.tar.xz
	- gst-plugins-base-1.14.4.tar.xz
	- gst-plugins-good-1.14.4.tar.xz
	- gst-plugins-ugly-1.14.4.tar.xz
	- gstreamer-1.14.4.tar.xz
	- hostapd-2.6.tar.gz
	- i2c-tools-4.0.tar.xz
	- input-event-daemon-v0.1.3.tar.gz
	- intltool-0.51.0.tar.gz
	- iperf-2.0.10.tar.gz
	- iputils-s20161105.tar.gz
	- iw-4.9.tar.xz
	- keyutils-1.5.10.tar.bz2
	- kmod-24.tar.xz
	- libdrm-2.4.89.tar.bz2
	- liberation-fonts-ttf-2.00.1.tar.gz
	- libevdev-1.5.8.tar.xz
	- libevent-2.1.8-stable.tar.gz
	- libffi-3.2.1.tar.gz
	- libgudev-230.tar.xz
	- libinput-1.8.2.tar.xz
	- libjpeg-turbo-2.0.2.tar.gz
	- liblockfile\_1.09-6.debian.tar.bz2
	- liblockfile\_1.09.orig.tar.gz
	- libmad-0.15.1b.tar.gz
	- libmpeg2-0.5.1.tar.gz
	- libnl-3.4.0.tar.gz
	- libogg-1.3.3.tar.xz
	- libpng-1.6.34.tar.xz
	- libpthread-stubs-0.4.tar.bz2
	- libtheora-1.1.1.tar.xz
	- libtool-2.4.6.tar.xz
	- libusb-1.0.21.tar.bz2
	- libvorbis-1.3.5.tar.xz
	- libX11-1.6.7.tar.bz2
	- libXau-1.0.9.tar.bz2
	- libxcb-1.13.tar.bz2
	- libXdmcp-1.1.3.tar.bz2
	- libxkbcommon-0.7.1.tar.xz
	- libxkbfile-1.1.0.tar.bz2
	- libxml2-2.9.7.tar.gz
	- libxslt-1.1.29.tar.gz
	- linux-HEAD.tar.gz
	- lmbench-3.0-a9.tgz
	- lockfile-progs\_0.1.17.tar.gz
	- lrzsz-0.12.20.tar.gz
	- lz4-v1.7.5.tar.gz
	- lzip-1.19.tar.gz
	- lzo-2.10.tar.gz
	- m4-1.4.18.tar.xz
	- memtester-4.3.0.tar.gz
	- mesa-17.3.6.tar.xz
	- mpc-1.0.3.tar.gz
	- mpfr-3.1.6.tar.xz
	- mpg123-1.25.2.tar.bz2
	- mtdev-1.1.4.tar.bz2
	- ncurses-6.0.tar.gz
	- ntfs-3g\_ntfsprogs-2017.3.23.tgz
	- ntp-4.2.8p10.tar.gz
	- openssl-1.0.2a-parallel-install-dirs.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d
	- openssl-1.0.2a-parallel-obj-headers.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d
	- openssl-1.0.2a-parallel-symlinking.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d
	- openssl-1.0.2d-parallel-build.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d
	- openssl-1.0.2n.tar.gz
	- parted-3.2.tar.xz
	- patchelf-0.9.tar.bz2
	- pcre2-10.30.tar.bz2
	- pcre-8.41.tar.bz2
	- perl-5.26.1.tar.xz
	- perl-cross-1.1.8.tar.gz
	- pixman-0.34.0.tar.bz2
	- pkgconf-0.9.12.tar.bz2
	- pm-utils-1.4.1.tar.gz
	- procrank\_linux-21c30ab4514a5b15ac6e813e21bee0d3d714cb08.tar.gz
	- Python-2.7.16.tar.xz
	- Python-3.7.4.tar.xz
	- qemu-4.2.0.tar.xz
	- qtbase-everywhere-src-5.12.2.tar.xz
	- qtdeclarative-everywhere-src-5.12.2.tar.xz
	- qtmultimedia-everywhere-src-5.12.2.tar.xz
	- qtquickcontrols-everywhere-src-5.12.2.tar.xz
	- qtsvg-everywhere-src-5.12.2.tar.xz
	- qttools-everywhere-src-5.12.2.tar.xz
	- qtvirtualkeyboard-everywhere-src-5.12.2.tar.xz
	- qtwayland-everywhere-src-5.12.2.tar.xz
	- readline-7.0.tar.gz
	- rebased-v2.6-0001-hostapd-Avoid-key-reinstallation-in-FT-handshake.patch
	- rebased-v2.6-0002-Prevent-reinstallation-of-an-already-in-use-group-ke.patch
	- rebased-v2.6-0003-Extend-protection-of-GTK-IGTK-reinstallation-of-WNM-.patch
	- rebased-v2.6-0004-Prevent-installation-of-an-all-zero-TK.patch
	- rebased-v2.6-0005-Fix-PTK-rekeying-to-generate-a-new-ANonce.patch
	- rebased-v2.6-0006-TDLS-Reject-TPK-TK-reconfiguration.patch
	- rebased-v2.6-0007-WNM-Ignore-WNM-Sleep-Mode-Response-without-pending-r.patch
	- rebased-v2.6-0008-FT-Do-not-allow-multiple-Reassociation-Response-fram.patch
	- rt-tests-1.0.tar.xz
	- SDL2-2.0.7.tar.gz
	- sftpserver-0.2.2.tar.gz
	- SourceHanSansCN.zip
	- sox-14.4.2.tar.bz2
	- squashfs-3de1687d7432ea9b302c2db9521996f506c140a3.tar.gz
	- strace-4.20.tar.xz
	- stress-1.0.4.tar.gz
	- stressapptest-master.tar.gz
	- stress-ng-0.06.15.tar.gz
	- ttf-bitstream-vera-1.10.tar.bz2
	- ttf-inconsolata\_001.010.orig.tar.gz
	- unixbench-master.tar.gz
	- upower-0.99.4.tar.xz
	- usbmount\_0.0.22.tar.gz
	- util-linux-2.31.1.tar.xz
	- util-macros-1.19.1.tar.bz2
	- v4l-utils-1.16.5.tar.bz2
	- wayland-1.14.0.tar.xz
	- wayland-protocols-1.17.tar.xz
	- weston-3.0.0.tar.xz
	- whetstone.c
	- wireless\_tools.30.pre9.tar.gz
	- wpa\_supplicant-2.6.tar.gz
	- xcb-proto-1.13.tar.bz2
	- xkbcomp-1.4.2.tar.bz2
	- xkeyboard-config-2.23.1.tar.bz2
	- XML-Parser-2.44.tar.gz
	- xorgproto-2018.4.tar.bz2
	- xtrans-1.4.0.tar.bz2
	- xz-5.2.3.tar.bz2
	- zip30.tgz
	- zlib-1.2.11.tar.xz

6. make
在buildroot下执行`make`命令即可
