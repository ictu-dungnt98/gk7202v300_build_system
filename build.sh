#!/bin/bash
# author Dungnt98 - nguyentrongdung0498@gmai.com
# date: 2023/08/09
# script used for building linux distribution running on Goke gk7202v300 SoC.
# References:
#
# - https://bootlin.com/doc/training/buildroot/buildroot-slides.pdf
# - https://bootlin.com/doc/training/buildroot/buildroot-labs.pdf
# - https://0xax.gitbooks.io/linux-insides/content/

echo "Build Script for Linux OS running on Goke GK7202V300 SoC"

working_dir=$PWD

# toolchain
toolchain_dir="toolchain"
cross_compiler="arm-linux-gnueabihf"

#uboot=========================================================
u_boot_dir="uboot_source"
u_boot_config_file=""
u_boot_boot_cmd_file="boot.cmd"
uboot_file="u-boot-sunxi-with-spl.bin"

#linux opt=========================================================
linux_dir="linux_source"
linux_config_file=""
dtb_file="sun8i-v3s-licheepi-zero.dtb"

#buildroot opt=========================================================
buildroot_dir="buildroot_source"
buildroot_config_file=""

#pull===================================================================
pull_toolchain() {
	rm -rf ${working_dir}/${toolchain_dir}
	mkdir -p ${working_dir}/${toolchain_dir}
	cd ${working_dir}/${toolchain_dir}
	ldconfig
	wget https://releases.linaro.org/components/toolchain/binaries/latest-7/arm-linux-gnueabihf/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz &&
		tar xvJf gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz
	if [ ! -d ${working_dir}/${toolchain_dir}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf ]; then
		echo "Error:pull toolchain failed"
		exit 0
	else
		echo "pull toolchain ok"
	fi
}

pull_uboot() {
	rm -rf ${working_dir}/${u_boot_dir} &&
		git clone https://github.com/OpenIPC/u-boot-gk7205v200.git ${working_dir}/${u_boot_dir}
	if [ ! -d ${working_dir}/${u_boot_dir} ]; then
		echo "Error:pull u_boot failed"
		exit 0
	else
		echo "pull u-boot ok"
	fi
}

pull_linux() {
	rm -rf ${working_dir}/${linux_dir} &&
		git clone -b goke-gk7205v200 https://github.com/OpenIPC/linux.git ${working_dir}/${linux_dir}

	if [ ! -d ${working_dir}/${linux_dir} ]; then
		echo "Error:pull linux failed"
		exit 0
	else
		echo "pull linux ok"
	fi
}


pull_buildroot() {
	sudo rm -rf ${working_dir}/${buildroot_dir}
	mkdir -p ${working_dir}/${buildroot_dir}
	cd ${working_dir}/${buildroot_dir}
	wget https://buildroot.org/downloads/buildroot-2023.02.1.tar.gz && tar -xvf buildroot-2023.02.1.tar.gz
	if [ ! -d ${working_dir}/${buildroot_dir}/buildroot-2023.02.1 ]; then
		echo "Error:pull buildroot failed"
		exit 0
	else
		echo "pull buildroot ok"
	fi
}

pull_all() {
	sudo apt-get update
	sudo apt-get install -y autoconf libtool gettext
	sudo apt-get install -y make gcc g++ swig python-dev bc python u-boot-tools bison flex libssl-dev libncurses5-dev unzip mtd-utils
	sudo apt-get install -y libc6-i386 lib32stdc++6 lib32z1
	sudo apt-get install -y libc6:i386 libstdc++6:i386 zlib1g:i386
	sudo apt-get install -y automake autotools-dev build-essential cpio curl file fzf git libncurses-dev lzop rsync wget
	pull_uboot
	pull_linux
	pull_toolchain
	pull_buildroot
}

#clean===================================================================
clean_log() {
	rm -f ${working_dir}/*.log
}

clean_all() {
	clean_log
	clean_uboot
	clean_linux
	clean_buildroot
}
#clean===================================================================

#env===================================================================
update_env() {
	if [ ! -d ${working_dir}/${toolchain_dir}/gcc-linaro-7.4.1-2019.02-i686_arm-linux-gnueabi ]; then
		if [ ! -d ${working_dir}/${toolchain_dir}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf ]; then
			echo "Error:toolchain no found,Please use ./buid.sh pull_all "
			exit 0
		else
			export PATH="$PWD/${toolchain_dir}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin":"$PATH"
		fi
	else
		export PATH="$PWD/${toolchain_dir}/gcc-linaro-7.4.1-2019.02-i686_arm-linux-gnueabi/bin":"$PATH"
	fi

}
check_env() {
	if [ ! -d ${working_dir}/${toolchain_dir} ] ||
		[ ! -d ${working_dir}/${u_boot_dir} ] ||
		[ ! -d ${working_dir}/${buildroot_dir} ] ||
		[ ! -d ${working_dir}/${linux_dir} ]; then
		echo "Error:env error,Please use ./buid.sh pull_all"
		exit 0
	fi
}

#uboot=========================================================
clean_uboot() {
	cd ${working_dir}/${u_boot_dir}
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- mrproper >/dev/null 2>&1
}

build_uboot() {
	cd ${working_dir}/${u_boot_dir}
	echo "Building uboot ..."
	echo "--->Configuring ..."
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- ${u_boot_config_file} >/dev/null 2>&1
	if [ $? -ne 0 ] || [ ! -f ${working_dir}/${u_boot_dir}/.config ]; then
		echo "Error: .config file not exist"
		exit 1
	fi
	echo "--->Get cpu info ..."
	proc_processor=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)
	echo "--->Compiling ..."
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- -j${proc_processor} >${working_dir}/build_uboot.log 2>&1

	if [ $? -ne 0 ] || [ ! -f ${working_dir}/${u_boot_dir}/u-boot ]; then
		echo "Error: UBOOT NOT BUILD.Please Get Some Error From build_uboot.log"
		error_msg=$(cat ${working_dir}/build_uboot.log)
		if [[ $(echo $error_msg | grep "ImportError: No module named _libfdt") != "" ]]; then
			echo "Please use Python2.7 as default python interpreter"
		fi
		exit 1
	fi

	if [ ! -f ${working_dir}/${u_boot_dir}/u-boot-sunxi-with-spl.bin ]; then
		echo "Error: UBOOT NOT BUILD.Please Enable spl option"
		exit 1
	fi
	#make boot.src
	if [ -n "$u_boot_boot_cmd_file" ]; then
		echo "build uboot.src"
		mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Beagleboard boot script" -d ${working_dir}/${u_boot_boot_cmd_file} ${working_dir}/output/boot.scr
	fi
	echo "Build uboot ok"
}

#linux=========================================================
clean_linux() {
	cd ${working_dir}/${linux_dir}
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- mrproper >/dev/null 2>&1
}

build_linux() {
	cd ${working_dir}/${linux_dir}
	echo "Building linux ..."
	echo "--->Configuring ..."
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- ${linux_config_file} >/dev/null 2>&1
	if [ $? -ne 0 ] || [ ! -f ${working_dir}/${linux_dir}/.config ]; then
		echo "Error: .config file not exist"
		exit 1
	fi
	echo "--->Get cpu info ..."
	proc_processor=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)
	echo "--->Compiling ..."
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- -j${proc_processor} >${working_dir}/build_linux.log 2>&1

	if [ $? -ne 0 ] || [ ! -f ${working_dir}/${linux_dir}/arch/arm/boot/zImage ]; then
		echo "Error: LINUX NOT BUILD. Please Get Some Error From build_linux.log"
		exit 1
	fi

	if [ ! -f ${working_dir}/${linux_dir}/arch/arm/boot/dts/${dtb_file} ]; then
		echo "Error: Linux NOT BUILD. ${working_dir}/${linux_dir}/arch/arm/boot/dts/${dtb_file} not found"
		exit 1
	fi

	#build linux kernel modules
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- -j${proc_processor} INSTALL_MOD_PATH=${working_dir}/${linux_dir}/out modules >/dev/null 2>&1
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- -j${proc_processor} INSTALL_MOD_PATH=${working_dir}/${linux_dir}/out modules_install >/dev/null 2>&1

	echo "Build linux ok"
}

#buildroot=========================================================
clean_buildroot() {
	cd ${working_dir}/${buildroot_dir}
	make ARCH=arm CROSS_COMPILE=${cross_compiler}- clean >/dev/null 2>&1
}

build_buildroot() {
	cd ${working_dir}/${buildroot_dir}
	echo "Building buildroot ..."
	echo "--->Configuring ..."
	rm ${working_dir}/${buildroot_dir}/.config
	make ${buildroot_config_file}
	if [ $? -ne 0 ] || [ ! -f ${working_dir}/${buildroot_dir}/.config ]; then
		echo "Error: .config file not exist"
		exit 1
	fi

	echo "--->Get cpu info ..."
	proc_processor=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)
	echo "--->Compiling ..."
	make -j${proc_processor} >${working_dir}/build_buildroot.log 2>&1

	if [ $? -ne 0 ] || [ ! -d ${working_dir}/${buildroot_dir}/output/target ]; then
		echo "Error: BUILDROOT NOT BUILD.Please Get Some Error From build_buildroot.log"
		exit 1
	fi
	echo "Build buildroot ok"
}

#copy=========================================================
copy_uboot() {
	cp ${working_dir}/${u_boot_dir}/u-boot-sunxi-with-spl.bin ${working_dir}/output/
}
copy_linux() {
	cp ${working_dir}/${linux_dir}/arch/arm/boot/zImage ${working_dir}/output/
	cp ${working_dir}/${linux_dir}/arch/arm/boot/dts/${dtb_file} ${working_dir}/output/
	mkdir -p ${working_dir}/output/modules/
	cp -rf ${working_dir}/${linux_dir}/out/lib ${working_dir}/output/modules/
}
copy_buildroot() {
	cp -r ${working_dir}/${buildroot_dir}/output/target ${working_dir}/output/rootfs/ >/dev/null 2>&1
	cp ${working_dir}/${buildroot_dir}/output/images/rootfs.tar ${working_dir}/output/
	gzip -c ${working_dir}/output/rootfs.tar >${working_dir}/output/rootfs.tar.gz
}

clean_output_dir() {
	sudo rm -rf ${working_dir}/output/*
}

build() {
	check_env
	update_env
	echo "clean log ..."
	clean_log
	echo "clean output dir ..."
	clean_output_dir
	build_uboot
	echo "copy uboot ..."
	copy_uboot
	build_linux
	echo "copy linux ..."
	copy_linux
	build_buildroot
	echo "copy buildroot ..."
	copy_buildroot
}

#=======================MAIN============================
if [ "${1}" = "" ] && [ ! "${1}" = "build_tf" ] && [ ! "${1}" = "build_flash" ] && [ ! "${1}" = "pull_all" ]; then
	echo "Usage: script.sh [build_flash | build_tf | pull_all | clean]"；
	echo "One key build nano fimware"
	echo " "
	echo "build_flash    Build zero firmware booted from spiflash"
	echo "build_tf          Build zero firmware booted from tf"
	echo "pull_all         Pull build env from internet"
	echo "clean            Clean build env"
	exit 0
fi

if [ "${1}" = "update_env" ]; then
	update_env
	echo "update_env ok"
	exit 0
fi

if [ "${1}" = "clean" ]; then
	clean_all
	clean_output_dir
	echo "clean ok"
	exit 0
fi

if [ "${1}" = "pull_all" ]; then
	pull_all
fi

if [ "${1}" = "pull_uboot" ]; then
	pull_uboot
fi

if [ "${1}" = "pull_linux" ]; then
	pull_linux
fi

if [ "${1}" = "pull_buildroot" ]; then
	pull_buildroot
fi

if [ "${1}" = "build_uboot" ]; then
	u_boot_config_file="LicheePi_Zero_defconfig"
	build_uboot
fi

if [ "${1}" = "build_linux" ]; then
	linux_config_file="licheepi_zero_defconfig"
	build_linux
fi

if [ "${1}" = "build_buildroot" ]; then
	buildroot_config_file="licheepi_zero_defconfig"
	build_buildroot
fi

sleep 1
echo "Done!"
