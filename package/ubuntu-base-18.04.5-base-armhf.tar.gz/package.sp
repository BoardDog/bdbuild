# http://cdimage.ubuntu.com/ubuntu-base/releases/18.04.5/release/ubuntu-base-18.04.5-base-armhf.tar.gz
# http://cdimage.ubuntu.com/ubuntu-base/releases/18.04.5/release/ubuntu-base-18.04.5-base-armhf.tar.gz.zsync

PKG_NAME="ubuntu-base"
PKG_VERSION="18.04.5"
PKG_VERSION_SHORT="18.04.5"
PKG_MD5="09730a1dfe882f6e81c983d3deb10a9a"
PKG_ARCH="armhf"
PKG_LICENSE="GPL"
PKG_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/${PKG_VERSION_SHORT}/release/${PKG_NAME}-${PKG_VERSION}-base-${PKG_ARCH}.tar.gz"
PKG_SOURCE_DIR="${PKG_NAME}-${PKG_VERSION}-base-${PKG_ARCH}"
PKG_SOURCE_NAME="${PKG_NAME}-${PKG_VERSION}-base-${PKG_ARCH}.tar.gz"
PKG_DESC="Ubuntu base 18.04.5 rootfs"

__package_install() {}
