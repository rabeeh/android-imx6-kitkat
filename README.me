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
Assuming you have downloaded 
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
10. Manuall patch kernel_imx -
   cd kernel_imx
   git am <git tree location>/android-imx6-kitkat/kernel_imx/*
   cd ..
9. source build/envsetup.sh
10. Config Android by either 'lunch cuboxi-eng' or 'choosecombo'
11. make

Things that are not working / tested
------------------------------------
The following list is known not to work in very early testing. More
things are probably not working.
This list will be removed and github issue tracking should be used instead.
1. WiFi and BT using brcm80211 driver are not integrated (i.e. no wifi/bt)
2. 512MByte memory is not tested (zswap and zbud are alreday part of the kernel)
3. There is a memory leak in LK 3.10.30; unclear where it's coming from.
   This memory leak happens when opening closing the vpu multiple times.
4. HDMI audio not correctly identified by tinyalsa. Hack to force card=1 is implemented.
5. HDMI CEC
6. Soft keyboard doesn't show when there is no HW keyboard.
7. Configuring resolution within settings menu
8. Configuring wired Ethernet within settings menu
9. Recoding from a UVC camera creates larger than expected file.
