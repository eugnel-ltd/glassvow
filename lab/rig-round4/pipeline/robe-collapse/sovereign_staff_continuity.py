# Rigid staff floor clearance about the existing hand grip. No mesh scaling or grip translation.
import math
import numpy as np


def unit(v):
    return v / max(float(np.linalg.norm(v)), 1e-12)


def rotation(axis, angle):
    axis = unit(axis)
    x, y, z = axis
    K = np.array([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
    return np.eye(3) + math.sin(angle) * K + (1 - math.cos(angle)) * K @ K


def horizontal_direction(axis, previous=None, fallback=(0., -1., 0.)):
    raw = np.asarray(axis) * [1, 1, 0]
    # Test the magnitude before normalisation. Near vertical, its azimuth has no stable meaning.
    if np.linalg.norm(raw) < .12:
        return unit(np.asarray(previous if previous is not None else fallback) * [1, 1, 0])
    h = unit(raw)
    if previous is not None and h @ previous < 0:
        h = -h
    return h


def solve(grip, base_rotation, rest_rotation, vertices, axis0, floor, previous=None, direction=None):
    """Return the nearest valid rigid orientation to the previous one, about an unchanged grip."""
    origin, base = grip[:3, 3], base_rotation
    start = base if previous is None else previous
    local = vertices  # armature-space offsets from the rest grip
    # Rotation maps rest armature-space offsets into this pose.
    def minimum(R):
        return float((local @ (R @ rest_rotation.T).T + origin)[:, 2].min())
    axis = start @ rest_rotation.T @ axis0
    h = horizontal_direction(axis, direction)
    if minimum(start) >= floor:
        return start.copy(), h, minimum(start)
    # Preserve the valid azimuth; flatten only as much as the actual surface requires.
    turn_axis = np.cross(axis, h)
    angle = math.acos(float(np.clip(unit(axis) @ h, -1, 1)))
    if np.linalg.norm(turn_axis) < 1e-8:
        raise ValueError('The staff thickness cannot clear the floor at the fixed hand grip')
    flat = rotation(turn_axis, angle) @ start
    if minimum(flat) < floor:
        raise ValueError(f'Staff/grip conflict: flat surface z={minimum(flat):.6f}, required={floor:.6f}, grip={origin.tolist()}')
    lo, hi = 0., angle
    for _ in range(20):
        mid = (lo + hi) / 2
        if minimum(rotation(turn_axis, mid) @ start) >= floor:
            hi = mid
        else:
            lo = mid
    R = rotation(turn_axis, hi) @ start
    return R, h, minimum(R)


def self_check():
    # Demonstrated f28/28.5/29 directions and close perturbations must retain one horizontal branch.
    directions = ([.00630, .00671, .99996], [.00036, -.01267, .99992], [-.00558, -.03204, .99947])
    previous = unit(np.array([.6848, .7287, 0.]))
    for axis in [*directions, [1e-10, -1e-10, 1], [-1e-10, 1e-10, 1]]:
        h = horizontal_direction(np.array(axis), previous)
        assert h @ previous > .999999
        previous = h
    shaft = np.array([[0., 0., -1.], [0., 0., .8], [.025, 0., -.8], [-.025, 0., -.8]])
    old = None
    for z in (.5, .32, .20):
        grip = np.eye(4); grip[2, 3] = z
        R, previous, low = solve(grip, np.eye(3), np.eye(3), shaft, np.array([0., 0., 1.]), .04, old, previous)
        assert low >= .04 - 1e-6 and abs(np.linalg.det(R) - 1) < 1e-9
        old = R
    print('STAFF CONTINUITY REGRESSION PASS')


if __name__ == '__main__':
    self_check()
