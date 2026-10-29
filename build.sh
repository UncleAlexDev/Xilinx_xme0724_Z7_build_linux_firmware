#!/bin/bash

VIVADO_FILES="./vivado-files/vivado-2018-3"
ARTIFACTS_DIR="./vivado-files/artifacts"

chmod +x ./lnx/build.sh
chmod +x ./upload_boot_to_tftp.sh

# follow MAIN() at the end of file

############################################################
function check_vivado_path()
{
    echo ""
    echo "Xilinx PATH:"
    found=0
    XIL_PATH=( $(echo $PATH | tr ":" "\n" | grep -i xilinx | grep -e "bin$" -e "bin/$" | uniq) )
    for dn in ${XIL_PATH[*]} ; do
        XILINXBIN=${dn}
        printf "%-45s" "${XILINXBIN}"
        if [ -d "${XILINXBIN}" ]; then 
            echo " - found"
            found=1
            if [ -x "${XILINXBIN}/bootgen" ]; then
                BOOTGEN="${XILINXBIN}/bootgen"
                if [ -f "${XILINXBIN}/bootgen.bat" ]; then
                    BOOTGEN_BAT="${XILINXBIN}/bootgen.bat"
                fi
            fi
        else
            echo " - not found"
        fi
    done
    echo ""

    if [ ${found} -eq 0 ]; then
        echo "Xilinx binaries is not found in PATH"
        echo ""
        read -p "Press any key to continue"
        exit 1
    fi

    if [ -z ${BOOTGEN} ]; then
        echo "'bootgen' скрипт не найден в каталогах"
        for dn in ${XIL_PATH[*]} ; do
            echo "  - ${dn}/bootgen"
        done
        echo ""
        read -p "Press any key to continue"
        exit 1
    fi

    export XILINXBIN=${XILINXBIN}
    export BOOTGEN=${BOOTGEN}
    export BOOTGEN_BAT=${BOOTGEN_BAT}

    echo "Xilinx Design Tools: ${XILINXBIN}"
    echo "bootgen utilities: "
    echo "  - ${BOOTGEN}"
    echo "  - ${BOOTGEN_BAT}"
}

############################################################
function create_artifacts_dir()
{
    rm -f ${ARTIFACTS_DIR} &> /dev/null
    mkdir -p ${ARTIFACTS_DIR}
    if [ ! -d ${ARTIFACTS_DIR} ]; then
        echo ""
        echo "ERROR: can't create directory for artifacts - \"${ARTIFACTS_DIR}\""
        echo ""
        read -p "Press any key to continue"
        exit 1
    fi
    
    export ARTIFACTS_DIR=$(cd ${ARTIFACTS_DIR}; pwd)
    echo ""
}


############################################################
function check_vivado_files()
{
    DIR="$1"

    create_artifacts_dir

    DN=$(cd ${VIVADO_FILES}; pwd)
    echo "поиск Viavo-файлов в ${dn} ... "
    if [ ! -d "${VIVADO_FILES}" ]; then
        echo "not found"
        echo ""
        read -p "Press any key to continue"
        exit 1
    fi

    # 1.
    printf "%-22s" "-- system-top.dts ... "
    fname_dts=$(find ${DIR} -name "system-top.dts" | grep -v artifacts)
    if [ -z "${fname_dts}" ]; then
        echo "not found"
        read -p "Press any key to continue"
        exit 1
    else
        FN="${fname_dts}"
        echo "OK - ${FN}"
        DN=$(dirname "${fname_dts}")
        rm -f ${ARTIFACTS_DIR}/*.dts* 2>/dev/null
        cp -f ${DN}/*.dts* ${ARTIFACTS_DIR} || exit 1
    fi

    # 2.
    printf "%-22s" "-- bitstream.bit ... "
    fname_bit=( $(find ${DIR} -name "*.bit" | grep -v artifacts) )
    if [ ${#fname_bit[*]} -eq 0 ]; then
        echo "not found"
        read -p "Press any key to continue"
        exit 1
    else
        FN="${fname_bit[0]}"
        echo "OK - ${FN}"
        rm -f ${ARTIFACTS_DIR}/*.bit 2>/dev/null
        cp -f ${FN} ${ARTIFACTS_DIR} || exit 1
        cp -f ${FN} ${ARTIFACTS_DIR}/bitstream.bit || exit 1
    fi

    # 3.
    printf "%-22s" "-- fsbl.bit ... "
    fname_fsbl=( $(find ${DIR} -name "fsbl.elf" | grep -v artifacts) )
    if [ ${#fname_fsbl[*]} -eq 0 ]; then
        echo "not found"
        read -p "Press any key to continue"
        exit 1
    else
        FN="${fname_fsbl[0]}"
        echo "OK - ${FN}"
        rm -f ${ARTIFACTS_DIR}/fsbl.elf 2>/dev/null
        cp -f ${FN} ${ARTIFACTS_DIR} || exit 1
    fi
    echo -e "\nThe Vivado artifacts is collected in folder \n${ARTIFACTS_DIR} \n"
}


############################################################
# MAIN()

check_vivado_path
check_vivado_files "${VIVADO_FILES}"

#-------------------------------------------------

(cd ./lnx ; ./build.sh ${VIVADO_FILES} ${ARTIFACTS_DIR})
if [ $? -ne 0 ]; then
    read -p "Press any key to continue"
    exit 1
fi

#-------------------------------------------------

cat << EOF

Используйте скрипт make_boot_pack.sh для подготовки пакета прошивки.
$ make_boot_pack.sh

Для сетевого конфигурирования xme0724-20 необходимо
скопировать комплект загрузочных файлов на tftp-сервер.
Например так (сервер - 192.168.1.32, /srv/tftp - рабочий каталог tftp-сервера):
$ scp boot_package/* user@192.168.1.32:/srv/tftp/

Или так:
  $ ls -ld BOOT     # убедиться в наличии готового BOOT
  $ scp BOOT/tftp/xme0724-20/* user@192.168.1.32:/srv/tftp/xme0724-20/
(используйте скрипт make_boot_pack.sh для подготовки boot_package)

EOF

echo "done."
read -p "Press any key to continue"
