Android KitKat support for CuBox-i and HummingBoard
===================================================

Introduction
------------

This is initial KitKat repository to support CuBox-i and HummingBoard.

The main changes from the beta-2 release is that it -

1. Bumps the support to KitKat 4.4.2 based
2. Uses Freescale kk-4.4.2-1.0.0-alpha support
3. Uses Linaro LK 3.10.30, android branch

Build instructions
------------------
1. curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
2. chmod a+x ~/bin/repo
3. mkdir myandroid
4. cd myandroid
5. ~/bin/repo init -u https://android.googlesource.com/platform/manifest -b android-4.4.2_r1
6. ~/bin/repo sync
7. source <git tree location>/android-imx6-kitkat/and_patch.sh

   Now you should have the c_patch function available
8. c_patch <git tree location>/android-imx6-kitkat/ imx_kk4.4.2_1.0.0-alpha

   imx_kk4.4.2_1.0.0-alpha branches is the branch which will be automatically created

   If everything OK then you should be getting the following message -

   Success: Now you can build the Android code from FSL i.MX6 platform
9. git clone https://github.com/linux4kix/linux-linaro-stable-mx6.git -b linux-linaro-lsk-v3.10-android-mx6 kernel_imx
10. Manually patch kernel_imx -

   cd kernel_imx

   git am <git tree location>/android-imx6-kitkat/kernel_imx/*

   cd ..
11. git clone https://github.com/SolidRun/u-boot-imx6 bootable/bootloader/uboot-imx
11. source build/envsetup.sh
12. Config Android by either 'lunch cuboxi-eng' or 'choosecombo'
13. make

Flashing instructions
---------------------
1. Insert a micro SD into your Linux PC
2. Determine the block device name of your micro SD (for instance /dev/sdc)
3. Make sure all partitions of your micro SD are unmounted
4. In the Android sources tree, run the following command (replace /dev/sdX with your SD card block device)-

sudo <git tree location>/tools/create-sdcard.sh -f /dev/sdX
