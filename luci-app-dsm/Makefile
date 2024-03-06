

include $(TOPDIR)/rules.mk

PKG_VERSION:=1.0.2-20240306
PKG_RELEASE:=

LUCI_TITLE:=LuCI support for Synology DSM
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+lsblk +docker +luci-lib-taskd +luci-lib-docker

define Package/luci-app-dsm/conffiles
/etc/config/dsm
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
