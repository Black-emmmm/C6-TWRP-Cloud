#
# TWRP BoardConfig — ud710_2h10 (讯飞 C6 / CB-C6-STU)
# 基线：SebaUbuntu 生成器产物 + minimal-manifest-twrp/platform_manifest_twrp_omni @ twrp-9.0
#
# 相对原树的修正（2026-10-25）：
#   1. BOARD_BOOTIMG_HEADER_VERSION 1 → 0        A9 官方 boot/recovery 都是 v0 头
#   2. 删除 OVERRIDE_TARGET_FLATTEN_APEX        Android 10+ 才有的变量
#   3. 删除 PLATFORM_VERSION=16.1.0 / SECURITY_PATCH=2099 反回滚 hack，
#      那是 twrp-11/12 的写法，在 A9（omni-9）上只会污染 build.prop
#   4. BOARD_INCLUDE_RECOVERY_DTBO → false      避免把 8MB dtbo 分区镜像塞进 40MB recovery
#   5. userdata 文件系统 ext4 → f2fs             官方 userdata 是 f2fs
#   6. 补 TARGET_OTA_ASSERT_DEVICE / 亮度 / NTFS / 加密开关等 twrp-9.0 有效 flag
#   7. 删掉 twrp-9.0 不存在的 flag：TW_SCREEN_BLANK_ON_BOOT、TW_INPUT_BLACKLIST、TW_EXTRA_LANGUAGES
#

DEVICE_PATH := device/sprd/ud710_2h10

# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Architecture
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

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := ud710_2h10
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := ud710
TARGET_OTA_ASSERT_DEVICE := ud710_2h10,c6,CB-C6-STU

# Display —— 面板 1200x1920 竖屏（内核 lcd_size=1920x1200 指物理方向，DRM mode 1200x1920）
TARGET_SCREEN_DENSITY := 240

# Kernel / boot.img
# 官方 boot.bin 头部逐字段提取：kernel_addr=0x8000 ramdisk_addr=0x5400000
#                              second_addr=0xf00000 tags_addr=0x100 page_size=2048
BOARD_BOOTIMG_HEADER_VERSION := 0
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_CMDLINE := console=ttyS1,115200n8 buildvariant=user
BOARD_KERNEL_PAGESIZE := 2048
BOARD_RAMDISK_OFFSET := 0x05400000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset 0x00008000
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)

# Kernel - prebuilt（C6 官方 4.14.98，2024-08-22 构建）
TARGET_FORCE_PREBUILT_KERNEL := true
ifeq ($(TARGET_FORCE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
endif
# dtbo 由展锐 U-Boot 从独立分区加载，不并入 recovery
BOARD_INCLUDE_RECOVERY_DTBO := false
BOARD_KERNEL_SEPARATED_DTBO :=

# Partitions
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 36700160
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 41943040
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
RECOVERY_GRAPHICS_USE_LINELENGTH := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_HAS_NO_SELECT_BUTTON := true
BOARD_SUPPRESS_EMMC_WIPE := true

# Security patch level
VENDOR_SECURITY_PATCH := 2021-08-01

# Verified Boot
BOARD_AVB_ENABLE := false

# TWRP Configuration
TW_THEME := portrait_hdpi
TW_DEVICE_VERSION := c6-cloud
TW_USE_TOOLBOX := true

# 亮度：dtbo pwm-backlight，范围 0x2~0x1FF
TW_BRIGHTNESS_PATH := /sys/class/backlight/sprd_backlight/brightness
TW_MAX_BRIGHTNESS := 511
TW_DEFAULT_BRIGHTNESS := 128

# 语言
TW_DEFAULT_LANGUAGE := zh_CN

# 存储
TW_INTERNAL_STORAGE_PATH := "/data/media"
TW_INTERNAL_STORAGE_MOUNT_POINT := "data"
TW_EXTERNAL_STORAGE_PATH := "/external_sd"
TW_EXTERNAL_STORAGE_MOUNT_POINT := "external_sd"

# 加密：首版关闭。twrp-9.0 的 FBE 需要 vendor vold + keymaster blob，
# 展锐侧未验证；Format Data 走 mkfs，不需要解密。
TW_INCLUDE_CRYPTO := false

# 其它模块
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_FB2PNG := true
TW_HAS_DOWNLOAD_MODE := false
TW_NO_HAPTICS := true

# twrp-9.0 没有 TW_INPUT_BLACKLIST（11+ 才有）。若进 recovery 触摸失效/被虚拟键设备抢走，
# 需要在 ueventd 里屏蔽 hbtp_vm，或改用 twrp-11 基座。
