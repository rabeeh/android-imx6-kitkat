#!/bin/bash

# Tool to flash SD card.
# Based on tool from Freescale

set -e
#set -x

function wait_for_partition()
{
	set +e
	while [ 1 ]; do
		BLOCK=`echo ${node} | cut -f3 -d'/'`
		echo "Rescanning $BLOCK"
		echo 1 > /sys/block/$BLOCK/device/rescan
		hdparm -z ${node}
		if [ $? -eq 0 ]; then
			break
		fi
		sleep 1
	done
	set -e
}
# partition size in MB
BOOTLOAD_RESERVE=8
BOOT_ROM_SIZE=8
SYSTEM_ROM_SIZE=736
CACHE_SIZE=512
RECOVERY_ROM_SIZE=8
VENDER_SIZE=8
MISC_SIZE=8

help() {

bn=`basename $0`
cat << EOF
usage $bn <option> device_node

options:
  -h				displays this help message
  -s				only get partition size
  -np 				not partition.
  -f 				flash android image.
EOF

}

# check the if root?
userid=`id -u`
if [ $userid -ne "0" ]; then
	echo "you're not root?"
	exit
fi


# parse command line
moreoptions=1
node="na"
cal_only=0
flash_images=0
not_partition=0
not_format_fs=0
while [ "$moreoptions" = 1 -a $# -gt 0 ]; do
	case $1 in
	    -h) help; exit ;;
	    -s) cal_only=1 ;;
	    -f) flash_images=1 ;;
	    -np) not_partition=1 ;;
	    -nf) not_format_fs=1 ;;
	    *)  moreoptions=0; node=$1 ;;
	esac
	[ "$moreoptions" = 0 ] && [ $# -gt 1 ] && help && exit
	[ "$moreoptions" = 1 ] && shift
done

if [ ! -e ${node} ]; then
	help
	exit
fi


# call sfdisk to create partition table
# get total card size
seprate=40
total_size=`sfdisk -s ${node}`
total_size=`expr ${total_size} / 1024`
boot_rom_sizeb=`expr ${BOOT_ROM_SIZE} + ${BOOTLOAD_RESERVE}`
extend_size=`expr ${SYSTEM_ROM_SIZE} + ${CACHE_SIZE} + ${VENDER_SIZE} + ${MISC_SIZE} + ${seprate}`
#data_size=`expr ${total_size} - ${boot_rom_sizeb} - ${RECOVERY_ROM_SIZE} - ${extend_size} + ${seprate}`
data_size=`expr ${total_size} - ${boot_rom_sizeb} - ${RECOVERY_ROM_SIZE} - ${extend_size} - 20`

# create partitions
if [ "${cal_only}" -eq "1" ]; then
cat << EOF
BOOT   : ${boot_rom_sizeb}MB
RECOVERY: ${RECOVERY_ROM_SIZE}MB
SYSTEM : ${SYSTEM_ROM_SIZE}MB
CACHE  : ${CACHE_SIZE}MB
DATA   : ${data_size}MB
MISC   : ${MISC_SIZE}MB
EOF
exit
fi

function format_android
{
    TMP_FILE=`mktemp`
    TMP="${TMP_FILE}.dir"
    echo "formating android images"
    mkdosfs ${node}1 -n boot
    mkfs.ext4 ${node}4 -Ldata
    mkfs.ext4 ${node}5 -Lsystem
    mkfs.ext4 ${node}6 -Lcache
    mkfs.ext4 ${node}7 -Lvender
    mkdir $TMP
    mount ${node}4 $TMP
    amount=$(df -k | grep ${node}4 | awk '{print $2}')
    stag=$amount
    stag=$((stag-32))
    kilo=K
    amountkilo=$stag$kilo
    sleep 1s
    umount $TMP
    rm -rf $TMP
    e2fsck -f ${node}4
    resize2fs ${node}4 $amountkilo
}

function flash_android
{
if [ "${flash_images}" -eq "1" ]; then
    TMP_FILE=`mktemp`
    TMP="${TMP_FILE}.dir"
    echo "flashing android images..."

    # Create boot partition and files
    mkdir $TMP
    mount ${node}1 $TMP
#    cp out/target/product/cuboxi/zImage $TMP
#    cp out/target/product/cuboxi/*.dtb $TMP
    cp out/target/product/cuboxi/uImage $TMP
    mkimage -A arm -O linux -T ramdisk -n 'Android ramdisk' -d out/target/product/cuboxi/ramdisk.img $TMP/ramdisk.img
    cat > $TMP/uEnv.txt << EOF
/* You can comment out and keep the resolution that suites you. For solo single cpu with 512MByte */
/* It is recommended to stay with gpumem=48M and 1280x720M@60 (i.e. 720p resolution) */

ramdisk_addr=0x15000000
resolution=1280x720M@60
mmcargs3=fatload mmc 0:1 \${ramdisk_addr} ramdisk.img; fatload mmc 0:1 0x10800000 uImage; bootm 0x10800000 \${ramdisk_addr}
mmcargs2=setenv bootargs console=ttymxc0,115200 init=/init vmalloc=400M no_console_suspend androidboot.console=ttymxc0 androidboot.hardware=freescale video=mxcfb0:dev=hdmi,\${resolution} \${bootargs_ext}; run mmcargs3
mmcargs=if test \${cpu} = 6SOLO; then setenv bootargs_ext gpumem=64M fbmem=10M; else setenv bootargs_ext; fi; run mmcargs2
EOF
#    cat > $TMP/uEnv.txt << EOF
#/* You can comment out and keep the resolution that suites you. For solo single cpu with 512MByte */
#/* It is recommended to stay with gpumem=48M and 1280x720M@60 (i.e. 720p resolution) */
#
#ramdisk_addr=0x15000000
#resolution=1280x720M@60
#mmcargs3=run autodetectfdt; fatload mmc 0:1 \${ramdisk_addr} ramdisk.img; fatload mmc 0:1 \${fdt_addr} \${fdt_file}; bootz \${loadaddr} \${ramdisk_addr} \${fdt_addr}
#mmcargs2=setenv bootargs console=ttymxc0,115200 init=/init vmalloc=400M no_console_suspend androidboot.console=ttymxc0 androidboot.hardware=freescale video=mxcfb0:dev=hdmi,\${resolution} \${bootargs_ext}; run mmcargs3
#mmcargs=if test \${cpu} = 6SOLO; then setenv bootargs_ext gpumem=64M fbmem=10M; else setenv bootargs_ext; fi; run mmcargs2
#EOF
    sync
    umount $TMP
    rm $TMP_FILE
    rmdir $TMP
    # Copy u-boot
    dd if=out/target/product/cuboxi/SPL of=${node} bs=1k seek=1
    dd if=out/target/product/cuboxi/u-boot.img of=${node} bs=1k seek=42
    dd if=/dev/zero of=${node} bs=512 seek=1536 count=16
    
    dd if=out/target/product/cuboxi/recovery.img of=${node}2
    dd if=out/target/product/cuboxi/system.img of=${node}5
fi
}

if [[ "${not_partition}" -eq "1" && "${flash_images}" -eq "1" ]] ; then
    flash_android
    exit
fi


# destroy the partition table
dd if=/dev/zero of=${node} bs=1024 count=1

wait_for_partition

sfdisk --force -uM -H32 -S32 ${node} << EOF
,${boot_rom_sizeb},b
,${RECOVERY_ROM_SIZE},83
,${extend_size},5
,${data_size},83
,${SYSTEM_ROM_SIZE},83
,${CACHE_SIZE},83
,${VENDER_SIZE},83
,${MISC_SIZE},83
EOF
wait_for_partition
sleep 5
# adjust the partition reserve for bootloader.
# if you don't put the uboot on same device, you can remove the BOOTLOADER_ERSERVE
# to have 8M space.
# the minimal sylinder for some card is 4M, maybe some was 8M
# just 8M for some big eMMC 's sylinder

sfdisk --no-reread -uM ${node} -N1 << EOF
${BOOTLOAD_RESERVE},${BOOT_ROM_SIZE},b
EOF

wait_for_partition
# format the SDCARD/DATA/CACHE partition
part=""
echo ${node} | grep mmcblk || true > /dev/null
if [ "$?" -eq "0" ]; then
	part="p"
fi

format_android
flash_android

echo "Done"

# For MFGTool Notes:
# MFGTool use mksdcard-android.tar store this script
# if you want change it.
# do following:
#   tar xf mksdcard-android.sh.tar
#   vi mksdcard-android.sh 
#   [ edit want you want to change ]
#   rm mksdcard-android.sh.tar; tar cf mksdcard-android.sh.tar mksdcard-android.sh
