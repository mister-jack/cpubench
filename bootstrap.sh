#!/bin/sh
# Sets this folder up to run the tests on an Apple Silicon Mac without
# Homebrew or a system Python. Everything it downloads stays in this folder.
#
#   1. Put the uv binary (macOS arm64, "aarch64-apple-darwin") at  bin/uv
#   2. ./bootstrap.sh                  (no sudo)
#   3. sudo ./stress-test
#
# What it does:
#   * uv downloads a standalone Python into .python/ and installs the
#     packages pinned in uv.lock into .venv/
#   * finds ffmpeg: bin/ffmpeg if you put one there, else one already on
#     this Mac. With --build-ffmpeg it builds bin/ffmpeg from source
#     (needs Apple's Command Line Tools; 5-10 minutes).
#   * writes three launchers: ./stress-test, ./app-monitor, ./ffmpeg-hour-test
#
# Safe to run again, e.g. after moving the folder or pulling new code.
# To undo it, delete .python/ .venv/ .uv-cache/ and the three launchers.
set -eu

PYTHON_VERSION=${PYTHON_VERSION:-3.13}

die() { echo "[!] $*" >&2; exit 1; }

build_ffmpeg=no
for arg in "$@"; do
    case "$arg" in
        --build-ffmpeg) build_ffmpeg=yes ;;
        -h|--help) sed -n '2,/^set -eu/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $arg (see --help)" ;;
    esac
done

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
uv="$here/bin/uv"

[ "$(uname -s)" = Darwin ] || die "This only runs on macOS."
[ "$(uname -m)" = arm64 ] ||
    echo "[!] This Mac is $(uname -m), not Apple Silicon. Carrying on, but bin/uv must match it."
# Under sudo everything created here would belong to root.
[ "$(id -u)" -ne 0 ] || die "Run bootstrap without sudo. Only the test itself needs sudo."

[ -f "$uv" ] || die "bin/uv not found. Put the uv binary for this Mac at:
    $uv
    It's in uv-aarch64-apple-darwin.tar.gz at https://github.com/astral-sh/uv/releases"
[ -x "$uv" ] || die "bin/uv isn't executable. Fix with:  chmod +x '$uv'"
if xattr -p com.apple.quarantine "$uv" >/dev/null 2>&1; then
    die "macOS has quarantined bin/uv (it was downloaded with a browser) and won't run it.
    If you trust where it came from, clear the flag and run bootstrap again:
        xattr -d com.apple.quarantine '$uv'"
fi
"$uv" --version >/dev/null 2>&1 || die "bin/uv doesn't run on this Mac. Is it the macOS $(uname -m) build?"
echo "[-] Using $("$uv" --version)"

# Keep Python, the environment and uv's cache inside this folder, and never
# fall back to a Python that happens to be installed on this Mac.
export UV_PYTHON_INSTALL_DIR="$here/.python"
export UV_PROJECT_ENVIRONMENT="$here/.venv"
export UV_CACHE_DIR="$here/.uv-cache"
export UV_PYTHON_PREFERENCE=only-managed

echo "[-] Installing Python $PYTHON_VERSION and the packages pinned in uv.lock"
"$uv" sync --frozen --no-dev --python "$PYTHON_VERSION" --compile-bytecode
[ -x "$here/.venv/bin/python" ] || die "uv finished but .venv/bin/python is missing."

if [ "$build_ffmpeg" = yes ]; then
    sh "$here/ci/build-ffmpeg.sh" "$here/bin"
fi

for name in stress-test app-monitor ffmpeg-hour-test; do
    cp "$here/ci/launcher.sh" "$here/$name"
    chmod 755 "$here/$name"
done
echo "[-] Wrote launchers: ./stress-test  ./app-monitor  ./ffmpeg-hour-test"
echo

# The script's own check covers Python, the packages and ffmpeg with libx264.
if "$here/stress-test" --check; then
    echo
    echo "Done. Run the test with:  sudo ./stress-test"
else
    echo
    echo "[!] Python is set up, but the check above found a problem."
    echo "    If it's ffmpeg, do one of these and run ./bootstrap.sh again:"
    echo "      * put an arm64 ffmpeg that has libx264 at  bin/ffmpeg"
    echo "      * ./bootstrap.sh --build-ffmpeg   (builds it; needs: xcode-select --install)"
    exit 1
fi
