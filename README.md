# TWRP for iFLYTEK CB-C6-STU (ud710_2h10) — 云构建

设备：讯飞 AI 学习机 CB-C6-STU，展锐 UD710/T7510（sharkl5），Android 9，非 A/B，
recovery 独立分区（40 MiB）。本仓库只放**设备树 + CI 流水线**，不存 AOSP 源码。

## 基线选择

| 项 | 值 | 原因 |
|---|---|---|
| 源码基座 | `minimal-manifest-twrp/platform_manifest_twrp_omni` @ `twrp-9.0` | 与设备 Android 9（first_api_level 28）对齐；omni-9 基座 + TeamWin `android-9.0` recovery |
| 内核 | 官方 prebuilt（`prebuilt/kernel`，4.14.98） | 展锐 BSP 内核未开源，直接用官方内核保证 vendor HAL/基带兼容 |
| DTBO | 官方 `prebuilt/dtbo.img` | dtb.bin 是 SPRD 私有打包格式，不能重打包 |
| fstab | TWRP v1 语法（`recovery.fstab`） | twrp-9.0 用 v1；分区名已与官方 fstab + sepolicy contexts 核对 |

twrp-9.0 的 TWRP 本体在 `bootable/recovery`（TeamWin fork），所以设备树继承
`base.mk` 即可，**不需要** `vendor/twrp/config/twrp.mk`（那是 twrp-11/12.1 的写法）。

## 怎么跑

1. GitHub 网页新建一个空仓库（建议 public —— Actions 分钟数不限）
2. 把本目录推上去（`main` 分支）
3. Actions → `Build TWRP (iFLYTEK C6)` → Run workflow
4. 跑完在 Artifacts 里下 `twrp-c6-recovery`

一次完整构建约 60–90 分钟：repo sync 20–40 min，编译 30–50 min。

## 流水线做了什么

```
ubuntu-22.04 runner
 ├─ 删 dotnet/android-sdk/CodeQL 等，腾出 ~55-65G
 ├─ docker run ubuntu:18.04（对齐 LineageOS 16 官方构建环境）
 │   ├─ apt 源：archive → 失败自动切 old-releases
 │   ├─ 依赖：openjdk-8 + gcc/multilib + python2/3（AOSP 9 全套）
 │   ├─ repo init --depth=1 浅克隆（省 ~40G）
 │   ├─ repo sync -c --no-clone-bundle --no-tags
 │   ├─ cp 设备树 → device/iflytek/c6
 │   └─ lunch twrp_c6-eng && mka recoveryimage
 └─ 上传 out/recovery.img + sha256 + build-info.txt
```

用 `ubuntu:18.04` 容器而不是 runner 本身，是因为 AOSP 9 在新版 gcc（11/12）和
默认 JDK 17 下会因 `-Werror` 和 host 工具链失败；18.04 的 gcc-7 + JDK 8 是
LineageOS 16 的官方组合。

## 刷入

```bash
# 关机 → 进 fastboot（展锐 U-Boot 一般有）或 bootloader 模式
fastboot flash recovery recovery.img
# 或已 root 的系统上直接 dd
adb push recovery.img /sdcard/
adb shell su -c "dd if=/sdcard/recovery.img of=/dev/block/platform/soc/soc:ap-apb/71400000.sdio/by-name/recovery"
adb shell su -c "dd if=/dev/zero of=/dev/block/platform/soc/soc:ap-apb/71400000.sdio/by-name/misc bs=512 count=1"
```

进 recovery：常规展锐是 **Power + Vol+**；未验证，失败就用 `adb reboot recovery`。

## 首版刻意关掉的东西

| 项 | 状态 | 原因 |
|---|---|---|
| `TW_INCLUDE_CRYPTO` / FBE 解密 | 关闭 | twrp-9.0 的 FBE 需要 vendor vold + keymaster blob 配合，展锐侧未验证；先保证能点亮、能 `Format Data`（mkfs 不需要解密） |
| 中文完整语言包 | 只有默认 zh_CN 主题字符串 | twrp-9.0 没有 `TW_EXTRA_LANGUAGES`，多语言靠 `gui/theme/common/languages` 内已有条目 |
| 电池百分比 | 用默认探测 | `TW_CUSTOM_BATTERY_PATH` 需按真机 `/sys/class/power_supply/` 实际节点确认 |

## 已知风险 / 需真机验证

1. **主题尺寸**：`TW_THEME := landscape_hdpi` 是按 10.1" 1920x1200 估的；错位改 `landscape_mdpi`。
2. **亮度节点**：`/sys/class/backlight/sprd_backlight/brightness`，来自 dtbo pwm-backlight；路径不对会黑屏（TWRP 有 `TW_NO_SCREEN_BLANK` 兜底可加）。
3. **触屏**：sc2703 走 evdev 自动识别；坐标错需开 `RECOVERY_TOUCHSCREEN_SWAP_XY` / `FLIP_X` / `FLIP_Y`。
4. **system-as-root 挂载**：`/system_root` 与 `/system` 双条目，TWRP 9 会自动处理；若刷 GSI 时目标分区识别异常，检查 fstab 里 system 那条。
5. **40 MiB 分区上限**：arm64 TWRP 带 NTFS-3G/中文主题约 28–35 MB，够用；超了会在打包阶段报错，届时关 `TW_INCLUDE_NTFS_3G`。
6. **SELinux**：recovery 用 AOSP 预定义 sepolicy，未加设备策略；若卡在 `init` 阶段，先加 `androidboot.selinux=permissive` 到 cmdline 验证。

## 目录

```
device/iflytek/c6/
├── AndroidProducts.mk      lunch 入口
├── BoardConfig.mk          板级事实 + TWRP 标志（已内联 AOSP 树，去掉自包含 include）
├── twrp_c6.mk              product 定义（继承 base.mk）
├── recovery.fstab          分区表（v1，非 A/B，去掉 slotselect）
└── prebuilt/
    ├── kernel              官方 4.14.98（18MB）
    └── dtbo.img            官方 DTBO（8MB）
scripts/build.sh            容器内构建脚本
.github/workflows/build-twrp.yml
```
