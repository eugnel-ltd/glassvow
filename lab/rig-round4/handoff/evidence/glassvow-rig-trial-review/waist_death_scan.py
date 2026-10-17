"""Check candidate articulated collapse poses before the first engine preview."""
import sys
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import round4_segments as seg
import gravewarden_round4_motion as mo
d=np.load(HERE/'gravewarden-fit.npz'); co,f=d['p'],d['f']; m=seg.measure(co,f); lab=seg.classify(m,co[f].mean(1)); lab,_=seg.clean(lab,f)
np.save(HERE/'gravewarden-fit-labels.npy',lab)
b=mo.Body(co,f,lab,m); v=mo.Volumes(b)
for k in (40,60,80,100,120):
    for a in (20,35,50):
        sp=dict(P=10,t=-a-10,k=k,toe=max(0,k-a-25),cx=35,arm=(-65,-35))
        p=b.grounded(dict(mo.stance(mo.vector(sp)),loc=(0,0,0))); q=b.posed(p)
        hit=v.collisions(p); hit={str(key):depth for key,depth in hit.items() if depth>.03}
        print(k,a,'root',round(p['loc'][2],3),'frame',round(float(q[b.bone=='Chest',2].min()),3),'hits',hit)
