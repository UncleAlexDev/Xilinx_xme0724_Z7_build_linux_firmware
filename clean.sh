#!/bin/bash

#rm -rf ./BOOT
rm -rf vivado-files/artifacts
rm -rf boot_package_*.bak

chmod +x lnx/clean.sh
(cd ./lnx ; ./clean.sh)

