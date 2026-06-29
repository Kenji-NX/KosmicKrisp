#!/bin/sh -e

: "${VERSION:?VERSION is required}"

_out="$PWD/out"
_lib="$_out/lib"
_icd="$_out/vulkan/icd.d"
_artifacts="$PWD/artifacts"

rm -rf "$_out"
mkdir -p "$_lib" "$_icd" "$_artifacts"

find install -type f -name '*.dylib' -exec cp {} "$_lib" \;
find install -type f -name '*icd*json' -exec cp {} "$_icd" \;

rm "$_lib/libSPIRV-Tools-shared.dylib"

mv "$_lib/libvulkan.1"*.dylib "$_lib/libvulkan.1.dylib"
find "$_icd" -type f -exec sed -i '' \
    's|"library_path": .*\(lib.*\.dylib\)"|"library_path": "../../../Frameworks/\1"|g' {} \;

# TODO: FIX ICD lib path to ../../Frameworks/blah.dylib

cd out
tar --zstd -cf "$_artifacts"/KosmicKrisp-"$VERSION".tar.zst ./*
