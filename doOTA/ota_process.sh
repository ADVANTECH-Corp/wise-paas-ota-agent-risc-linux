#!/bin/bash
deviceprefix=/dev/mmcblk0p
mountpprefix=/media/mmcblk0p
ubootpartno=1
rootpartAno=2
rootpartBno=3
workpartno=4
ubootdevice=${deviceprefix}${ubootpartno}
rootAdevice=${deviceprefix}${rootpartAno}
rootBdevice=${deviceprefix}${rootpartBno}
workdevice=${deviceprefix}${workpartno}
ubootpoint=${mountpprefix}${ubootpartno}
rootApoint=${mountpprefix}${rootpartAno}
rootBpoint=${mountpprefix}${rootpartBno}
workpoint=${mountpprefix}${workpartno}
OTA_WORK_DIR=${mountpprefix}${workpartno}/ota/work
OTA_LOG_DIR=${mountpprefix}${workpartno}/ota/log
OTA_LOG_FILE=`date +"%Y%m%d%H%M%S"`.log
OTA_LOG_FILE=${OTA_LOG_DIR}/${OTA_LOG_FILE}
partindex=`fw_printenv boot_part | busybox cut -d '=' -f 2`

error_log(){
	echo "$1" >> ${OTA_LOG_FILE}
	exit 1
}
mount_prepare()
{
        umount ${workdevice}
        mount -t ext3  ${workdevice} ${workpoint}
        [ "$?" -ne 0 ] &&  error_log "error: mount failed"
}

if [[ -z $1 ]]; then
cat << EOF
SYNOPSIS:
    $0 {new-bsp-file}

EXAMPLE:
    $0 4221LIV0001_2016-02-29.tar.gz

EOF
    exit 1
fi

#mount_prepare
t1=`echo $1 | busybox cut -d '_' -f 1`
version=`echo ${t1:0-5}`
mkdir -p ${OTA_WORK_DIR}
mkdir -p ${OTA_LOG_DIR}
rm -rf ${OTA_WORK_DIR}/*
touch ${OTA_LOG_FILE}
echo "info: begin: " > ${OTA_LOG_FILE}
echo "info: version: ${version}" >>  ${OTA_LOG_FILE}
echo "info: boot_part: ${partindex}" >>  ${OTA_LOG_FILE}
tar xvf $1 -C ${OTA_WORK_DIR} > /dev/null
[ "$?" -ne 0 ] &&  error_log "error: tar failed" 
cd ${OTA_WORK_DIR}/image
if [ ${partindex} == "0" ];then
	echo "info: current is partA" >> ${OTA_LOG_FILE}
	umount ${rootBdevice}
	echo "info: mkfs.ext3 for rootB" >> ${OTA_LOG_FILE}
	mkfs.ext3 ${rootBdevice}
	[ "$?" -ne 0 ] &&  error_log "error: format rootB failed"
	echo "info: mount rootB" >> ${OTA_LOG_FILE}
	mount -t ext3  ${rootBdevice} ${rootBpoint}
	[ "$?" -ne 0 ] &&  error_log "error: mount rootB failed"
	echo "info: copy files to  rootB" >> ${OTA_LOG_FILE}
	busybox cp -rfa ${OTA_WORK_DIR}/image/rootfs/* ${rootBpoint}/
	[ "$?" -ne 0 ] &&  error_log "error: copy rootB failed"	
elif [ ${version} == "1" ];then
        echo "info: current is partB" >> ${OTA_LOG_FILE}
        umount ${rootAdevice}
	echo "info: mkfs.ext3 for rootA" >> ${OTA_LOG_FILE}
        mkfs.ext3 ${rootAdevice}
        [ "$?" -ne 0 ] &&  error_log "error: format rootA failed"
	echo "info: mount rootA" >> ${OTA_LOG_FILE}
        mount -t ext3  ${rootAdevice} ${rootApoint}
        [ "$?" -ne 0 ] &&  error_log "error: mount rootA failed"
	echo "info: copy files to  rootA" >> ${OTA_LOG_FILE}
        busybox cp -rfa ${OTA_WORK_DIR}/image/rootfs/* ${rootApoint}/
        [ "$?" -ne 0 ] &&  error_log "error: copy rootA failed" 
else
	error_log "error: invalid partition"
fi

rm -rf ${OTA_WORK_DIR}/*
let  newpartindex=($partindex+1)%2
echo "info: will set boot_part to ${newpartindex}" >> ${OTA_LOG_FILE}
fw_setenv boot_part ${newpartindex}
echo "info: success" >> ${OTA_LOG_FILE} 
echo "==============================================" >> ${OTA_LOG_FILE} 
#sync
#reboot
