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
#                                     Trace of <s> seconds, <delay> seconds in
#   mt_export <label>                 export the trace's tables and analyse them
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

## A recording sometimes fails to start ("Timed out waiting for device to
## boot"); each of up to three attempts relaunches with a fresh nonce, and the
## later ones name the device rather than give its identifier.
mt_trace() {
  local label=$1 seconds=$2 delay=$3 attempt target; shift 3
  for attempt in 1 2 3; do
    target=$UDID; (( attempt > 1 )) && target=$(mt_name)
    _mt_start $label "$@"
    [[ -n "$MT_PID" ]] || { echo "== $label: launch failed"; return 1; }
    echo $MT_PID > $OUT/$label.pid
    sleep $delay
    rm -rf $OUT/$label.trace
    # xctrace cannot attach to a device pid ("Cannot find process for provided
    # pid"): it records every process, and the analysis keeps this pid.
    xcrun xctrace record --device "$target" --template 'Metal System Trace' --all-processes \
      --time-limit ${seconds}s --output $OUT/$label.trace --no-prompt 2>&1 | mt_redact > $OUT/$label.xctrace.log
    _mt_rows $label
    [[ -d $OUT/$label.trace ]] && return 0
    echo "== $label: no trace (attempt $attempt): $(tail -1 $OUT/$label.xctrace.log)"
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
  python3 $MT_DIR/frames.py $x "$p" > $OUT/$label.passes.txt 2>&1
  python3 $MT_DIR/display.py $x "$p" > $OUT/$label.display.txt 2>&1
}
