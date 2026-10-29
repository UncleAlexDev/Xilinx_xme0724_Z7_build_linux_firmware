#!/bin/bash

echo $(date +%c)
DATE="$(date +%Y%m%d-%H%M%S)"

echo "looking for BOOT/tftp ... "
if [ ! -d ./BOOT -o ! -d ./BOOT/tftp ]; then
    echo "not found"
    echo -e "\nERROR: bootable files in BOOT is not found\n"
    read -p "Press any key to continue "
    exit 1
fi

BOOT_PACKAGE_DIR="boot_package"
XME0724_DIR="xme0724-20"

if [ -d "${BOOT_PACKAGE_DIR}" ]; then
    rm -rf "${BOOT_PACKAGE_DIR}_2.bak" 1>/dev/null 2>&1
    [ -d "${BOOT_PACKAGE_DIR}_1.bak" ] && mv "${BOOT_PACKAGE_DIR}_1.bak" "${BOOT_PACKAGE_DIR}_2.bak"

    rm -rf "${BOOT_PACKAGE_DIR}_1.bak" 1>/dev/null 2>&1
    mv "${BOOT_PACKAGE_DIR}" "${BOOT_PACKAGE_DIR}_1.bak" || exit 1
fi

######

echo "copy BOOT/tftp to ${BOOT_PACKAGE_DIR} ..."
FIRMWARE_NAME="${XME0724_DIR}-FW-${DATE}"

mkdir -p -v "${BOOT_PACKAGE_DIR}/${XME0724_DIR}" 1>/dev/null || exit 1
cp -rf "BOOT"/tftp/xme0724-20/* "${BOOT_PACKAGE_DIR}/${XME0724_DIR}" || exit 1

mkdir -p -v "${BOOT_PACKAGE_DIR}/${XME0724_DIR}-FW-${DATE}" 1>/dev/null || exit 1
cp -rf "BOOT"/tftp/xme0724-20/* "${BOOT_PACKAGE_DIR}/${XME0724_DIR}-FW-${DATE}" || exit 1

(cd ${BOOT_PACKAGE_DIR} && zip -r -9 -q "${FIRMWARE_NAME}.zip" "${FIRMWARE_NAME}") || exit 1
rm -rf "${BOOT_PACKAGE_DIR}/${FIRMWARE_NAME}" 1>/dev/null 2>&1

######

BACKUP_NAME="${XME0724_DIR}-backup-${DATE}"
echo "make backup ${BOOT_PACKAGE_DIR}/${BACKUP_NAME} ..."
mkdir -p -v "${BOOT_PACKAGE_DIR}/${BACKUP_NAME}/BOOT/" 1>/dev/null || exit 1
mkdir -p -v "${BOOT_PACKAGE_DIR}/${BACKUP_NAME}/${XME0724_DIR}" 1>/dev/null || exit 1
cp -rf BOOT/* "${BOOT_PACKAGE_DIR}/${BACKUP_NAME}/BOOT/" || exit 1
cp -rf "BOOT"/tftp/xme0724-20/* "${BOOT_PACKAGE_DIR}/${BACKUP_NAME}/${XME0724_DIR}" || exit 1
cp -rf "${BOOT_PACKAGE_DIR}/${FIRMWARE_NAME}.zip" "${BOOT_PACKAGE_DIR}/${BACKUP_NAME}/" || exit 1

######

find "${BOOT_PACKAGE_DIR}" -type f -exec chmod 640 {} \; || exit 1
find "${BOOT_PACKAGE_DIR}" -type d -exec chmod 750 {} \; || exit 1

######

echo "packing everything ..."
cd ${BOOT_PACKAGE_DIR} || exit 1
zip -r -9 -q "${BACKUP_NAME}.zip" "${BACKUP_NAME}" || exit 1
[ $? -eq 0 ] && rm -rf "${BACKUP_NAME}" 1>/dev/null
cd ..

ls -l ${BOOT_PACKAGE_DIR}

echo ""
read -p "Press any key to continue "
