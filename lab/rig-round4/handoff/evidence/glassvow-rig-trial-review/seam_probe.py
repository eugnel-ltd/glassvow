"""Inspect the existing waist moulding and finial base without Blender."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from round4_hidden import fitted_with_uv
import round4_segments as seg
p, f, uv, tex = fitted_with_uv(HERE / 'src/gravewarden.glb', 2.4)
m = seg.measure(p, f)
lab = np.load(HERE / 'gravewarden-fit-labels.npy')
rng = np.random.default_rng(5)
a, b = rng.random((2, len(f), 45, 1)); flip = a+b>1
a[flip], b[flip] = 1-a[flip], 1-b[flip]
tri = p[f]
q = (tri[:, None, 0] + a*(tri[:, None, 1]-tri[:, None, 0]) + b*(tri[:, None, 2]-tri[:, None, 0])).reshape(-1, 3)
tuv = (uv[:, None, 0] + a*(uv[:, None, 1]-uv[:, None, 0]) + b*(uv[:, None, 2]-uv[:, None, 0])).reshape(-1, 2)
c = tex[np.clip((tuv[:, 1]*tex.shape[0]).astype(int),0,tex.shape[0]-1), np.clip((tuv[:, 0]*tex.shape[1]).astype(int),0,tex.shape[1]-1)]
# Colour only the existing rear pelvic block; leave the long front door intact.
mask = (q[:, 2] < .80) & (q[:, 1] > -.03) & (np.abs(q[:, 0]) < .52) & (q[:,2]>.55)
normal = np.cross(tri[:,1]-tri[:,0], tri[:,2]-tri[:,0]); normal /= np.maximum(np.linalg.norm(normal, axis=1)[:,None],1e-9)
normal = np.repeat(normal,45,0)
colours = [c, np.where(mask[:,None], .25*c + [.60, .15, .06], c)]
rows=[]
for colour in colours:
    panels=[]
    for yaw in (0, 90, 180, -90):
        rad=np.radians(yaw); u=q[:,0]*np.cos(rad)+q[:,1]*np.sin(rad); depth=q[:,1]*np.cos(rad)-q[:,0]*np.sin(rad)
        shade=np.clip(.65+.35*(normal @ np.array([-.3,-.6,.7])),.2,1)
        img=np.full((640,600,3),.55)
        order=np.argsort(-depth)
        x=(300+u[order]*500).astype(int); y=(580-(q[order,2]-.3)*500).astype(int)
        ok=(x>=0)&(x<599)&(y>=0)&(y<639)
        for dx in (0,1):
            for dy in (0,1): img[y[ok]+dy,x[ok]+dx] = (colour*shade[:,None])[order][ok]
        panels.append(img)
    rows.append(np.concatenate(panels,1))
Image.fromarray((np.clip(np.concatenate(rows,0),0,1)*255).astype('uint8')).save(HERE/'waist-probe.png')
for z in (.55,.6,.65,.7,.75,.8,.85,.9,1):
    row = q[(abs(q[:,2]-z)<.005)&(abs(q[:,0])<.15)]
    print(z, np.round(np.percentile(row[:,1],[0,10,30,50,70,90,100]),3))
