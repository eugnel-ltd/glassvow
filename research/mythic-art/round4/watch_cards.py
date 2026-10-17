"""Create source inspection sheets once each card's generation finishes."""
import json
import os
from pathlib import Path
import select
import subprocess
ROOT=Path(__file__).resolve().parent
cards=('silvering','unbrokenFlame','unbowed','knownRoad','cleanBreak')
fd=os.open(ROOT,os.O_RDONLY)
q=select.kqueue()
q.control([select.kevent(fd,filter=select.KQ_FILTER_VNODE,flags=select.KQ_EV_ADD|select.KQ_EV_CLEAR,fflags=select.KQ_NOTE_WRITE)],0,0)
seen=set()
try:
    while len(seen)<len(cards):
        for card in cards:
            status=ROOT/f'{card}-generation-status.txt'
            if card in seen or not status.exists(): continue
            if status.read_text().strip()!='complete':
                print(card+' generation failed; inspect status',flush=True)
                raise SystemExit(1)
            for script in ('geometry.py','inspect.py'):
                subprocess.run(['python3','-I',str(ROOT/script),card],check=True)
            seen.add(card)
            print(card+' sources and geometry ready for inspection',flush=True)
        if len(seen)<len(cards): q.control(None,1,None)
finally:
    os.close(fd); q.close()
