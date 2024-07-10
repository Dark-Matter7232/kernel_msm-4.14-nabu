#!/bin/sh

# Initialize variables
GRN='\033[01;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[01;31m'
RST='\033[0m'
ORIGIN_DIR=$(pwd)
TOOLCHAIN=$ORIGIN_DIR/build-shit
IMAGE=$ORIGIN_DIR/out/arch/arm64/boot/Image
DEVICE=nabu
CONFIG="${DEVICE}_defconfig"
NPROC=$(($(nproc) + 1))
MAKE="-j$NPROC O=out CROSS_COMPILE=aarch64-elf- CROSS_COMPILE_ARM32=arm-eabi- HOSTCC=gcc HOSTCXX=aarch64-elf-g++ CC=aarch64-elf-gcc LD=ld.lld"

# Export environment variables
export KBUILD_BUILD_USER=Const
export KBUILD_BUILD_HOST=Coccinelle
export ARCH=arm64
export USE_CCACHE=1
export CCACHE_SLOPPINESS="file_macro,locale,time_macros"
export CCACHE_NOHASHDIR="true"

script_echo() {
    echo "  $1"
}

exit_script() {
    kill -INT $$
}

add_deps() {
    echo -e "${CYAN}"
    if [ ! -d "$TOOLCHAIN" ]; then
        script_echo "Creating build-shit folder"
        mkdir "$TOOLCHAIN"
    fi

    if [ ! -d "$TOOLCHAIN/gcc-arm64" ]; then
        script_echo "Downloading toolchain..."
        cd "$TOOLCHAIN" || exit_script
        (
            git clone https://github.com/KenHV/gcc-arm64.git --single-branch -b master --depth=1 2>&1 | sed 's/^/     /' &
            git clone https://github.com/KenHV/gcc-arm.git --single-branch -b master --depth=1 2>&1 | sed 's/^/     /'
        )
        wait
        cd "$ORIGIN_DIR"
    fi

    verify_toolchain_install
}

verify_toolchain_install() {
    script_echo " "
    if [ -d "$TOOLCHAIN" ]; then
        script_echo "I: Toolchain found at default location"
        PATH="$TOOLCHAIN/gcc-arm64/bin:$TOOLCHAIN/gcc-arm/bin:$PATH"
        export PATH
    else
        script_echo "I: Toolchain not found"
        script_echo "   Downloading recommended toolchain at $TOOLCHAIN..."
        add_deps
    fi
}

build_kernel_image() {
    cleanup
    script_echo " "
    echo -e "${GRN}"
    printf "Write the Kernel version: "
    read KV
    echo -e "${YELLOW}"
    script_echo "Building CosmicFresh Kernel For $DEVICE"

    eval make "$MAKE" LOCALVERSION="—CosmicFresh-R$KV" $CONFIG 2>&1 | sed 's/^/     /'
    echo -e "${YELLOW}"
    eval make "$MAKE" LOCALVERSION="—CosmicFresh-R$KV" 2>&1 | sed 's/^/     /'

    SUCCESS=$?
    echo -e "${RST}"

    if [ $SUCCESS -eq 0 ] && [ -f "$IMAGE" ]; then
        echo -e "${GRN}"
        script_echo "------------------------------------------------------------"
        script_echo "Compilation successful..."
        script_echo "Image can be found at out/arch/arm64/boot/Image"
        script_echo "------------------------------------------------------------"
        build_flashable_zip
    elif [ $SUCCESS -eq 130 ]; then
        echo -e "${RED}"
        script_echo "------------------------------------------------------------"
        script_echo "Build force stopped by the user."
        script_echo "------------------------------------------------------------"
        echo -e "${RST}"
    elif [ $SUCCESS -eq 1 ]; then
        echo -e "${RED}"
        script_echo "------------------------------------------------------------"
        script_echo "Compilation failed.."
        script_echo "------------------------------------------------------------"
        echo -e "${RST}"
        cleanup
    fi
}

build_flashable_zip() {
    script_echo " "
    script_echo "I: Building kernel image..."
    echo -e "${GRN}"
    cp "$ORIGIN_DIR"/out/arch/arm64/boot/Image "$ORIGIN_DIR"/out/arch/arm64/boot/dtbo.img CosmicFresh/
    cp "$ORIGIN_DIR"/out/arch/arm64/boot/dtb.img CosmicFresh/dtb
    cd "$ORIGIN_DIR"/CosmicFresh/ || exit_script
    zip -r9 "CosmicFresh-R$KV-$DEVICE.zip" META-INF version anykernel.sh tools Image dtb dtbo.img
    rm -rf Image dtb dtbo.img
    cd "$ORIGIN_DIR"
}

cleanup() {
    rm -rf "$ORIGIN_DIR"/out/arch/arm64/boot/Image
    rm -rf "$ORIGIN_DIR"/out/arch/arm64/boot/dtb*
    rm -rf "$ORIGIN_DIR"/CosmicFresh/Image
    rm -rf "$ORIGIN_DIR"/CosmicFresh/*.zip
    rm -rf "$ORIGIN_DIR"/CosmicFresh/dtb*
}

add_deps
build_kernel_image
