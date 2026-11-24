#!/bin/sh
# Sets this folder up to run the tests on an Apple Silicon Mac without
# Homebrew or a system Python. Everything it downloads stays in this folder.
#
#   1. Put two macOS arm64 binaries in bin/:
#        bin/uv       from uv-aarch64-apple-darwin.tar.gz at
#                     https://github.com/astral-sh/uv/releases
#        bin/ffmpeg   any arm64 build that includes libx264
#   2. ./bootstrap.sh                  (no sudo)
#   3. sudo ./stress-test
#
# What it does:
#   * checks bin/uv and bin/ffmpeg run on this Mac, and that ffmpeg has libx264
#   * uv downloads a standalone Python into .python/ and installs the
#     packages pinned in uv.lock into .venv/
#   * writes three launchers: ./stress-test, ./app-monitor, ./ffmpeg-hour-test
#     They use that Python and bin/ffmpeg, never ones installed on the Mac.
#
# Safe to run again, e.g. after moving the folder or pulling new code.
# To undo it, delete .python/ .venv/ .uv-cache/ and the three launchers.
set -eu

PYTHON_VERSION=${PYTHON_VERSION:-3.13}

die() { echo "[!] $*" >&2; exit 1; }

for arg in "$@"; do
    case "$arg" in
        -h|--help) sed -n '2,/^set -eu/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $arg (see --help)" ;;
    esac
done

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
uv="$here/bin/uv"
ffmpeg="$here/bin/ffmpeg"

[ "$(uname -s)" = Darwin ] || die "This only runs on macOS."
[ "$(uname -m)" = arm64 ] ||
    echo "[!] This Mac is $(uname -m), not Apple Silicon. Carrying on, but the binaries in bin/ must match it."
# Under sudo everything created here would belong to root.
[ "$(id -u)" -ne 0 ] || die "Run bootstrap without sudo. Only the test itself needs sudo."

# A binary you supplied: present, executable, not quarantined.
check_binary() {
    [ -f "$1" ] || die "bin/$2 not found. Put it at:
    $1
    $3"
    [ -x "$1" ] || die "bin/$2 isn't executable. Fix with:  chmod +x '$1'"
    if xattr -p com.apple.quarantine "$1" >/dev/null 2>&1; then
        die "macOS has quarantined bin/$2 (it was downloaded with a browser) and won't run it.
    If you trust where it came from, clear the flag and run bootstrap again:
        xattr -d com.apple.quarantine '$1'"
    fi
}

check_binary "$uv" uv "It's in uv-aarch64-apple-darwin.tar.gz at https://github.com/astral-sh/uv/releases"
"$uv" --version >/dev/null 2>&1 || die "bin/uv doesn't run on this Mac. Is it the macOS $(uname -m) build?"
echo "[-] Using $("$uv" --version)"

check_binary "$ffmpeg" ffmpeg "It must be a macOS arm64 build that includes libx264."
"$ffmpeg" -hide_banner -version >/dev/null 2>&1 ||
    die "bin/ffmpeg doesn't run on this Mac. Is it the macOS $(uname -m) build?
    (If it came with .dylib files, they have to stay next to it.)"
"$ffmpeg" -hide_banner -encoders 2>/dev/null | grep -q libx264 ||
    die "bin/ffmpeg has no libx264 encoder, which the test needs. Use a build that includes it."
if [ "$(uname -m)" = arm64 ] && ! file "$ffmpeg" | grep -q arm64; then
    echo "[!] bin/ffmpeg is an Intel build. It runs under Rosetta, but far slower, so the"
    echo "    results won't mean much. Replace it with an arm64 build."
fi
echo "[-] Using $("$ffmpeg" -hide_banner -version | head -n 1)"

# Keep Python, the environment and uv's cache inside this folder, and never
# fall back to a Python that happens to be installed on this Mac.
export UV_PYTHON_INSTALL_DIR="$here/.python"
export UV_PROJECT_ENVIRONMENT="$here/.venv"
export UV_CACHE_DIR="$here/.uv-cache"
export UV_PYTHON_PREFERENCE=only-managed

echo "[-] Installing Python $PYTHON_VERSION and the packages pinned in uv.lock"
"$uv" sync --frozen --no-dev --python "$PYTHON_VERSION" --compile-bytecode
[ -x "$here/.venv/bin/python" ] || die "uv finished but .venv/bin/python is missing."

for name in stress-test app-monitor ffmpeg-hour-test; do
    cp "$here/ci/launcher.sh" "$here/$name"
    chmod 755 "$here/$name"
done
echo "[-] Wrote launchers: ./stress-test  ./app-monitor  ./ffmpeg-hour-test"
echo

# The script's own check, through the launcher, proves the pieces work together.
"$here/stress-test" --check || die "Setup finished, but the check above found a problem."
echo
echo "Done. Run the test with:  sudo ./stress-test"
