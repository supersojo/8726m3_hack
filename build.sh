#!/bin/bash

# exit on error
set -e

ROOT_DIR=$(pwd)
M3_KERNEL_MIRROR=https://pedode.com/Android/AMLogic/kernel
M3_KERNEL=arm-src-kernel-m3-2012-04-23-15.19-git-ec9b327098.tar.bz2
M3_KERNEL_DIR=m3_kernel

function download()
{
cd $ROOT_DIR
if [ ! -d $M3_KERNEL_DIR ];then
    mkdir $M3_KERNEL_DIR
    wget $M3_KERNEL_MIRROR/$M3_KERNEL
    tar jxvf $M3_KERNEL -C $M3_KERNEL_DIR
fi
}
export ARCH=arm
export CROSS_COMPILE=/opt/gcc49-latest-linaro/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabi/bin/arm-linux-gnueabi-
export MKIMAGE=mkimage
function build()
{
    cd $ROOT_DIR/$M3_KERNEL_DIR
    make meson_reff16_defconfig
    make
    make uImage
    cd $ROOT_DIR
}

function config()
{
    cd $ROOT_DIR/$M3_KERNEL_DIR
    make menuconfig
}
inc_build()
{
    cd $ROOT_DIR/$M3_KERNEL_DIR
    make
    make uImage
    cd $ROOT_DIR
}
#config
#build
inc_build

