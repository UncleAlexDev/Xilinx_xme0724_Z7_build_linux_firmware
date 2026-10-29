#!/bin/bash

#
# Официальный образ Linux из репозитория Xilinx
# git clone https://github.com/Xilinx/linux-xlnx
#
# используем:
# git clone --branch xilinx-v2023.2 --single-branch --depth 1 https://github.com/Xilinx/linux-xlnx linux-xlnx-v2023.2
# git co tags/xilinx-v2023.2 -b xilinx-v2023.2
#

echo ""


LINUX_ARC="linux-xlnx-branch-v2023.2.tar.bz2"
LINUX_VER="linux-xlnx-v2023.2"

# v2025 не получается использозвать
# "cdns,zynq-gem" - там при загрузке драйвера сети долгий поиск по регистрам mdiobus read-c45 - 40 сек.
# неприемлемо :(
# LINUX_ARC="linux-xlnx-branch-v2025.1.tar.bz2"
# LINUX_VER="linux-xlnx-v2025.1"

LINUX="linux-xlnx"

echo ""

# 0.
if [ ! -d ${LINUX} ]; then
    if [ ! -f ${LINUX_ARC} ]; then
        echo "ERROR: ${LINUX_ARC} NOT FOUND"
        exit 1
    fi

    [ -d ${LINUX} ] && rm -rf ${LINUX}

    echo "unpacking:"
    cmd="tar xfj ${LINUX_ARC}"
    echo "  $ $cmd"
    eval $cmd || exit 1

    if [ ! -d ${LINUX_VER} ]; then
        echo "ERROR: ${LINUX_VER} NOT FOUND"
        echo "(perhaps the archive does not contain the expected version)"
        exit 1
    fi

    mv -v ${LINUX_VER} ${LINUX} || exit 1fi
fi

if [ ! -d "${LINUX}" ]; then
   echo "ERROR: Не найден каталог \"${LINUX}\""
fi

[ ! -f ${LINUX}/.scmversion ] && touch ${LINUX}/.scmversion

#-------------------------------------------------
# 1.
rm -fv ./uImage.bin
#chmod +x ${LINUX}/scripts/*.sh
#set -x

#-------------------------------------------------
# 2.
export CROSS_COMPILE=arm-linux-gnueabihf-
export ARCH=arm

#-------------------------------------------------
# 3.
# make -C ${LINUX} clean
if [ ! -f ${LINUX}/.config ]; then
    make -C ${LINUX} ARCH=arm xilinx_zynq_defconfig
fi

#-------------------------------------------------
# 4.
# optional!  (требуется linux-пакет ncurses)
# make -C ${LINUX} ARCH=arm menuconfig

# правка конфигурации сборки .config

CFGFILE="linux-xlnx/.config"

#-------------------------------------------------
# 5. эти конфиг-опции будут удалены
sed 's/^.*CONFIG_RTC_DRV_PCF8563=[ym].*$/# CONFIG_RTC_DRV_PCF8563 is not set/' -i ${CFGFILE}
sed 's/^.*CONFIG_DVB_CORE=[ym].*$/# CONFIG_DVB_CORE is not set/' -i ${CFGFILE}
sed 's/^.*CONFIG_DVB_NET=[ym].*$/# CONFIG_DVB_NET is not set/' -i ${CFGFILE}
sed 's/^.*CONFIG_MEDIA_DIGITAL_TV_SUPPORT=[ym].*$/# CONFIG_MEDIA_DIGITAL_TV_SUPPORT is not set/' -i ${CFGFILE}

sed 's/^.*CONFIG_CAN=[ym].*$/# CONFIG_CAN is not set/' -i ${CFGFILE}
sed 's/^.*CONFIG_LOCALVERSION_AUTO=[ym].*$/# CONFIG_LOCALVERSION_AUTO is not set/' -i ${CFGFILE}

#-------------------------------------------------
# 6. эти конфиг-опции будут разрешены
sed 's/^.*CONFIG_RTC_DRV_DS1307 .*$/CONFIG_RTC_DRV_DS1307=y/' -i ${CFGFILE}
if ! grep -q "CONFIG_RTC_DRV_DS1307_CENTURY" ${CFGFILE} ; then
    echo "CONFIG_RTC_DRV_DS1307_CENTURY=y" >> ${CFGFILE}
fi

#-------------------------------------------------
# 7. эти конфиг-опции будут изменены
sed 's/CONFIG_BLK_DEV_RAM_SIZE=.*/CONFIG_BLK_DEV_RAM_SIZE=/' -i ${CFGFILE}
sed 's/CONFIG_BLK_DEV_RAM_SIZE=/CONFIG_BLK_DEV_RAM_SIZE=24576/' -i ${CFGFILE}


#-------------------------------------------------
if [ 0 -eq 1 ]; then   # turned off now
    sed 's/^.*CONFIG_DYNAMIC_DEBUG .*$/CONFIG_DYNAMIC_DEBUG=y/' -i ${CFGFILE}
    if ! $(grep -q "CONFIG_DYNAMIC_DEBUG" ${CFGFILE}) ; then
        echo "CONFIG_DYNAMIC_DEBUG=y" >> ${CFGFILE}
    fi

    sed 's/^.*CONFIG_TEST_DYNAMIC_DEBUG .*$/# CONFIG_TEST_DYNAMIC_DEBUG is not set/' -i ${CFGFILE}
    if ! $(grep -q "CONFIG_TEST_DYNAMIC_DEBUG" ${CFGFILE}) ; then
        echo "CONFIG_TEST_DYNAMIC_DEBUG=y" >> ${CFGFILE}
    fi

    sed 's/^.*CONFIG_UIO_DMEM_GENIRQ .*$/CONFIG_UIO_DMEM_GENIRQ=y/' -i ${CFGFILE}
    if ! $(grep -q "CONFIG_UIO_DMEM_GENIRQ" ${CFGFILE}) ; then
        echo "CONFIG_UIO_DMEM_GENIRQ=y" >> ${CFGFILE}
    fi
fi

# 8. Печатает метку времени загрузки ядра Linux
#    (можно отключить закоментировав)
# sed 's/^.*CONFIG_PRINTK_TIME .*$/CONFIG_PRINTK_TIME=y/' -i ${CFGFILE}
# if ! $(grep -q "CONFIG_PRINTK_TIME" ${CFGFILE}) ; then
#     echo "CONFIG_PRINTK_TIME=y" >> ${CFGFILE}
# fi

#-------------------------------------------------
# before last
if ! $(grep -q " esz7/" ./linux-xlnx/drivers/Makefile) ; then
    echo "obj-y				+= esz7/" >> ./linux-xlnx/drivers/Makefile
fi
rm -rf ./linux-xlnx/drivers/esz7/
mkdir -p ./linux-xlnx/drivers/esz7/
cp -fv esz7/*.[ch] ./linux-xlnx/drivers/esz7/
cp -fv esz7/{Kbuild,Makefile} ./linux-xlnx/drivers/esz7/

# calc cpu cores for using
NUM=$(nproc)
echo "-- Cpu cores: ${NUM}"
if [ $NUM -gt 4 ]; then
    [ $NUM -gt 26 ] && NUM=27
    NUM=$((NUM-1))
    MAKEFLAGS+="-j $NUM"
    echo "-- using:     ${NUM}"
    JOBS="-j $NUM"
fi

# make
make $JOBS -C $LINUX UIMAGE_LOADADDR=0x8000 uImage || exit 1

echo -e "\n---------- Build MODULES ----------\n"
make $JOBS -C $LINUX modules || exit 1

ROOTFS_MODULES=../rootfs_modules
rm -rf ${ROOTFS_MODULES} &>/dev/null
make -C ${LINUX} INSTALL_MOD_PATH=${ROOTFS_MODULES} modules_install || exit 1

set +x
echo -e "\n"

#-------------------------------------------------
# end.
ls -lh ${LINUX}/arch/arm/boot/uImage || exit 1

cp -fv ${LINUX}/arch/arm/boot/uImage ./uImage.bin || exit 1

echo ""
