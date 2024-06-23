# https://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz
# https://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz.asc

PKG_NAME="arm-linux-gnueabihf"
PKG_VERSION="6.3.1-2017.05"
PKG_VERSION_SHORT="6.3-2017.05"
PKG_MD5="ea9ba26cfc0aaf0a1d307083f64e2fa9"
PKG_ARCH="arm"
PKG_LICENSE="GPL"
PKG_URL="https://releases.linaro.org/components/toolchain/binaries/${PKG_VERSION_SHORT}/${PKG_NAME}/gcc-linaro-${PKG_VERSION}-x86_64_${PKG_NAME}.tar.xz"
PKG_SOURCE_DIR="gcc-linaro-${PKG_VERSION}-x86_64_${PKG_NAME}"
PKG_SOURCE_NAME="gcc-linaro-${PKG_VERSION}-x86_64_${PKG_NAME}.tar.xz"
PKG_DESC="GCC for building U-Boot and Kernel firmware"

__package_install() {
	local TARGET_PATH="${CODE_PATH}/prebuilts/gcc/linux-x86/arm/"
	[ -d "$TARGET_PATH" ] || mkdir -p "$TARGET_PATH"
	echo $TARGET_PATH
}
