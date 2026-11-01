#!/bin/sh -e

# shellcheck disable=SC1091

brew install meson cmake python-setuptools llvm ninja lld libclc vulkan-headers spirv-llvm-translator ccache pkg-config
python3 -m venv venv

. venv/bin/activate

. tools/spirv.sh

pip install mako setuptools pyyaml

LLVM_PREFIX="$(brew --prefix llvm)"
ZSTD_PREFIX="$(brew --prefix zstd)"
# TODO
CCACHE="$(which ccache)"

export CC="$LLVM_PREFIX/bin/clang"
export CXX="$LLVM_PREFIX/bin/clang++"

export AR="$LLVM_PREFIX/bin/llvm-ar"
export NM="$LLVM_PREFIX/bin/llvm-nm"
export RANLIB="$LLVM_PREFIX/bin/llvm-ranlib"
export STRIP="$LLVM_PREFIX/bin/llvm-strip"
export LD="$LLVM_PREFIX/bin/ld.lld"

cat << EOF > brew-llvm.ini
[binaries]
llvm-config = '$LLVM_PREFIX/bin/llvm-config'
c = ['$CCACHE', '$CC']
cpp = ['$CCACHE', '$CXX']
ar = '$AR'
nm = '$NM'
strip = '$STRIP'
ranlib = '$RANLIB'
ld = '$LD'
EOF

cat brew-llvm.ini

cat << EOF > ios.ini
[binaries]
c      = ['xcrun', '-sdk', 'iphoneos', 'clang', '-arch', 'arm64']
cpp    = ['xcrun', '-sdk', 'iphoneos', 'clang++', '-arch', 'arm64']
objc   = ['xcrun', '-sdk', 'iphoneos', 'clang', '-arch', 'arm64']
objcpp = ['xcrun', '-sdk', 'iphoneos', 'clang++', '-arch', 'arm64']
ar     = ['xcrun', '-sdk', 'iphoneos', 'ar']
ranlib = ['xcrun', '-sdk', 'iphoneos', 'ranlib']
strip  = ['xcrun', '-sdk', 'iphoneos', 'strip']

[properties]
root = '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk'
has_function_printf = true
needs_exe_wrapper = true

[host_machine]
system = 'darwin'
subsystem = 'ios'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'

[built-in options]
c_args      = ['-miphoneos-version-min=26.0']
cpp_args    = ['-miphoneos-version-min=26.0']
objc_args   = ['-miphoneos-version-min=26.0']
objcpp_args = ['-miphoneos-version-min=26.0']
c_link_args = ['-miphoneos-version-min=26.0']
cpp_link_args = ['-miphoneos-version-min=26.0']
EOF

mkdir -p build src

_branch=kk-ios/26.2
_url_primary=https://github.com/Kenji-NX/mesa
_url_fallback=https://gitlab.com/kenji-nx/mesa
git clone -b $_branch --single-branch $_url_primary src/mesa \
  || git clone -b $_branch --single-branch $_url_fallback src/mesa
cd src/mesa && git checkout $_branch && cd ../..

_src="$PWD/src/mesa"
_build="$PWD/build/mesa"
_out="$PWD/install/mesa"

export PATH="$LLVM_PREFIX/bin:$PATH"

export CFLAGS="-g1 -fno-asynchronous-unwind-tables"
export CXXFLAGS="-g1 -fno-asynchronous-unwind-tables"
export LDFLAGS="-fuse-ld=lld"

export LIBRARY_PATH="${ZSTD_PREFIX}/lib${LIBRARY_PATH:+:${LIBRARY_PATH}}"
export PKG_CONFIG_PATH="$SPIRV_DIR/lib/pkgconfig"

# Debug options.
if [ "${DEBUG:-false}" = 'true' ]; then
    NDEBUG=false
    BUILD_TYPE=debug
else
    NDEBUG=true
    BUILD_TYPE=minsize
fi

echo "-- Making $BUILD_TYPE build"

_build_native="$PWD/build/mesa-native"
_out_native="$PWD/install/native"

# Stage 1: Host-side compilers
meson setup "$_build_native" "$_src" \
    --buildtype=$BUILD_TYPE \
    --native-file brew-llvm.ini \
    --prefix "$_out_native" \
    -D gallium-drivers= \
    -D vulkan-drivers=kosmickrisp \
    -D platforms=macos \
    -D valgrind=disabled \
    -D gallium-rusticl=false \
    -D static-libclc=all \
    -D video-codecs= \
    -D zstd=disabled -D expat=disabled -D xmlconfig=disabled \
    -D install-mesa-clc=true \
    -D install-precomp-compiler=true

meson install -C "$_build_native"
export PATH="$_out_native/bin:$PATH"

unset CC CXX AR NM RANLIB STRIP LD CFLAGS CXXFLAGS LDFLAGS LIBRARY_PATH

# Stage 2: Cross-compile to iOS
meson setup "$_build" "$_src" \
    --buildtype=$BUILD_TYPE \
    --cross-file ios.ini \
    -D b_ndebug=$NDEBUG \
    -D strip=$NDEBUG \
    -D gallium-drivers= \
    -D vulkan-drivers=kosmickrisp \
    -D platforms=macos \
    -D valgrind=disabled \
    -D gallium-rusticl=false \
    -D video-codecs= \
    -D llvm=disabled \
    -D zstd=disabled -D expat=disabled -D xmlconfig=disabled \
    -D mesa-clc=system \
    -D precomp-compiler=system

meson compile -C "$_build"
meson install -C "$_build" --no-rebuild --destdir "$_out"