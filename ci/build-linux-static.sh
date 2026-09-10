#!/bin/sh
# Run inside the pinned Alpine builder, with the fio source as working directory.
set -eu

arch=${1:?usage: build-linux-static.sh amd64|arm64}
case "$arch:$(uname -m)" in
    amd64:x86_64|arm64:aarch64) ;;
    *) echo "Build architecture does not match $arch" >&2; exit 1 ;;
esac

apk add --no-cache build-base linux-headers file

./configure --build-static --disable-native --disable-numa --disable-rdma \
    --disable-rados --disable-rbd --disable-http --disable-gfapi \
    --disable-pmem --disable-libnfs --disable-libzbc --disable-xnvme \
    --disable-isal --disable-isal64 --disable-libblkio --disable-tcmalloc \
    --disable-dfs --disable-lex
make -j "$(nproc)"
make test
strip fio

file fio
readelf -h fio
readelf -l fio > static-program-headers.txt
readelf -d fio > static-dynamic-section.txt
if grep -q INTERP static-program-headers.txt || grep -q NEEDED static-dynamic-section.txt; then
    echo 'fio still requires a dynamic loader or shared libraries' >&2
    exit 1
fi

{
    ./fio --version
    printf 'Architecture: %s\n' "$arch"
    printf 'Source commit: %s\n' "${FIO_SOURCE_COMMIT:?}"
    printf 'Upstream musl fix: a84eece62edd46c1f4c8047f1052ac6181fc8b3e\n'
    printf 'Builder: %s\n' "${FIO_BUILDER_IMAGE:?}"
    printf 'Packaging commit: %s\n' "${FIO_PACKAGING_COMMIT:?}"
    printf '\nCompiler:\n'
    cc --version
    printf '\nInstalled packages:\n'
    apk info -v
    printf '\nConfigure flags:\n'
    head -n 3 config.log
} > BUILDINFO.txt
