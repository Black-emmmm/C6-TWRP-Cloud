# TWRP product — iFLYTEK CB-C6-STU (ud710_2h10)
# 基线: minimal-manifest-twrp/platform_manifest_twrp_omni @ twrp-9.0
#
# twrp-9.0 是 omni-9 基座，TWRP 本体来自 TeamWin/android_bootable_recovery (android-9.0)，
# 由 manifest 的 twrp-extras.xml 覆盖 bootable/recovery。
# 因此这里继承 base.mk 即可，不需要 vendor/twrp/config/twrp.mk
# （那是 twrp-11/12.1 的写法）。

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

PRODUCT_NAME := twrp_c6
PRODUCT_DEVICE := c6
PRODUCT_BRAND := iFLYTEK
PRODUCT_MODEL := CB-C6-STU
PRODUCT_MANUFACTURER := iFLYTEK

PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.device=c6 \
    ro.product.first_api_level=28 \
    ro.sf.lcd_density=213 \
    ro.twrp.target.devices=c6
