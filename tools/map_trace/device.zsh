# Map trace: device helpers for a measuring batch on the iPad 8, sourced by a
# lane's batch script (docs/dev-tools.md, "Map trace"). QA app only
# (io.fol2.glassvow.qa); never the production bundle or its container.
#
# The caller sets OUT (a scratch folder for this batch) and holds the shared
# batch lock for the whole batch. The iPad's identifier is looked up at run time
# into $UDID and redacted from every log; nothing here writes it to a file.
#
#   mt_install <ipa>                  install a QA .ipa (refuses any other bundle id)
#   mt_launch <label> [game args]     launch with a fresh nonce, wait, pull the
#                                     probe rows; keeps them only if they echo it
#   mt_trace <label> <s> <delay> [game args]
#                                     launch as above and record a Metal System
#                                     Trace of <s> seconds, <delay> seconds in;
#                                     a recording that ends early (the device
#                                     "disconnected") is thrown away and retried
#   mt_export <label>                 export the trace's tables and analyse them
#                                     (frames.py skips the first MT_SKIP_S
#                                     seconds, default 1.5: the recording-start
#                                     hitch)
#
# MT_SHOT=<seconds> makes mt_launch take a screenshot that far in; MT_WAIT is the
# first wait before pulling rows (default 40 s).

MT_DIR=${0:A:h}
MT_QA=io.fol2.glassvow.qa
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

mt_udid() {
  xcrun devicectl list devices --quiet --json-output - 2>/dev/null | python3 -c '
import json, sys
found = [d["hardwareProperties"]["udid"] for d in json.load(sys.stdin)["result"]["devices"]
         if (d.get("hardwareProperties") or {}).get("productType") == "iPad11,6"]
print(found[0] if len(found) == 1 else "")'
}

mt_redact() { sed "s/${UDID:-no-udid}/<device>/g"; }

## The iPad's name, which xctrace also takes in place of its identifier.
mt_name() {
  xcrun devicectl list devices --quiet --json-output - 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin)["result"]["devices"]:
    if (d.get("hardwareProperties") or {}).get("udid") == sys.argv[1]:
        print(d["deviceProperties"]["name"])' "$UDID"
}

mt_install() {
  local ipa=$1 id
  id=$(unzip -p "$ipa" Payload/glassvow.app/Info.plist | plutil -extract CFBundleIdentifier raw -o - -)
  [[ "$id" == "$MT_QA" ]] || { echo "mt_install: $ipa is $id, not $MT_QA; refusing"; return 1; }
  local i
  for i in 1 2 3; do
    xcrun devicectl device install app --device $UDID "$ipa" 2>&1 | mt_redact > $OUT/install.log && return 0
    sleep 5
  done
  echo "mt_install: failed, see $OUT/install.log"; return 1
}

_mt_pull() {
  xcrun devicectl device copy from --device $UDID --domain-type appDataContainer \
    --domain-identifier $MT_QA --source Documents/$1 --destination $2 >/dev/null 2>&1
}

_mt_fresh() { grep -q "\"nonce\":\"$2\"" $1 2>/dev/null && grep -q '"probe":"done"' $1; }

## Launches the QA app with a fresh nonce. Sets MT_NONCE and MT_PID (empty if
## the launch failed); call it directly, never in a subshell.
_mt_start() {
  local label=$1; shift
  MT_NONCE=$label-$RANDOM$RANDOM
  xcrun devicectl device process launch --terminate-existing --device $UDID \
    --json-output $OUT/.launch.json $MT_QA -- "$@" --probe-nonce=$MT_NONCE 2>&1 | mt_redact > $OUT/$label.launch.txt
  MT_PID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["result"]["process"]["processIdentifier"])' \
    $OUT/.launch.json 2>/dev/null)
  rm -f $OUT/.launch.json
}

## Pulls the probe's rows until they echo this launch's nonce and are done.
_mt_rows() {
  local label=$1 i
  rm -f $OUT/$label.jsonl
  for i in $(seq 1 30); do
    _mt_pull trace_probe.jsonl $OUT/$label.jsonl
    _mt_fresh $OUT/$label.jsonl $MT_NONCE && { echo "== $label nonce $MT_NONCE: rows fresh"; return 0; }
    sleep 4
  done
  echo "== $label nonce $MT_NONCE: rows MISSING"; return 1
}

mt_launch() {
  local label=$1; shift
  _mt_start $label "$@"
  [[ -n "$MT_PID" ]] || { echo "== $label: launch failed"; return 1; }
  if [[ -n "${MT_SHOT:-}" ]]; then
    sleep $MT_SHOT
    xcrun devicectl device capture screenshot --device $UDID --destination $OUT/$label.png >/dev/null 2>&1
    sleep $(( ${MT_WAIT:-40} > MT_SHOT ? ${MT_WAIT:-40} - MT_SHOT : 0 ))
  else
    sleep ${MT_WAIT:-40}
  fi
  _mt_rows $label
}

## The recorded window from the trace's table of contents: "<seconds> <why it
## ended>", the reason with its spaces as underscores.
_mt_window() {
  xcrun xctrace export --input $1 --toc 2>/dev/null | python3 -c '
import re, sys
t = sys.stdin.read()
d = re.search(r"<duration>([\d.]+)</duration>", t)
r = re.search(r"<end-reason>([^<]*)</end-reason>", t)
print(d.group(1) if d else "0", (r.group(1) if r else "unknown").replace(" ", "_"))'
}

## A recording sometimes fails to start ("Timed out waiting for device to
## boot") or ends early ("Device got disconnected, ending recording..."), which
## leaves a short window read across the recording-start hitch. Each of up to
## three attempts relaunches with a fresh nonce; a trace is kept only when it
## ran its whole time limit (its window is written to <label>.window), and the
## later attempts name the device rather than give its identifier.
mt_trace() {
  local label=$1 seconds=$2 delay=$3 attempt target; shift 3
  for attempt in 1 2 3; do
    target=$UDID; (( attempt > 1 )) && target=$(mt_name)
    _mt_start $label "$@"
    [[ -n "$MT_PID" ]] || { echo "== $label: launch failed"; return 1; }
    echo $MT_PID > $OUT/$label.pid
    sleep $delay
    rm -rf $OUT/$label.trace
    # devicectl lets its tunnel drop between commands, and xctrace then waits
    # for the device to "boot" until it times out: bring the tunnel and the
    # developer services up just before recording.
    xcrun devicectl device info ddiServices --device $UDID >/dev/null 2>&1
    # xctrace cannot attach to a device pid ("Cannot find process for provided
    # pid"): it records every process, and the analysis keeps this pid.
    xcrun xctrace record --device "$target" --template 'Metal System Trace' --all-processes \
      --time-limit ${seconds}s --output $OUT/$label.trace --no-prompt 2>&1 | mt_redact > $OUT/$label.xctrace.log
    _mt_rows $label
    if [[ -d $OUT/$label.trace ]]; then
      local window=($(_mt_window $OUT/$label.trace))
      echo "${window[1]} s, ${window[2]}" > $OUT/$label.window
      if [[ ${window[2]} == Time_limit_reached ]] && (( ${window[1]} >= 0.95 * seconds )); then
        echo "== $label: trace ${window[1]} s"; return 0
      fi
      echo "== $label: trace cut short (${window[1]} s, ${window[2]}; attempt $attempt)"
      mv $OUT/$label.xctrace.log $OUT/$label.short$attempt.xctrace.log
      rm -rf $OUT/$label.trace
    else
      echo "== $label: no trace (attempt $attempt): $(tail -1 $OUT/$label.xctrace.log)"
    fi
  done
  return 1
}

mt_export() {
  local label=$1 x=$OUT/x-$1 s
  mkdir -p $x
  for s in metal-gpu-intervals metal-application-encoders-list displayed-surfaces-interval \
      gpu-performance-state-intervals gpu-performance-device-state-intervals \
      gpu-performance-state-info device-thermal-state-intervals; do
    [[ -s $x/$s.xml ]] || xcrun xctrace export --input $OUT/$label.trace \
      --xpath "/trace-toc/run[@number=\"1\"]/data/table[@schema=\"$s\"]" > $x/$s.xml 2>/dev/null
  done
  local p="glassvow ($(cat $OUT/$label.pid))"
  python3 $MT_DIR/frames.py $x "$p" --skip-s ${MT_SKIP_S:-1.5} --json $OUT/$label.frames.json \
    > $OUT/$label.passes.txt 2>&1
  python3 $MT_DIR/display.py $x "$p" > $OUT/$label.display.txt 2>&1
}
