#!/usr/bin/env bash
#
# TWRP 构建脚本 —— 在 ubuntu:18.04 容器内以 root 运行
# 由 .github/workflows/build-twrp.yml 调用，也可在任意 docker/VM 里直接跑。
#
# 环境变量：
#   TWRP_BRANCH  minimal-manifest 分支，默认 twrp-9.0
#   JOBS         并行数，默认 nproc
#   SRC          源码目录，默认 /src
#   WORK         仓库挂载点，默认 /work
#
set -euo pipefail

TWRP_BRANCH="${TWRP_BRANCH:-twrp-9.0}"
SRC="${SRC:-/src}"
WORK="${WORK:-/work}"
JOBS="${JOBS:-$(nproc)}"

# 从第一行起就把全部输出落到宿主机挂载目录，任何早期失败（apt / docker / repo）
# 都能留下日志：workflow 里 objects.githubusercontent 不可达，日志是我们唯一的排障入口。
mkdir -p "$WORK/out"
exec > >(tee "$WORK/out/build.log") 2>&1
trap 'rc=$?; echo "== build.sh 退出码 $rc =="; [ "$rc" -ne 0 ] && echo "（失败前最后 5 行见上）"' EXIT

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

echo "host: $(uname -a)"
echo "date: $(date -u +%FT%TZ)"
df -h / /work 2>/dev/null || true

# ---------------------------------------------------------------
# 1. apt 源（bionic 已进 old-releases，先试 archive，失败自动回退）
# ---------------------------------------------------------------
log "准备 apt 源"
echo "--- 当前 sources.list ---"
cat /etc/apt/sources.list
if ! apt-get update -qq; then
    echo "archive 不可用，切换到 old-releases.ubuntu.com"
    sed -i -e 's@//archive\.ubuntu\.com@//old-releases.ubuntu.com@g' \
           -e 's@//security\.ubuntu\.com@//old-releases.ubuntu.com@g' \
           /etc/apt/sources.list
    apt-get update || { echo "old-releases 也失败"; exit 11; }
fi

# ---------------------------------------------------------------
# 2. 构建依赖（对齐 LineageOS 16 / AOSP 9 官方构建环境）
# ---------------------------------------------------------------
log "安装依赖"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openjdk-8-jdk git curl ca-certificates python python3 \
    bc bison build-essential ccache flex g++-multilib gcc-multilib \
    gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev \
    libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libwxgtk3.0-dev \
    libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools \
    xsltproc zip zlib1g-dev unzip

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
java -version 2>&1 | head -2

# AOSP 9 的部分 host 工具仍然调 python2（repo / 部分 build 脚本）
if ! command -v python >/dev/null 2>&1; then
    ln -sf /usr/bin/python2.7 /usr/bin/python
fi
python --version 2>&1 | head -1 || true

# ---------------------------------------------------------------
# 3. repo 工具
# ---------------------------------------------------------------
log "安装 repo"
if ! curl -fsSL --max-time 60 https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo; then
    echo "googleapis 不可达，改用清华镜像"
    curl -fsSL --max-time 60 https://mirrors.tuna.tsinghua.edu.cn/git/git-repo -o /usr/local/bin/repo
fi
chmod +x /usr/local/bin/repo
repo --version 2>&1 | head -1 || true

# ---------------------------------------------------------------
# 4. 同步源码
# ---------------------------------------------------------------
git config --global user.name  "c6-cloud-builder"
git config --global user.email "c6-cloud-builder@localhost"
git config --global http.postBuffer 524288000

mkdir -p "$SRC"
cd "$SRC"
if [ ! -d .repo ]; then
    log "repo init ($TWRP_BRANCH, 浅克隆)"
    repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git \
        -b "$TWRP_BRANCH" --depth=1 --no-clone-bundle
fi

log "repo sync（约 20-40 分钟）"
repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags --optimized-fetch

# ---------------------------------------------------------------
# 5. 放入设备树
# ---------------------------------------------------------------
log "安装设备树 device/sprd/ud710_2h10"
rm -rf "$SRC/device/sprd/ud710_2h10"
mkdir -p "$SRC/device/sprd"
cp -a "$WORK/device/sprd/ud710_2h10" "$SRC/device/sprd/ud710_2h10"
ls -l "$SRC/device/sprd/ud710_2h10"

# ---------------------------------------------------------------
# 6. 编译
# ---------------------------------------------------------------
cd "$SRC"
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

# AOSP 9 的 envsetup.sh / mka 大量引用未定义变量（例如 line 753 的 TOP），
# 在 `set -u` 下会直接 unbound variable 退出 → 从这里开始关掉 nounset。
set +u

log "envsetup + lunch omni_ud710_2h10-eng"
# shellcheck disable=SC1091
source build/envsetup.sh
lunch omni_ud710_2h10-eng
echo "TARGET_PRODUCT=${TARGET_PRODUCT:-?} VARIANT=${TARGET_BUILD_VARIANT:-?} OUT=${OUT:-?}"

log "mka recoveryimage -j$JOBS"
set +e
mka recoveryimage -j"$JOBS"
BUILD_RC=$?
set -e

if [ "$BUILD_RC" -ne 0 ]; then
    echo "构建失败，退出码 $BUILD_RC"
    exit "$BUILD_RC"
fi

IMG="$SRC/out/target/product/ud710_2h10/recovery.img"
if [ ! -f "$IMG" ]; then
    echo "构建返回成功但没找到 $IMG"
    find "$SRC/out/target/product/ud710_2h10" -maxdepth 1 -name '*.img' -ls || true
    exit 1
fi

cp -f "$IMG" "$WORK/out/recovery.img"
cd "$WORK/out"
sha256sum recovery.img > recovery.img.sha256
{
    echo "device:   sprd/ud710_2h10 (讯飞 C6)"
    echo "twrp:     $TWRP_BRANCH"
    echo "built:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "size:     $(stat -c%s recovery.img) bytes"
    echo "md5:      $(md5sum recovery.img | cut -d' ' -f1)"
} > build-info.txt

log "完成"
ls -lh "$WORK/out"
cat "$WORK/out/build-info.txt"
