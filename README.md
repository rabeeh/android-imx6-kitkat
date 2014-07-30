Android KitKat support for CuBox-i and HummingBoard
===================================================

Introduction
------------

This is initial KitKat repository to support CuBox-i and HummingBoard.

The main changes from the beta-2 release are -

1. Android KitKat 4.4.2 based
2. Uses Freescale kk-4.4.2-1.0.0-ga release
3. Uses Freescale LK 3.0.35

Build instructions
------------------
The instructions are mainly tested on Ubuntu 12.04 build machine (64bit)

1. curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
2. chmod a+x ~/bin/repo
3. mkdir myandroid
4. cd myandroid
5. ~/bin/repo init -u https://android.googlesource.com/platform/manifest -b android-4.4.2_r1
6. ~/bin/repo sync
7. source < git tree location >/android-imx6-kitkat/and_patch.sh

   Now you should have the c_patch function available
8. c_patch < git tree location >/android-imx6-kitkat/ imx_kk4.4.2_1.0.0-ga

   imx_kk4.4.2_1.0.0-ga is the name of the branches which will be automatically created

   If everything OK then you should be getting the following message -

   Success: Now you can build the Android code from FSL i.MX6 platform
9. git clone git://git.freescale.com/imx/linux-2.6-imx.git kernel_imx
   cd kernel_imx; git checkout kk4.4.2_1.0.0-ga
   Alternative, until Freescale updates their tree tags, the kernel can be downloaded from -
   http://git.freescale.com/git/cgit.cgi/imx/linux-2.6-imx.git/tag/?id=kk4.4.2_1.0.0-ga
10. Manually patch kernel_imx -
   cd kernel_imx
   git am < git tree location >/android-imx6-kitkat/kernel_imx/3.0.35/*

   cd ..
11. git clone https://github.com/SolidRun/u-boot-imx6 bootable/bootloader/uboot-imx
12. source build/envsetup.sh
13. Config Android build configuration by 'lunch cuboxi-eng', 'lunch cuboxi-user'  or 'choosecombo'
14. make

Flashing instructions
---------------------
1. Insert a micro SD into your Linux PC
2. Determine the block device name of your micro SD (for instance /dev/sdc)
3. Make sure all partitions of your micro SD are unmounted
4. In the Android sources tree, run the following command (replace /dev/sdX with your SD card block device)-
5. sudo < git tree location >/tools/create-sdcard.sh -f /dev/sdX
