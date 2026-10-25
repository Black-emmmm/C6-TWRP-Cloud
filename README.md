# TWRP for 讯飞 C6 / CB-C6-STU (ud710_2h10) — 云构建

展锐 UD710/T7510（sharkl5），Android 9，非 A/B，recovery 独立分区 40 MiB，
面板 1200×1920 竖屏。本仓库只放**设备树 + CI 流水线**，不存 AOSP 源码。

设备树基于已有的 `Black-emmmm/android_unisoc_twrpdt`（SebaUbuntu 生成器，来自
KDXF T10 的官方 recovery），在其上做了 7 处修正，见文末。

## 基座

| 项 | 值 |
|---|---|
| 源码 | `minimal-manifest-twrp/platform_manifest_twrp_omni` @ `twrp-9.0`（omni-9 + TeamWin android-9.0 recovery） |
| 内核 | C6 官方 4.14.98（`prebuilt/kernel`，2024-08-22） |
| DTBO | C6 官方 dtbo（标准 AOSP DTBO 表，7703 字节有效 + 零填充） |
| fstab | TWRP v1 语法，设备路径统一用 `/dev/block/by-name/*` |

twrp-9.0 是 omni 基座，TWRP 本体由 manifest 的 `twrp-extras.xml` 把
`bootable/recovery` 换成 TeamWin `android-9.0`，所以 product 继承
`vendor/omni/config/common.mk`（不是 `vendor/twrp/config/twrp.mk`，那是 11/12.1 的写法）。

## 两条构建路径

### A. 本仓库的 workflow（推荐，环境可控）

`Actions → Build TWRP (iFLYTEK C6) → Run workflow`

```
ubuntu-22.04 runner
 ├─ 删 dotnet/android-sdk/CodeQL 等，腾 ~55-65G
 ├─ docker run ubuntu:18.04（gcc-7 + openjdk-8 + python2，LineageOS 16 同款）
 │   ├─ repo init --depth=1 → repo sync -c（浅克隆省 ~40G）
 │   ├─ cp device/sprd/ud710_2h10
 │   └─ lunch omni_ud710_2h10-eng && mka recoveryimage
 └─ 上传 out/recovery.img
```

### B. 你现有的 `Lazy_Action-Recoverys-Builder`

`TeamWin [TWRP]` workflow，参数：

| 输入 | 值 |
|---|---|
| MANIFEST_URL | `https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni` |
| MANIFEST_BRANCH | `twrp-9.0` |
| DEVICE_TREE_URL | 本仓库地址 |
| DEVICE_TREE_BRANCH | `main` |
| DEVICE_PATH | `device/sprd/ud710_2h10` |
| DEVICE_NAME | `ud710_2h10` |
| MAKEFILE_NAME | `omni_ud710_2h10` |
| BUILD_TARGET | `recovery` |

注意 B 的已知风险（A 已规避）：runner 是 `ubuntu-latest`（24.04）+ 默认 gcc/JDK，
AOSP 9 需要 python2 垫片 —— 你 10-05 的 OFRP 两次运行就是卡在 `install py-is-py2`，
构建步骤没跑起来。B 路径如果报 python2 相关错误，就转到 A。

## 刷入

```bash
fastboot flash recovery recovery.img
# 或
adb push recovery.img /sdcard/
adb shell su -c "dd if=/sdcard/recovery.img of=/dev/block/by-name/recovery"
adb shell su -c "dd if=/dev/zero of=/dev/block/by-name/misc bs=512 count=1"
```

进 recovery：展锐常规 **Power + Vol+**；未验证，失败用 `adb reboot recovery`。

## 对原树的 7 处修正

| # | 原值 | 改为 | 原因 |
|---|---|---|---|
| 1 | fstab 用 `71900000.ufs/by-name/*` | `/dev/block/by-name/*` | C6 官方固件是 `71400000.sdio`，两台同板不同控制器；by-name 由 ueventd 自动建链，通吃 |
| 2 | fstab 系统分区挂 `/` | `/system_root` | twrp-9.0 的 SAR 约定，否则刷 GSI 时找不到 system |
| 3 | `BOARD_BOOTIMG_HEADER_VERSION := 1` | `0` | A9 官方 boot/recovery 都是 v0 头 |
| 4 | `BOARD_INCLUDE_RECOVERY_DTBO := true` | `false` | 否则 8MB dtbo 分区镜像被塞进 40MB recovery |
| 5 | `PLATFORM_VERSION := 16.1.0`、`SECURITY_PATCH := 2099` | 删除 | twrp-11/12 的反回滚 hack，A9 上只会污染 build.prop |
| 6 | `BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4` | `f2fs` | 官方 userdata 是 f2fs |
| 7 | `TW_SCREEN_BLANK_ON_BOOT`、`TW_INPUT_BLACKLIST`、`TW_EXTRA_LANGUAGES` | 删除 | twrp-9.0 无此 flag（11+ 才有）；`TW_THEME := portrait_hdpi` 保留 —— 内核 lcd_size=1920x1200 是物理方向，DRM mode 实为 1200x1920 |

另外补了 `TARGET_OTA_ASSERT_DEVICE`、亮度节点（`/sys/class/backlight/sprd_backlight`，
范围 0x2~0x1FF）、NTFS-3G、FB2PNG；首版 `TW_INCLUDE_CRYPTO := false`，先保点亮 + 能 Format Data。

## 首版仍需真机验证

1. **主题**：`portrait_hdpi` 按 1200×1920/240dpi 选；若图标过大改 `portrait_xhdpi`。
2. **亮度**：路径来自 dtbo pwm-backlight，不对会黑屏（可加 `TW_NO_SCREEN_BLANK`）。
3. **触摸**：Goodix `hbtp_vm` 虚拟键设备可能抢走输入，twrp-9.0 没有 `TW_INPUT_BLACKLIST`，
   必要时在 ueventd 里屏蔽，或改用 twrp-11 基座。
4. **system_root**：TWRP 会把 system 挂到 `/system_root`，`/system` 是它的软链。
5. **加密**：FBE 关闭，`/data` 不解密；Format Data 走 mkfs，不受影响。

## 目录

```
device/sprd/ud710_2h10/
├── AndroidProducts.mk / Android.mk / Android.bp / vendorsetup.sh
├── omni_ud710_2h10.mk         product（继承 core_64_bit + full_base_telephony + vendor/omni/config/common.mk）
├── BoardConfig.mk             板级 + TWRP flag（已按 twrp-9.0 白名单清理）
├── device.mk
├── recovery.fstab             by-name 路径 + /system_root
├── extract-files.sh / setup-makefiles.sh
├── recovery/root/             init.recovery / ueventd（展锐设备节点）
└── prebuilt/{kernel,dtbo.img}
scripts/build.sh               容器内构建脚本
.github/workflows/build-twrp.yml
```
