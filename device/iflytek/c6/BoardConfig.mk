#
# TWRP BoardConfig — iFLYTEK CB-C6-STU (AIPad)
# SoC:    Unisoc (Spreadtrum) UD710 / T7510 "sharkl5", 5G NR
# Board:  ud710_2h10
# Kernel: 4.14.98 (arm64), 官方 prebuilt
# Android: 9 (PPR1.180610.011), first_api_level=28
#
# 基线：minimal-manifest-twrp/platform_manifest_twrp_omni @ twrp-9.0
#       （omni 9 + TeamWin android-9.0 recovery）
#
# 说明：本文件合并了 AOSP 设备树的板级事实（来自官方固件提取）
#       与 TWRP 专用标志。原 twrp/iflytek/c6/BoardConfig.mk 里的
#       `include device/iflytek/c6/BoardConfig.mk` 会造成自包含递归，
#       已在此处内联合并。
#

DEVICE_PATH := device/iflytek/c6

TARGET_BOARD_PLATFORM := ud710
TARGET_BOOTLOADER_BOARD_NAME := ud710_2h10
TARGET_OTA_ASSERT_DEVICE := c6,ud710_2h10,CB-C6-STU

# ---------------------------------------------------------------
# 架构
# ---------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a75

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_USES_64_BIT_BINDER := true

# ---------------------------------------------------------------
# 内核 / DTBO（均为官方镜像，不从源码编译）
# ---------------------------------------------------------------
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# boot.img 参数 —— 从官方 boot.bin 头部逐字段提取：
#   kernel_addr=0x8000 ramdisk_addr=0x5400000 second_addr=0xf00000
#   tags_addr=0x100 page_size=2048
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE := console=ttyS1,115200n8 buildvariant=user
BOARD_MKBOOTIMG_ARGS := \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x05400000 \
    --second_offset 0x00f00000 \
    --tags_offset 0x00000100 \
    --header_version 0

# ---------------------------------------------------------------
# 分区布局（数值 = 官方分区实际大小）
# 非 A/B（经典布局 + _bak 备份分区），recovery 独立分区
# ---------------------------------------------------------------
AB_OTA_UPDATER := false
BOARD_USES_RECOVERY_AS_BOOT := false
TARGET_NO_RECOVERY := false

BOARD_BOOTIMAGE_PARTITION_SIZE := 36700160      # 0x2300000 (35 MiB)
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 41943040  # 40 MiB，与官方一致
BOARD_DTBOIMAGE_PARTITION_SIZE := 8388608       # 8 MiB
BOARD_FLASH_BLOCK_SIZE := 262144                # 0x40000 (eMMC erase block)

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_HAS_LARGE_FILESYSTEM := true

# Android 9 system-as-root：system 分区挂载为 /，TWRP 需配合 /system_root
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
BOARD_ROOT_EXTRA_FOLDERS := persist

# ---------------------------------------------------------------
# Recovery 基础
# ---------------------------------------------------------------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
# 展锐 fbdev（sc2703-disp）走 legacy framebuffer，需按行宽对齐
RECOVERY_GRAPHICS_USE_LINELENGTH := true
BOARD_HAS_NO_SELECT_BUTTON := true
# 展锐 eMMC 清理超时保护
BOARD_SUPPRESS_EMMC_WIPE := true

# ---------------------------------------------------------------
# 显示 / 主题
# 10.1" 横屏平板，dtbo 面板 1920x1200；若界面错位改 landscape_mdpi
# ---------------------------------------------------------------
TW_THEME := landscape_hdpi
TW_DEVICE_VERSION := c6-cloud

# 亮度：dtbo pwm-backlight，范围 0x2~0x1FF(511)
TW_BRIGHTNESS_PATH := /sys/class/backlight/sprd_backlight/brightness
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 128

# ---------------------------------------------------------------
# 语言
# ---------------------------------------------------------------
TW_DEFAULT_LANGUAGE := zh_CN

# ---------------------------------------------------------------
# 存储
# ---------------------------------------------------------------
TW_INTERNAL_STORAGE_PATH := "/data/media"
TW_INTERNAL_STORAGE_MOUNT_POINT := "data"
TW_EXTERNAL_STORAGE_PATH := "/external_sd"
TW_EXTERNAL_STORAGE_MOUNT_POINT := "external_sd"

# ---------------------------------------------------------------
# 功能模块
# ---------------------------------------------------------------
# v1 首版关闭加密解密：FBE(aes-256-xts) 在 twrp-9.0 上需要 vendor vold/keymaster
# 才能工作，先保证能点亮 + 能 Format Data（mkfs 不需要解密）。
# 验证通过后再开 TW_INCLUDE_CRYPTO / TW_INCLUDE_CRYPTO_FBE。
TW_INCLUDE_CRYPTO := false
TW_INCLUDE_FB2PNG := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_LIBRESETPROP := true
TW_NO_HAPTICS := true
TW_HAS_DOWNLOAD_MODE := false

# 触屏：sc2703 走 evdev 自动识别；若方向/坐标异常再启用：
# RECOVERY_TOUCHSCREEN_SWAP_XY := true
# RECOVERY_TOUCHSCREEN_FLIP_X := true
# RECOVERY_TOUCHSCREEN_FLIP_Y := true

# 电池：展锐常用 power_supply 节点，若 TWRP 显示 0% 再改成 platform 下的实际路径
# TW_CUSTOM_BATTERY_PATH := /sys/class/power_supply/battery/capacity
