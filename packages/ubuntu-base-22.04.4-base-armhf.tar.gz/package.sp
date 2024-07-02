# http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-armhf.tar.gz
# http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-armhf.tar.gz.zsync

PKG_NAME="ubuntu-base"
PKG_VERSION="22.04.4"
PKG_VERSION_SHORT="22.04"
PKG_MD5="050ed1b91eab8c710d2deb2431efb784"
PKG_ARCH="armhf"
PKG_LICENSE="GPL"
PKG_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/${PKG_VERSION_SHORT}/release/${PKG_NAME}-${PKG_VERSION}-base-${PKG_ARCH}.tar.gz"
PKG_SOURCE_DIR="${PKG_NAME}-${PKG_VERSION}-base-${PKG_ARCH}"
PKG_SOURCE_NAME="${PKG_NAME}-${PKG_VERSION}-base-${PKG_ARCH}.tar.gz"
PKG_DESC="Ubuntu base rootfs"

__package_install() {}
