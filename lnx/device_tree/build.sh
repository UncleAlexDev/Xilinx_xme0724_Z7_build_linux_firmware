#!/bin/bash
#
# Необходимо скомпилировать Device Tree Sources и получить Device Tree Blob
# Прим.: используется утилита dtc
# - утилита может быть установлена из пакета - apt install -y device-tree-compiler
# - может быть собрана из исходников
#

# Примечание: табуляция в этом файле нужна

echo ""

echo "ARTIFACTS:  ${ARTIFACTS_DIR}"
if [ -z "${ARTIFACTS_DIR}" ]; then
    echo "The artifacts directory is not specified"
    echo ""
    exit 1
fi 

if [ ! -d "${ARTIFACTS_DIR}" ]; then
    echo "The artifacts directory is not found"
    echo ""
    exit 1
fi 

DTBDIR="device_tree_bsp"

ZYNQ_DTSI_FILE="zynq-7000.dtsi"
PL_DTSI_FILE="pl.dtsi"

# follow MAIN() at the end of file


#-------------------------------------------------
function add_local_mac_address()
{
    FN="system-top.dts"
    [ ! -f ${FN} ] && return

    grep -q "local-mac-address" *
    [ $? -eq 0 ] && return

    printf "%-15s - %s " "${FN}" "add mac address ... "
    # 00 0A 35 - Xilinx prefix
    desc='&gem0 {\n	local-mac-address = [00 0A 35 BA AF 80];\n};\n'
    echo -e "\n${desc}" >> ${FN}
    if [ $? -ne 0 ]; then
         echo "FAILED"
         exit 1
    fi
    echo "OK"
}


#-------------------------------------------------
function fix_memory_descr()
{
    FN="system-top.dts"
    [ ! -f "${FN}" ] && return

   NUM=(`sed -n '/memory[:[:blank:]]*{/,/};/{//=;}' ${FN}`)
   [ ${#NUM[*]} -ne 2 ] && return
 
   echo -n "${FN}  - fix memory description ... "
 
   desc='	memory: memory@40000000 {\
 		device_type = "memory";\
 		memory_type = "memory";\
 		reg = <0x0 0x40000000>;\
 	};\n'
 
   ERR=0
   if [ ${#NUM[*]} -eq 2 ]; then
       sed "${NUM[0]},${NUM[1]}d" -i ${FN}
       [ $? -ne 0 ] && ERR=1
       sed "${NUM[0]}i \\${desc}" -i ${FN}
       [ $? -ne 0 ] && ERR=1
   fi
 
   if [ $ERR -ne 0 ]; then
        echo "FAILED"
        exit 1
   fi
   echo "OK"
}

#-------------------------------------------------
function fix_intc_address_cells()
{
    FN="${ZYNQ_DTSI_FILE}"
    [ ! -f "${FN}" ] && return
    RES=$(grep -A1 "interrupt-controller;" ${FN} | grep "address-cells")
    if [ -z "$RES" ]; then
        printf "%-15s - %s " "${FN}" "fix interrupt-controller address cells ... "
        NUM=$(grep -n -o "interrupt-controller;" ${FN} | cut -d':' -f1)
        NUM=$(echo $NUM | tac -s' ')
        for n in ${NUM}; do
            n=$((n+1))
    
            sed "${n}i \\			#size-cells = <1>;" -i ${FN}
            [ $? -ne 0 ] && echo "FAILED" && exit 1
    
            sed "${n}i \\			#address-cells = <1>;" -i ${FN}
            [ $? -ne 0 ] && echo "FAILED" && exit 1
        done
        echo "OK"
    fi
}

#-------------------------------------------------
function fix_old_tags()
{
# fix for:
#   U-Boot 2025.01-gcb52646e468c-dirty (Nov 18 2025 - 10:54:41 +0500)
#   Warning: Device tree includes old 'u-boot,dm-' tags: please fix by 2023.07!

    FN="${ZYNQ_DTSI_FILE}"
    [ ! -f "${FN}" ] && return
    echo -n "${FN} - fix old 'u-boot,dm-' tags ... "
    sed "s/u-boot,dm-pre-reloc;/\/\/u-boot,dm-pre-reloc;/g" -i ${FN}
}

#-------------------------------------------------
function fix_ExtDev_version()
{
    # ExtDevV1-1.0
    FN="${PL_DTSI_FILE}"
    [ ! -f "${FN}" ] && return
    printf "%-15s - %s\n" "${FN}" "change the name ExtDev{xxx} to anon ExtDev"
    # replace similar followed
    #   ExtDevV1_0: ExtDevV1@43c00000
    #   compatible = "xlnx,ExtDevV1-1.0"
    sed "s/ExtDevV.*:/ExtDev:/g" -i ${FN}
    sed "s/ExtDevV.*@/ExtDev@/g" -i ${FN}
    sed "s/\"xlnx,ExtDevV.*\"/\"xlnx,ExtDev\"/g" -i ${FN}
}

#-------------------------------------------------
function add_rtc()
{
    FN="${ZYNQ_DTSI_FILE}"
    [ ! -f "${FN}" ] && return
    grep -q "rtc@68" ${FN}
    [ $? -eq 0 ] && return

    printf "%-15s - %s " "${FN}" "add description for RTC M41T00 ... "
    desc="\t\t\t\trtc@68 { compatible = \"st,m41t00\"; reg = <0x68>; interrupt-parent = <&intc>; interrupts = <0 0x9 0x8>; };"
    NUM=$(sed -n '/i2c0:/,/};/{//!=;}' ${FN} | tail -n1)
    NUM=$((NUM+1))
    sed "${NUM}i \\${desc}" -i ${FN}
    if [ $? -eq 0 ]; then
        echo "OK"
    else
        echo "FAILED"
        exit 1
    fi
}

#-------------------------------------------------
function add_esz7_ads125()
{
    FN="${ZYNQ_DTSI_FILE}"
    [ ! -f "${FN}" ] && return
    grep -q "ads125h01@43c00000" ${FN}
    if [ $? -eq 0 ]; then
        echo "${FN} - found description for ADC ADS125H01 - OK"
    else
        echo -n "${FN}  - add description for ADC ADS125H01 ... "
        desc='		esz7: esz7@43c00000 {\
			compatible = \"esz7,ads125h01\";\
			reg = <0x43c00000 0x40>;\
			interrupts = <0 29 1>, <0 30 1>, <0 31 1>, <0 32 1>;\
			interrupt-parent = <&intc>;\
			version = "Ver. 3.0.2 Oct 22 2026";\
		};\n'

        NUM=$(sed -n '/adc:/,/};/{//=;}' ${FN} | tail -n1)
        NUM=$((NUM+2))
        sed "${NUM}i \\${desc}" -i ${FN}
        if [ $? -eq 0 ]; then
            echo "OK"
        else
            echo "FAILED"
            exit 1
        fi
    fi
}

#-------------------------------------------------
function add_gpio_status_ok()
{
    return 0
    FN="system-top.dts"
    [ ! -f ${FN} ] && return

    if awk '/&gpio0/ {in_block=1} in_block && /status = "okay";/ {found=1; exit} in_block && /\};/ {in_block=0} END {exit !found}' ${FN}; then
        return;
    fi
    printf "%-15s - %s" "${FN}" "add gpio status okay ... "
    desc='&gpio0 {\n    status = "okay";\n};\n'
    echo -e "\n${desc}" >> ${FN}
    if [ $? -ne 0 ]; then
         echo "FAILED"
         exit 1
    fi
    echo "OK"
}

#-------------------------------------------------
function add_gpio_pinctrl()
{
    FN="${ZYNQ_DTSI_FILE}"
    [ ! -f "${FN}" ] && return
    if grep -q "&pinctrl0 " ${FN}; then
        return;
    fi
        printf "%-15s - %s " "${FN}" "add gpio pinctrl ..."
        desc='&pinctrl0 {
	pinctrl_led: xme0724-20-led-mio13 {
		mux {
			function = "gpio0";
			groups = "gpio0_13_grp";
		};
		conf {
			pins = "MIO13";
			io-standard = <1>;  /* LVCMOS 3.3V */
			bias-disable;       /* Сброс Pull-Up в SLCR */
			slew-rate = <0>;    /* Slow */
		};
	};
};\n';
    echo -e "\n${desc}" >> ${FN}
    if [ $? -ne 0 ]; then
         echo "FAILED"
         exit 1
    fi
    echo "OK"
}

#-------------------------------------------------
function add_gpio_leds()
{
    FN="${ZYNQ_DTSI_FILE}"
    [ ! -f "${FN}" ] && return

    if grep -q "compatible = \"gpio-leds\";" ${FN}; then
        return;
    fi
    printf "%-15s - %s " "${FN}" "add gpio leds section ..."
    desc='/ {
    leds {
        compatible = "gpio-leds";
        status = "disabled";                // "okay"
        user_led {
            label = "xme0724_20_led_mio13";
            gpios = <&gpio0 13 0>; 
            default-state = "heartbeat";    // "off"
        };
    };
};\n'
    echo -e "\n${desc}" >> ${FN}
    if [ $? -ne 0 ]; then
         echo "FAILED"
         exit 1
    fi
    echo "OK"
}


############################################################
# MAIN()

echo ""
echo "-- check for 'dtc' utility"
which dtc
if [ $? -ne 0 ]; then
    echo -e "\nERROR: Утилита dtc не обнаружена"
    echo "  - установите из пакета device-tree-compiler (sudo apt install device-tree-compiler)"
    echo "  или"
    echo "  - соберите из исходников (https://github.com/vagrantc/device-tree-compiler/tree/master)"
    exit 1
fi
dtc --version

echo ""
echo "Vivado artifacts: \"${ARTIFACTS_DIR}\""
echo -n "Проверка наличия файла ${ARTIFACTS_DIR}/system-top.dts"
if [ -f "${ARTIFACTS_DIR}/system-top.dts" ]; then
    echo -e " - OK\n"
    rm -rf ${DTBDIR} 2>/dev/null
    mkdir -p ${DTBDIR}
    cp -vf ${ARTIFACTS_DIR}/*.dts* ${DTBDIR}/ || exit 1
    echo ""
else 
    echo " - файл не найден"
    exit 1
fi

ERR=0
if [ ! -f ${DTBDIR}/system-top.dts ]; then
    echo -e "- ${DTBDIR}/system-top.dts - file not found"
    ERR=1
fi

if [ ! -f "${DTBDIR}/${ZYNQ_DTSI_FILE}" ]; then
    echo -e "- ${DTBDIR}/${ZYNQ_DTSI_FILE} - file not found"
    ERR=1
fi

if [ $ERR -ne 0 ]; then
    echo -e "\n-- не найдены нужные файлы"
    echo "Необходимо обеспечить наличие каталога ${DTBDIR}"
    echo "с файлами *.dts/*.dtsi"
    echo ""
    exit 1
fi

###
rm -f ./system.dtb
pushd ${DTBDIR} >/dev/null
echo "cd $(pwd)"
echo ""

rm -f system.dts # странный файл от Vivado 2018 - не нужен 


# some fixes

fix_ExtDev_version
fix_memory_descr
fix_intc_address_cells

add_local_mac_address
add_rtc
add_esz7_ads125
add_gpio_pinctrl
add_gpio_leds
add_gpio_status_ok

# compiling
cmd="gcc -I my_dts -E -nostdinc -I include -undef -D__DTS__ -x assembler-with-cpp -o system.dts system-top.dts"
echo -e "\n$ $cmd"
eval $cmd || exit 1

cmd="dtc -I dts -O dtb -o system.dtb system.dts"
echo -e "\n$ $cmd"
eval $cmd || exit 1

popd > /dev/null
echo ""

if [ -f ${DTBDIR}/system.dtb ]; then
    cp -fv ${DTBDIR}/system.dtb system.dtb || exit 1
fi

ls -l system.dtb
echo ""

exit 0
