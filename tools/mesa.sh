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

mkdir -p build src

_commit=e8ab81cc3a1c35090e1534f356b8315456ba91a9
git clone https://gitlab.freedesktop.org/mesa/mesa src/mesa
cd src/mesa && git checkout $_commit && cd ../..

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
    BUILD_TYPE=release
fi

echo "-- Making $BUILD_TYPE build"

meson setup "$_build" "$_src" \
    --buildtype=$BUILD_TYPE \
    -D b_ndebug=$NDEBUG \
    -D strip=$NDEBUG \
    -D gallium-drivers= \
    -D vulkan-drivers=kosmickrisp \
    -D platforms=macos \
    -D valgrind=disabled \
    -D gallium-rusticl=false \
    -D static-libclc=all \
    -D video-codecs= \
    --native-file brew-llvm.ini \
    --prefer-static

meson compile -C "$_build"
meson install -C "$_build" --destdir "$_out"
