#!/usr/bin/env bash
# Build Script for Hui Kramel (kanged for ZeloKernel)
# Copyright (C) 2022-2023 Mar Yvan D.

# Dependency preparation
sudo apt install bc -y
sudo apt-get install device-tree-compiler -y

# Main Variables
KDIR=$(pwd)
DATE=$(date +%d-%h-%Y-%R:%S | sed "s/:/./g")
START=$(date +"%s")
TCDIR=$GITHUB_WORKSPACE/kernel_workspace/clang
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb

# Naming Variables
KNAME="ZeloKernel"
VERSION="v6.9"
CODENAME="sweet"
MIN_HEAD=$(git rev-parse HEAD)
export KVERSION="${KNAME}-${VERSION}-${CODENAME}-$(echo ${MIN_HEAD:0:8})"

# Build Information
LINKER=ld.lld
export COMPILER_NAME="$(${TCDIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export LINKER_NAME="$("${TCDIR}"/bin/${LINKER} --version | head -n 1 | sed 's/(compatible with [^)]*)//' | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export KBUILD_BUILD_USER=puerconiox009
export KBUILD_BUILD_HOST=andromedawashere
export DEVICE="Redmi Note 10 Pro/Pro Max"
export CODENAME="sweet"
export TYPE="Beta"
export DISTRO=$(source /etc/os-release && echo "${NAME}")

# Telegram Integration Variables
CHAT_ID="$CHAT_ID"
PUBCHAT_ID="$PUBCHAT_ID"
BOT_ID="$BOT_ID"

function publicinfo() {
    curl -s -X POST "https://api.telegram.org/bot${BOT_ID}/sendMessage" \
        -d chat_id="$PUBCHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>Automated build started for ${DEVICE} (${CODENAME})</b>"
}
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot${BOT_ID}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>Laboratory Machine: Build Triggered</b>%0A<b>Docker: </b><code>$DISTRO</code>%0A<b>Build Date: </b><code>${DATE}</code>%0A<b>Device: </b><code>${DEVICE} (${CODENAME})</code>%0A<b>Kernel Version: </b><code>$(make kernelversion 2>/dev/null)</code>%0A<b>Build Type: </b><code>${TYPE}</code>%0A<b>Compiler: </b><code>${COMPILER_NAME}</code>%0A<b>Linker: </b><code>${LINKER_NAME}</code>%0A<b>Zip Name: </b><code>${KVERSION}</code>%0A<b>Branch: </b><code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Last Commit Details: </b><a href='${REPO_URL}/commit/${COMMIT_HASH}'>${COMMIT_HASH}</a> <code>($(git log --pretty=format:'%s' -1))</code>"
}
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot${BOT_ID}/sendDocument" \
        -F chat_id="$CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds. | <b>Compiled with: ${COMPILER_NAME} + ${LINKER_NAME}.</b>"
}
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot${BOT_ID}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="Compilation failed, please check build logs for errors."
    exit 1
}
function compile() {
    make O=out ARCH=arm64 sweet_defconfig
    export PATH=${TCDIR}/bin/:/usr/bin/:${PATH}
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    export LLVM=1
    export LLVM_IAS=1
    make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip Image.gz-dtb dtbo.img 2>&1 | tee log.txt

    if ! [ -a "$IMAGE" ]; then
        finerr
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel

    if ! [ -a "$DTBO" ]; then
        finerr
        exit 1
    fi
    cp out/arch/arm64/boot/dtbo.img AnyKernel
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r "${KVERSION}.zip" . -x ".git*" -x "README.md" -x "*.zip"
    cd ..
}
publicinfo
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
