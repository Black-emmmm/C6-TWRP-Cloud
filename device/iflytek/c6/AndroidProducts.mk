PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_c6.mk

# Android 10+ 才读这个变量，P 上会被忽略但无害
COMMON_LUNCH_CHOICES := \
    twrp_c6-eng \
    twrp_c6-userdebug
