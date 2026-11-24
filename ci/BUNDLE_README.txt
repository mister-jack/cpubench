cpubench - self-contained bundle for Apple Silicon Macs (arm64, macOS 11+)
==========================================================================

Nothing to install: Python, psutil, matplotlib and ffmpeg (with libx264) are
all inside this folder. No Homebrew needed.

FIRST, ONCE
  If you downloaded this with a web browser, macOS quarantines it and will
  refuse to run the unsigned binaries. Clear that from Terminal:

      xattr -dr com.apple.quarantine /path/to/this/folder

  Unpack with `tar -xzf` (or double-click the .tar.gz). Keep the folder
  together; you can move or rename it as a whole.

RUN
      ./stress-test --check        check everything is in place
      sudo ./stress-test           the 30-minute stress test
      ./app-monitor                the monitor on its own
      ./ffmpeg-hour-test           plain one-hour ffmpeg run

  All options are the same as in README.md, e.g.
      sudo ./stress-test --duration 3600 --out ~/StressTests

WHAT'S INSIDE
  stress-test, app-monitor, ffmpeg-hour-test   launchers
  *.py                                         the scripts
  python/     standalone CPython (python-build-standalone, installed by uv)
              with psutil and matplotlib at the versions pinned in uv.lock
  bin/ffmpeg  static ffmpeg built with libx264 only (no other codecs/devices)
  VERSIONS.txt  exact versions and the commit this was built from

LICENCES
  bin/ffmpeg is FFmpeg built with --enable-gpl and linked against x264, so
  that binary is licensed under the GNU GPL v2 or later. Sources:
  https://ffmpeg.org/releases/ and https://code.videolan.org/videolan/x264
  (exact versions in VERSIONS.txt). CPython is under the PSF licence; see
  python/lib/python3.*/LICENSE.txt. Package licences are in their
  *.dist-info folders under python/lib/python3.*/site-packages.
