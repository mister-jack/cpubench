
## mac_stress_test.py

how does this Mac hold up under a long video encode?

The script records CPU load, chip temperature and (with sudo) GPU load, clock
speed and power. After a short idle baseline it starts a software H.264 encode
with ffmpeg and keeps it running for the test length. Then it stops recording,
stops ffmpeg and saves graphs plus a summary to a new folder on your Desktop.

```
  0:00         recording starts (idle baseline)
  0:30         ffmpeg encode starts            (--warmup, default 30 s)
  0:30 + 30m   recording stops, ffmpeg stops   (--duration, default 1800 s)
               graphs, CSV and summary are saved
```

Press Ctrl-C at any time to end early. You still get graphs for what was
recorded.

**REQUIREMENTS**
* A Mac. Apple Silicon gives every graph. On an Intel Mac you get CPU load
  and encode speed only.
* Python 3 with psutil and matplotlib
* ffmpeg with libx264 (Homebrew's ffmpeg has it)

**SETUP WITHOUT HOMEBREW (once)**

  On an Apple Silicon Mac, `bootstrap.sh` sets everything up inside this
  folder using [uv](https://github.com/astral-sh/uv). No Homebrew or system
  Python needed.

1. Put two macOS arm64 binaries in the `bin` folder here:
   * `bin/uv`, from `uv-aarch64-apple-darwin.tar.gz` on uv's releases page
   * `bin/ffmpeg`, any arm64 build that includes libx264
2. Run, without sudo:
   ```
   ./bootstrap.sh
   ```
   It checks both binaries run and that ffmpeg has libx264, downloads a
   standalone Python into `.python/`, installs the packages pinned in
   `uv.lock` into `.venv/`, and writes three launchers: `./stress-test`,
   `./app-monitor` and `./ffmpeg-hour-test`. The launchers use that Python
   and `bin/ffmpeg`, never ones installed on the Mac.
3. Run the test with `sudo ./stress-test`. It takes the same options as
   `mac_stress_test.py` below.

  If macOS won't run a binary you downloaded with a browser, bootstrap stops
  and shows the command that clears its quarantine flag, e.g.
  `xattr -d com.apple.quarantine bin/ffmpeg`

**SETUP WITH HOMEBREW (once)**
1. Install Homebrew from https://brew.sh if you don't have it, then:
   brew install python ffmpeg
2. Make a Python environment with the two packages:
   python3 -m venv ~/stresstest-venv
   ~/stresstest-venv/bin/pip install psutil matplotlib
3. Check that everything is in place:
   ~/stresstest-venv/bin/python mac_stress_test.py --check

**RUNNING**
  Plug the Mac into power, quit other heavy apps and run, from the folder
  holding this file:

```
sudo ~/stresstest-venv/bin/python mac_stress_test.py
```
 
 sudo asks for your password. It's needed for GPU %, clock speed and power,
  which come from macOS's powermetrics tool. Without sudo you still get CPU
  load, temperature and encode speed.

  **Options**:
```
    --duration N   seconds of encoding (default 1800 = 30 minutes)
    --warmup N     idle seconds recorded before the encode starts (default 30)
    --encodes N    identical encodes run side by side (default 3). One 1080p
                   encode can't fill a chip with many cores; 3 fill an M5 Max.
                   Use --encodes 1 for a single-encode test.
    --out DIR      where to save results (default: your Desktop). Each run
                   makes its own dated folder inside DIR. DIR is created if
                   it doesn't exist.
    --check        check the requirements and exit
```

  For example, a one-hour test saved to ~/StressTests:
  
  `sudo ~/stresstest-venv/bin/python mac_stress_test.py --duration 3600 --out ~/StressTests`

**RESULTS**
  A new folder in the --out folder (your Desktop unless you choose another),
  e.g. ~/Desktop/mac_stress_test_2026-11-19_1430/:
  ```
  chart.png        every measurement
  chart_cores.png  the same, with the utilization panel showing only core types
  data.csv         one row per 2-second sample
  summary.txt      Mac model, chip, macOS and ffmpeg versions, settings, results
```

  The headline number is the average encode speed (fps). Higher is faster.
  Compare it only between runs with the same --duration and --encodes. If the
  fps in the last 5 minutes is well below the first 5, the Mac slowed down as
  it got hot (thermal throttling). The temperature and clock graphs show it.

  The encode is a synthetic 1920x1080 30 fps test pattern made by ffmpeg. It's
  encoded with libx264's medium preset at 6 Mbps and thrown away. Nothing is
  written to disk except the results.
