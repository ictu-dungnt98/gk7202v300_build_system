# gk7202v300_build_system
buildroot + linux kernel + uboot supporting Goke gk7202v300 SoC


# Flashing OpenIPC firmware
sudo chmod 777 /dev/ttyUSB0 && ./burn --chip gk7202v300 --file=../u-boot-gk7202v300-universal.bin --break; picocom -b 115200 --databits 8 --parity n --stopbits 1 --flow n --logfile=log-$(date +%s).txt /dev/ttyUSB0
setenv flashsize 0x800000
mw.b ${baseaddr} 0xff ${flashsize}
loady ${baseaddr}
exec !! sz --ymodem openipc-gk7202v300-lite-8mb.bin
sf probe 0
sf lock 0
sf erase 0x0 ${flashsize}
sf write ${baseaddr} 0x0 ${filesize}


# wifi module - Altobeam 60321