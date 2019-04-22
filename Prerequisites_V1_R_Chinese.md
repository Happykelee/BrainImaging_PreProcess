# 脑部影像数据预处理之**前期准备**（第一版）
**[Linux/Mac OS 系统 & R语言]**  
**编辑时间：2019/04/19**  
**作者：蔡正厅**  

0. 整个安装和运行**基于ubuntu 16.04 LTS**，所以相关的代码和脚本如有问题请自行修改调整。

1. 一开始更新apt-get：
  ```bash
  #!/bin/bash

  sudo apt-get update
  sudo apt-get upgrade
  ```

2. 安装如下的软件和程序包
  * [R](http://cran.r-project.org)  
    安装方法众多，可查看官网相关指南。方便起见可直接使用如下：
  ```bash
  #!/bin/bash

  sudo apt-get install r-base
  ```
  * [R Studio](http://www.rstudio.com)  
      下载相关deb文件，进入所在文件夹输入：
  ```bash
  #!/bin/bash

  sudo apt-get install dpkg-sig # 如果安装请忽略
  gpg --keyserver keys.gnupg.net --recv-keys 3F32EE77E331692F
  dpkg-sig --verify rstudio-1.2.1335-amd64.deb # (需要事先安装dpkg-sig)
  ```
  * [FSL](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation)  
    官网有十分详细的安装指导，不赘述

  * R包安装之前需要确认操作系统是否安装如下程序：  
    libcurl4-openssl-dev  
    libgit2-dev  
    libssl-dev  
    libv8-dev  
  ```bash
  #!/bin/bash

  for i in {libcurl4-openssl-dev,libgit2-dev,libssl-dev,libv8-dev}
  do
    if [ `dpkg -l | grep $i |wc -l` -ne 0 ];then
      echo -e "Already installed： $i"
    else
      sudo apt-get install $i
    fi
  done
  echo -e '\n-------------Done-------------'
  ```
  * R包的安装  
    在R / R Studio中运行如下安装程序：
  ```R
  #!/usr/bin/R

  if (!require(devtools)){install.packages("devtools")}
  install.packages("oro.nifti")
  install.packages("oro.dicom")
  devtools::install_github("muschellij2/fslr")
  devtools::install_github("stnava/cmaker")
  devtools::install_github("stnava/ITKR")
  devtools::install_github("stnava/ANTsR")
  devtools::install_github("muschellij2/extrantsr")
  ```
  * [Cmake](https://cmake.org/)(选择安装)  
    **说明：** ANTs的编译需要通过CMake进行。另外，CMake本身编译很复杂，所以建议直接下载二进制文件，设置环境变量例子如下：
  ```bash
  export PATH=/{YOUR_PATH}/cmake-3.14.0-Linux-x86_64/bin:$PATH
  ```
  * [ANTs](https://stnava.github.io/ANTs/)(选择安装)  
    网站 https://github.com/ANTsX/ANTs/wiki/Compiling-ANTs-on-Linux-and-Mac-OS 中有详细的安装指导
