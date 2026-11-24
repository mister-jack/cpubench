#!/bin/sh
# Builds a static arm64 ffmpeg with libx264 from source and puts it in OUTDIR.
# Used by the CI workflow and by `./bootstrap.sh --build-ffmpeg`.
#
#   ci/build-ffmpeg.sh OUTDIR
#
# Needs Apple's Command Line Tools (xcode-select --install) and a network
# connection. Takes roughly 5-10 minutes. Nothing is installed outside OUTDIR.
#
# The binary has only what the scripts use: the lavfi test source, libx264
# and the null output. It links nothing but macOS's own libraries.
set -eu

FFMPEG_VERSION=${FFMPEG_VERSION:-8.1.3}
# x264 has no releases; this is a commit on its "stable" branch.
X264_COMMIT=${X264_COMMIT:-b35605ace3ddf7c1a5d67a2eb553f034aef41d55}
# Oldest macOS the binary runs on (11.0 is the first Apple Silicon release).
MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
export MACOSX_DEPLOYMENT_TARGET

die() { echo "[!] $*" >&2; exit 1; }

[ $# -eq 1 ] || die "usage: $0 OUTDIR"
[ "$(uname -s)" = Darwin ] || die "This builds on macOS only."
[ "$(uname -m)" = arm64 ] || die "This builds on Apple Silicon only (this Mac is $(uname -m))."
# Without the Command Line Tools, cc/make/git are stubs that only pop up an install dialog.
xcode-select -p >/dev/null 2>&1 ||
    die "Apple's Command Line Tools are needed to build ffmpeg. Install them with:  xcode-select --install"

mkdir -p "$1"
out=$(cd "$1" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
prefix="$work/prefix"
jobs=$(sysctl -n hw.ncpu)

echo "[-] Building x264 ($X264_COMMIT)"
git init -q "$work/x264"
git -C "$work/x264" fetch -q --depth 1 https://code.videolan.org/videolan/x264.git "$X264_COMMIT"
git -C "$work/x264" checkout -q FETCH_HEAD
(
    cd "$work/x264"
    ./configure --prefix="$prefix" --enable-static --enable-pic --disable-cli \
        --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac
    make -j"$jobs"
    make install
)

echo "[-] Building ffmpeg $FFMPEG_VERSION"
curl -fsSL "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" -o "$work/ffmpeg.tar.xz"
mkdir "$work/ffmpeg"
tar -xf "$work/ffmpeg.tar.xz" -C "$work/ffmpeg" --strip-components 1
(
    cd "$work/ffmpeg"
    # --disable-autodetect keeps Homebrew libraries that happen to be on this
    # Mac out of the binary. x264 is found through pkg-config when there is
    # one and through the -I/-L flags when there isn't.
    PKG_CONFIG_PATH="$prefix/lib/pkgconfig" ./configure \
        --prefix="$prefix" \
        --arch=arm64 \
        --enable-gpl --enable-libx264 \
        --enable-static --disable-shared \
        --pkg-config-flags=--static \
        --extra-cflags="-I$prefix/include" \
        --extra-ldflags="-L$prefix/lib" \
        --disable-autodetect \
        --disable-doc --disable-debug \
        --disable-ffplay --disable-ffprobe \
        --disable-network \
        --disable-indevs --enable-indev=lavfi \
        --disable-outdevs
    make -j"$jobs"
)

cp "$work/ffmpeg/ffmpeg" "$out/ffmpeg"
strip "$out/ffmpeg"
# strip invalidates the linker's ad-hoc signature, and arm64 Macs refuse to
# run unsigned code, so sign again.
codesign --force --sign - "$out/ffmpeg"
chmod 755 "$out/ffmpeg"

# Prove it can do the one job the scripts give it.
"$out/ffmpeg" -hide_banner -nostdin -loglevel error \
    -f lavfi -i testsrc2=size=1920x1080:rate=30 -frames:v 30 \
    -c:v libx264 -preset medium -pix_fmt yuv420p -f null - ||
    die "The ffmpeg that was just built can't run a libx264 test encode."

{
    echo "ffmpeg: $FFMPEG_VERSION (https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz)"
    echo "x264: commit $X264_COMMIT (https://code.videolan.org/videolan/x264)"
    echo "minimum macOS: $MACOSX_DEPLOYMENT_TARGET"
} > "$out/ffmpeg-build-info.txt"

echo "[-] Built $out/ffmpeg"
