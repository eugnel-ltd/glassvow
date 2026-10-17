"""Emit completed generation records from macOS file events, without polling."""
import json
import os
from pathlib import Path
import select
ROOT = Path(__file__).resolve().parent
ledger = ROOT/'generation-count.jsonl'
fd = os.open(ledger, os.O_RDONLY)
queue = select.kqueue()
queue.control([select.kevent(fd, filter=select.KQ_FILTER_VNODE, flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR, fflags=select.KQ_NOTE_WRITE)], 0, 0)
seen = set()
try:
    while True:
        try:
            records = [json.loads(s) for s in ledger.read_text().splitlines()]
        except (json.JSONDecodeError, OSError):
            records = []
        for r in records:
            key = (r['call'], r['status'])
            if r['status'] != 'running' and key not in seen:
                print(f"Generation {r['call']}: {r['name']} {r['status']} ({r.get('seconds', 0)} s); disk at start {r['free_gib']} GiB", flush=True)
                seen.add(key)
        if records and (records[-1]['status'] == 'failed' or records[-1]['name'] == 'cleanBreak-A-subject' and records[-1]['status'] == 'complete'):
            break
        queue.control(None, 1, None)
finally:
    os.close(fd)
    queue.close()
