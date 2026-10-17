# Compare all exported channels except explicitly authored rotation changes.
import sys
from pathlib import Path

source = Path(__file__).with_name('stretch_round2_compare.py')
text = source.read_text()
marker = 'first, second = map(load, sys.argv[1:])'
assert text.count(marker) == 1
prefix, _ = text.split(marker)
helpers = {}
exec(compile(prefix, str(source), 'exec'), helpers)
import numpy as np

first, second = map(helpers['load'], sys.argv[1:3])
allowed = {tuple(item.split(':')) for item in sys.argv[3:]}
assert first.keys() == second.keys()
for clip, channels in first.items():
    assert channels.keys() == second[clip].keys()
    for key, (times, values, interpolation) in channels.items():
        other_times, other_values, other_interpolation = second[clip][key]
        if (clip, *key) not in allowed:
            assert interpolation == other_interpolation, (clip, key, 'interpolation')
            assert times.shape == other_times.shape and np.allclose(times, other_times, atol=1e-6), (clip, key, 'times')
            assert values.shape == other_values.shape, (clip, key, 'shape')
            if key[1] == 'rotation' and interpolation == 'LINEAR':
                difference = np.minimum(np.linalg.norm(values - other_values, axis=1), np.linalg.norm(values + other_values, axis=1))
                assert np.all(difference < 2e-5), (clip, key, 'rotation')
            else:
                assert np.allclose(values, other_values, atol=2e-6), (clip, key, 'values')
print('UNCHANGED CHANNELS PASS; authored changes:', sorted(allowed))
