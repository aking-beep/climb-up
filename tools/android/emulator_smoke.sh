#!/bin/sh
# Runs the built game on a connected Android device or emulator and checks
# what a player would hit first: install, cold start, the landscape lock
# (with the device held in portrait), background and resume, rotating the
# device, a burst of random touches (monkey), and no crash in the log.
# Writes screenshots, logcat and a summary to OUT.
#
#   tools/android/emulator_smoke.sh build/godot-android/climb-up-x86_64.apk out/
#
# Used by .github/workflows/android.yml on an emulator; works the same on
# a phone plugged in over USB (adb).
set -u
APK=$1
OUT=$2
PKG=com.climbup.game
ACT=com.godot.game.GodotAppLauncher
mkdir -p "$OUT"
fails=0
pass() { echo "PASS  $1" | tee -a "$OUT/summary.txt"; }
fail() { echo "FAIL  $1" | tee -a "$OUT/summary.txt"; fails=$((fails + 1)); }
note() { echo "INFO  $1" | tee -a "$OUT/summary.txt"; }
shot() { adb exec-out screencap -p > "$OUT/$1.png"; }
rotation() { adb shell dumpsys window displays | grep -o -m1 "mCurrentRotation=[A-Z_0-9]*" | cut -d= -f2; }
alive() { adb shell pidof "$PKG" | tr -d '\r'; }

: > "$OUT/summary.txt"
note "device: $(adb shell getprop ro.product.model | tr -d '\r'), Android $(adb shell getprop ro.build.version.release | tr -d '\r') (API $(adb shell getprop ro.build.version.sdk | tr -d '\r')), $(adb shell getprop ro.product.cpu.abi | tr -d '\r')"

if adb install -r "$APK" > "$OUT/install.txt" 2>&1; then pass "install"; else fail "install: $(cat "$OUT/install.txt")"; fi

# Hold the device in portrait: the game must still come up in landscape.
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb logcat -c
# Every buffer, from the start, into a file (the device's own ring buffer
# rolls over during the touch test and would lose an early crash).
adb logcat -b all -v threadtime > "$OUT/logcat-full.txt" 2>&1 &
LOGCAT=$!
sdk=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
why_gone() {
  # Why the game's process ended, as Android recorded it (API 30+), and the
  # log lines about it.
  [ "$sdk" -ge 30 ] && adb shell dumpsys activity exit-info "$PKG" | head -40
  grep -E "$PKG|godot|Godot|AndroidRuntime|DEBUG *:|libc *:|ActivityManager|ActivityTaskManager|lowmemorykiller" "$OUT/logcat-full.txt" \
    | grep -v "commands.monkey" | tail -60
}

start=$(adb shell am start -W -n "$PKG/$ACT" | tr -d '\r')
echo "$start" > "$OUT/start.txt"
total=$(echo "$start" | grep -o "TotalTime: [0-9]*" | grep -o "[0-9]*")
note "cold start (activity drawn): ${total:-?} ms"
sleep 25
pid=$(alive)
if [ -n "$pid" ]; then pass "running 25 s after launch (pid $pid)"; else fail "not running after launch"; echo "--- why:"; why_gone; echo "---"; fi
shot 1-launch
r=$(rotation)
case "$r" in ROTATION_90|ROTATION_270) pass "landscape with the device in portrait ($r)";; *) fail "orientation is $r, not landscape";; esac

# Turn the device the other way up: still landscape (either way round is fine).
adb shell settings put system user_rotation 3
sleep 4
r=$(rotation)
case "$r" in ROTATION_90|ROTATION_270) pass "still landscape after turning the device ($r)";; *) fail "orientation is $r after turning the device";; esac
adb shell settings put system user_rotation 0
sleep 2

# Background and resume: the same process comes back.
adb shell input keyevent KEYCODE_HOME
sleep 6
adb shell am start -n "$PKG/$ACT" > /dev/null
sleep 8
if [ "$(alive)" = "$pid" ]; then pass "home and back: resumed the same process"; else fail "home and back: process changed ($pid -> $(alive))"; fi
shot 2-resumed

# Memory after start.
pss=$(adb shell dumpsys meminfo "$PKG" | grep -m1 "TOTAL PSS" | tr -s ' ' | cut -d' ' -f4)
[ -z "$pss" ] && pss=$(adb shell dumpsys meminfo "$PKG" | grep -m1 "TOTAL" | tr -s ' ' | cut -d' ' -f3)
note "memory (total PSS): ${pss:-?} KB"

# Random touches and drags, no system keys: the game must not crash.
adb shell monkey -p "$PKG" --pct-syskeys 0 --pct-appswitch 0 --pct-nav 0 --pct-majornav 0 \
  --throttle 120 -s 7 -v 1500 > "$OUT/monkey.txt" 2>&1
if grep -q "Monkey finished" "$OUT/monkey.txt" && ! grep -q "CRASH\|NOT RESPONDING" "$OUT/monkey.txt"; then
  pass "1500 random touches: no crash, no ANR"
else
  fail "monkey: $(grep -m3 'CRASH\|NOT RESPONDING\|aborted' "$OUT/monkey.txt" | tr '\n' ' ')"
fi
sleep 2
shot 3-after-touches
[ -n "$(alive)" ] && pass "still running after the touches" || fail "not running after the touches"

kill $LOGCAT 2> /dev/null
# Only the game's own crashes count (the monkey tool can crash on its own).
{ grep -E "Fatal signal.*\($PKG\)|ANR in $PKG" "$OUT/logcat-full.txt"
  grep -A2 "FATAL EXCEPTION" "$OUT/logcat-full.txt" | grep "Process: $PKG"; } > "$OUT/crashes.txt"
if [ -s "$OUT/crashes.txt" ]; then
  fail "the game crashed: $(head -3 "$OUT/crashes.txt" | tr '\n' ' ')"
  why_gone
else
  pass "no crash or ANR of the game in logcat"
fi
errs=$(grep -c "SCRIPT ERROR\|USER ERROR" "$OUT/logcat-full.txt")
[ "$errs" -eq 0 ] && pass "no Godot script errors in logcat" || fail "$errs Godot script errors in logcat"

echo "---"
cat "$OUT/summary.txt"
exit $fails
