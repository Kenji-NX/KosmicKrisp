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
_tagged=true

if [ "$_tagged" = "true" ] ; then
    _commit=26.1.2
    _artifact=mesa-$_commit.tar.xz
    _download=https://archive.mesa3d.org/$_artifact
else
    _repo=mesa/mesa
    _commit=b3d356db66d92ff99ad5b3274569761290232899
    _artifact=mesa-$_commit.tar.gz
    _download="https://gitlab.freedesktop.org/$_repo/-/archive/$_commit/$_artifact"
fi

_src="$PWD/src/mesa-$_commit"
_build="$PWD/build/mesa-$_commit"
_out="$PWD/install/mesa-$_commit"

[ -f $_artifact ] || curl "$_download" -o $_artifact --fail
[ -d "$_build" ] || tar xf $_artifact -C src

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
    -D video-codecs=h264dec,vp9dec \
    --native-file brew-llvm.ini \
    --prefer-static

meson compile -C "$_build"
meson install -C "$_build" --destdir "$_out"
