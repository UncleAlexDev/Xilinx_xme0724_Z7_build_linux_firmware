#!/bin/bash

echo ""

ROOTFS_ARCH="rootfs.tar.bz2"

EXT2IMG=rootfs.image
EXT2IMG_GZ=${EXT2IMG}.gz
UROOTFS="uRootfs.image.gz"

ROOTFSIMGDIR=/tmp/${EXT2IMG}

function make_rootfs_image()
{
    RDSIZE=$((20*1024))
    BLKSIZE=1024

    echo "-- создание ${EXT2IMG} - size:$RDSIZE..."
    dd if=/dev/zero of=${EXT2IMG} bs=$BLKSIZE count=$RDSIZE 2>/dev/null || return 1
    /sbin/mke2fs -q -F -m 0 -b $BLKSIZE ${EXT2IMG} $RDSIZE || return 1

    echo "-- монтирование \"${EXT2IMG}\" в ${ROOTFSIMGDIR}... "
    sudo umount ${ROOTFSIMGDIR} &>/dev/null
    sudo rm -rf ${ROOTFSIMGDIR} &>/dev/null
    mkdir -p ${ROOTFSIMGDIR} || return 1
    sudo mount -o loop -t ext2 ${EXT2IMG} ${ROOTFSIMGDIR} || return 1

    echo "-- копирование файлов из ${ROOTFS_ARCH} в \"${ROOTFSIMGDIR}\" ... "
    rm -rfv ${ROOTFSIMGDIR}/* &>/dev/null
    sudo tar --directory ${ROOTFSIMGDIR} -xjf ${ROOTFS_ARCH} || return 1

    # debug
    #rm -rf /tmp/rootfs-tmp &>/dev/null
    #mkdir -p /tmp/rootfs-tmp ; sudo cp -rfd ${ROOTFSIMGDIR}/* /tmp/rootfs-tmp/
    #sudo chown -R user:user /tmp/rootfs-tmp/

    #sync
    sudo umount ${ROOTFSIMGDIR}
}

function create_rootfs_image()
{
    echo "-- формирование загрузочного образа из \"${EXT2IMG}\" ... "
set -x
    gzip -k -f -9 -v ${EXT2IMG} || return 1
    mkimage -A arm -T ramdisk -C gzip -d ${EXT2IMG_GZ} -n ${UROOTFS} ${UROOTFS} || return 1
set +x

    echo -e "\ndone:"
    ls -l ${UROOTFS}
}

############################################################
# MAIN()

chmod +x ./creation/build.sh

(cd ./creation ; ./build.sh)
[ $? -ne 0 ] && exit 1

echo "Формирование зарузочного образа файловой системы \"${UROOTFS}\""

echo "-- удаление предыдущих артефактов ..."
rm -fv $EXT2IMG     &>/dev/null
rm -fv $EXT2IMG_GZ  &>/dev/null
rm -fv $UROOTFS     &>/dev/null

echo "-- получение подготовленного комплекта rootfs ..."
cp -fv ./creation/${ROOTFS_ARCH} ${ROOTFS_ARCH} || exit 1

make_rootfs_image   || exit 1
create_rootfs_image || exit 1


