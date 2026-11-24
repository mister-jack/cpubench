#!/bin/sh
# Runs the script named like this launcher (stress-test -> mac_stress_test.py, ...)
# with this folder's own Python and ffmpeg. Works under sudo, which resets
# PATH: the folder's bin/ is put back in front here, so bin/ffmpeg wins over
# any ffmpeg installed on the Mac.
#
# Python is python/ in the CI-built bundle, or .venv/ after ./bootstrap.sh.
here=$(cd "$(dirname "$0")" && pwd)
case "$(basename "$0")" in
    stress-test)      script=mac_stress_test.py ;;
    app-monitor)      script=app_monitor_share.py ;;
    ffmpeg-hour-test) script=ffmpeg_hour_test.py ;;
    *) echo "unknown launcher name: $0" >&2; exit 2 ;;
esac
if [ -x "$here/python/bin/python3" ]; then
    python="$here/python/bin/python3"
elif [ -x "$here/.venv/bin/python" ]; then
    python="$here/.venv/bin/python"
else
    echo "[!] No Python in $here. Run ./bootstrap.sh first." >&2
    exit 1
fi
PATH="$here/bin:$PATH"
export PATH
exec "$python" "$here/$script" "$@"
