#!/bin/sh -e

_tag="1.4.350"
_repo="KhronosGroup/Vulkan-Loader"
_dir="Vulkan-Loader-$_tag"
_artifact="$_tag.tar.gz"
_url="https://github.com/$_repo/archive/v$_artifact"

_src="$PWD/src"
_build="$PWD/build/$_dir"
_out="$PWD/install/$_dir"

CCACHE="$(which ccache)"

if [ ! -d "$_out" ]; then
    mkdir -p "$_src" "$_build" "$_out"

    [ -f "$_artifact" ] || curl -L "$_url" -o "$_artifact"
    [ -d "$_src/$_dir" ] || tar xf "$_artifact" -C "$_src"

    cmake -S "$_src/$_dir" -B "$_build" \
        -DCMAKE_INSTALL_PREFIX="$_out" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTS=OFF \
        -DCMAKE_CXX_COMPILER_LAUNCHER="$CCACHE" \
        -DCMAKE_C_COMPILER_LAUNCHER="$CCACHE" \
        -G Ninja

    cmake --build "$_build"
    cmake --install "$_build"
fi

export VULKAN_LOADER_DIR="$_out"
