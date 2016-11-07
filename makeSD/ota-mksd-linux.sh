#!/bin/bash

PROGNAME=${0##*/}
[ ${PROGNAME/inand/} != $PROGNAME ] && INAND=1
DEVEX="/dev/sdc" && [ ! -z $INAND ] && DEVEX="/dev/mmcblk0"

cat << EOF

Transfer U-Boot & Linux to target device

EOF

if [[ -z $1 ]]; then
cat << EOF
SYNOPSIS:
    $PROGNAME {device node}

EXAMPLE:
    $0 $DEVEX

EOF
    exit 1
fi

[ ! -e $1 ] && echo "Device $1 not found" && exit 1

echo "All data on "$1" now will be destroyed! Continue? [y/n]"
read ans
if [ $ans != 'y' ]; then exit 1; fi

echo 0 > /proc/sys/kernel/printk

echo "[Unmounting all existing partitions on the device ]"

umount $1* &> /dev/null

echo "[Partitioning $1...]"

DRIVE=$1
## Clear partition table
dd if=/dev/zero of=$DRIVE bs=512 count=2 conv=fsync &>/dev/null

## Create partition table
SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`

echo DISK SIZE - $SIZE bytes

CYLINDERS=`echo $SIZE/255/63/512 | bc`

echo CYLINDERS - $CYLINDERS
{
echo ,9,0x0C,*
} | sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE &> /dev/null

mkfs.vfat -F 32 -n "boot" ${DRIVE}1
sync
sleep 1 

## format device [step 2]
tmp=partitionfile
allsectors=$(fdisk -l ${DRIVE} | grep total | awk '{print $8}')
cs=$(${busybox} fdisk -l ${DRIVE}|${busybox} sed -n '4p'|${busybox} cut -d ' ' -f 3)
if [ $cs == "cylinders" ];then
	echo u > $tmp
	echo n>> $tmp
else
	echo n > $tmp
fi
#p2
echo p >> $tmp
echo 2 >> $tmp
echo "" >> $tmp
echo +1280M >> $tmp

echo n >> $tmp
echo p >> $tmp
echo 3 >> $tmp
echo "" >> $tmp
echo +1280M >> $tmp

echo n >> $tmp
echo p >> $tmp
echo 4 >> $tmp
echo "" >> $tmp
echo "" >> $tmp
echo w >> $tmp
${busybox} fdisk ${DRIVE} < $tmp &> /dev/null 
sync
sleep 2
rm $tmp

mkfs.ext3 -L "rootfsA" ${DRIVE}2
mkfs.ext3 -L "rootfsB" ${DRIVE}3
mkfs.ext3 -L "data" ${DRIVE}4

## update the partition from kernel
if [ -x /sbin/partprobe ]; then
    /sbin/partprobe ${DRIVE} &> /dev/null
else
    sleep 1
fi

unset DPART
DPART=`ls -1 ${DRIVE}1 2> /dev/null`
[ -z $DPART ] && DPART=`ls -1 ${DRIVE}p1 2> /dev/null`
[ -z $DPART ] && echo "$DRIVE's partition 1 not found" && exit 1

if ! mount $DPART /mnt &> /dev/null; then
    echo  "Cannot mount $DPART"
    exit 1
fi

echo "[Copy u-boot.img]"
if [ -f ../image/MLO ];then
	cp ../image/MLO  /mnt
fi
cp ../image/u-boot.img /mnt
umount $DPART

DPART=`ls -1 ${DRIVE}2 2> /dev/null`
[ -z $DPART ] && DPART=`ls -1 ${DRIVE}p2 2> /dev/null`
[ -z $DPART ] && echo "$DRIVE's partition 2 not found" && exit 1

echo "[Copying rootfs...]"
if ! mount $DPART /mnt &> /dev/null; then
    echo  "Cannot mount $DPART"
    exit 1
fi

rmdir /mnt/lost+found/
cp -a ../image/rootfs/* /mnt &> /dev/null

#if [ -z $INAND ]; then
# for emmc update usage
    echo "[Copying iNAND upgrate tools...]"
    mkdir /mnt/mk_inand
    cp -a mkinand-linux.sh /mnt/mk_inand/
    mkdir /mnt/image
    cp -a  ../image/u-boot.img   /mnt/image
    mkdir -p /mnt/image/rootfs
    cp -a  ../image/rootfs/*   /mnt/image/rootfs
    if [ -f ../image/adv_boot.bin ];then
	cp ../image/adv_boot.bin  /mnt/image
    fi
    chown -R 0.0 /mnt/*
#fi
sudo sync
umount $DPART

echo 7 > /proc/sys/kernel/printk
echo "[Done]"
