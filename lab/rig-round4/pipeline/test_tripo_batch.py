"""Check the Studio batch spending guards without opening a browser or spending credits.
Run on the engine: python3 -I test_tripo_batch.py
"""
import os
from pathlib import Path
import subprocess
import tempfile

LANE = Path(__file__).resolve().parent.parent
SOURCE = (LANE / "pipeline/tripo_batch.sh").read_text()

def main():
    folder = tempfile.mkdtemp(prefix="batch-check-", dir=LANE / "pipeline")
    root = Path(folder)
    fake = root / "bin"
    fake.mkdir()
    runner = fake / "bun"
    runner.write_text('''#!/bin/bash
case "$1" in
  *cdp_account.ts) printf 'wallet.total_credit=%s\\n' "$TEST_WALLET" ;;
  *cdp_vis.ts) printf '{"vis":"visible"}\\n' ;;
  *studio_image_to_glb.ts)
    printf 'called\\n' >> "$TEST_CALLS"
    if [ "$TEST_RESULT" = success ]; then
      printf '{"ok":true,"summary":"test export"}\\n'
    else
      printf '{"ok":false,"summary":"test failure after Generate"}\\n'
      exit 2
    fi ;;
  *) exit 9 ;;
esac
''')
    runner.chmod(0o700)
    timeout = fake / "timeout"
    timeout.write_text('#!/bin/bash\nshift\nexec "$@"\n')
    timeout.chmod(0o700)
    script = root / "batch.sh"
    script.write_text(SOURCE.replace(
        "W=/Volumes/Coding/glassvow/.claude/worktrees/asset-manager", f"W={root}"
    ).replace(
        "LANE=/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab", f"LANE={root}"
    ).replace("BUN=~/.bun/bin/bun", f"BUN={runner}"))
    (root / "pipeline").mkdir()
    for name in ("first", "second"):
        ref = root / f"mobs/{name}/ref"
        ref.mkdir(parents=True)
        (ref / "body-a-clean.png").write_bytes(b"test reference")
    jobs = root / "jobs.txt"
    jobs.write_text("first body 8000\nsecond body 8000\n")
    calls = root / "calls.txt"

    def check(label, wallet, result, expected_calls, expected_code, existing=False):
        calls.write_text("")
        model = root / "mobs/first/tripo/body-a.glb"
        if existing:
            model.parent.mkdir(parents=True, exist_ok=True)
            model.write_bytes(b"existing model")
        env = dict(os.environ, ROOT="mobs", TEST_WALLET=str(wallet), TEST_RESULT=result,
                   TEST_CALLS=str(calls), PATH=f"{fake}:{os.environ['PATH']}")
        completed = subprocess.run(["bash", str(script), str(jobs)], env=env,
                                   text=True, capture_output=True, timeout=20)
        assert completed.returncode == expected_code, (label, completed.stdout, completed.stderr)
        assert len(calls.read_text().splitlines()) == expected_calls, (label, completed.stdout)
        print("PASS", label)

    check("successful tasks advance", 2560, "success", 2, 0)
    check("unknown result stops before next task", 2560, "failure", 1, 1)
    check("reserve blocks generation", 1119, "success", 0, 1)
    check("unreadable wallet blocks generation", "unknown", "success", 0, 1)
    check("existing model blocks regeneration", 2560, "success", 0, 1, existing=True)
    print("Test files retained:", root)


if __name__ == "__main__":
    main()
