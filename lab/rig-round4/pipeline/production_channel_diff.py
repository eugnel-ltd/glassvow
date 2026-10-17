import runpy
from pathlib import Path
import sys
import numpy as np

source = Path(__file__).with_name('stretch_round2_compare.py')
namespace = {}
exec(compile(source.read_text().split('first, second = map(load, sys.argv[1:])')[0], str(source), 'exec'), namespace)
first, second = map(namespace['load'], sys.argv[1:])
for clip, channels in first.items():
    for key, (times, values, interpolation) in channels.items():
        t, v, mode = second[clip][key]
        if values.shape != v.shape:
            print(clip, key, 'shape', values.shape, v.shape)
        elif not np.allclose(values, v, atol=2e-6):
            print(clip, key, 'max raw delta', float(np.abs(values-v).max()), 'quaternion sign-equivalent', bool(key[1]=='rotation' and np.all(np.minimum(np.linalg.norm(values-v,axis=1), np.linalg.norm(values+v,axis=1))<2e-5)))
