#!/bin/sh
# Runs the script named like this launcher (stress-test -> mac_stress_test.py, ...)
# with the bundled Python and the bundled ffmpeg. Works under sudo, which
# resets PATH: the bundle's bin/ is put back in front here.
here=$(cd "$(dirname "$0")" && pwd)
case "$(basename "$0")" in
    stress-test)      script=mac_stress_test.py ;;
    app-monitor)      script=app_monitor_share.py ;;
    ffmpeg-hour-test) script=ffmpeg_hour_test.py ;;
    *) echo "unknown launcher name: $0" >&2; exit 2 ;;
esac
PATH="$here/bin:$PATH"
export PATH
exec "$here/python/bin/python3" "$here/$script" "$@"
