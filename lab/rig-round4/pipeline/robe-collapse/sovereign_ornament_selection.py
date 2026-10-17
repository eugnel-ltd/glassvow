# Label a connectivity-defined sovereign ornament without changing the rig or weights.
# python sovereign_ornament_selection.py rest.npz solve.npz new-output-directory
import sys,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
rest,solve,out=map(Path,sys.argv[1:4]);assert not out.exists();out.mkdir()
a=np.load(rest);d=np.load(solve);v0=a['verts'];T=a['tris'];adj=[set() for _ in v0]
for i,j,k in T:adj[i].update((j,k));adj[j].update((i,k));adj[k].update((i,j))
seen=set();parts=[]
for i in range(len(v0)):
    if i in seen:continue
    todo=[i];seen.add(i);part=[]
    while todo:
        j=todo.pop();part.append(j)
        for k in adj[j]:
            if k not in seen:seen.add(k);todo.append(k)
    parts.append(np.array(part))
# The only large disconnected component above the back of the shoulders.
choices=[p for p in parts if len(p)>100 and v0[p,1].min()>.15 and v0[p,2].min()>1]
assert len(choices)==1,[len(p) for p in choices]
ids=choices[0];selected=np.zeros(len(v0),bool);selected[ids]=True
face=selected[T].all(1);assert not (selected[T].any(1)&~face).any(), 'Selection cuts a connected component'
w=a['weights'];names=list(a['names']);p=d['verts'][33]
x=v0[ids];y=p[ids];u,_,vt=np.linalg.svd((x-x.mean(0)).T@(y-y.mean(0)));R=u@vt
if np.linalg.det(R)<0:u[:,-1]*=-1;R=u@vt
error=np.linalg.norm((x-x.mean(0))@R+y.mean(0)-y,axis=1)
report={'selection':'One disconnected mesh component, selected by connectivity; no geometric cut through fused faces.',
        'vertex_indices':ids.tolist(),'face_indices':np.nonzero(face)[0].tolist(),'vertices':len(ids),'triangles':int(face.sum()),
        'rest_bounds':[x.min(0).tolist(),x.max(0).tolist()],
        'weight_totals':{str(n):float(w[ids,j].sum()) for j,n in enumerate(names) if w[ids,j].sum()>1e-6},
        'vertices_with_non_head_weight_over_0_01':int(((1-w[ids,names.index('Head')])>.01).sum()),
        'f34_best_rigid_fit_residual_m':{'max':float(error.max()),'p95':float(np.percentile(error,95))}}
(out/'ornament-selection.json').write_text(json.dumps(report,indent=2)+'\n')
size=480;sheet=Image.new('RGB',(size*3,size*2),(42,46,54));font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',17)
for row,(label,v) in enumerate((('Rest',v0),('Failed pose f34',p))):
    centre=(v.min(0)+v.max(0))/2;scale=size/(np.linalg.norm(v.max(0)-v.min(0))*1.05)
    for col,(view,direction) in enumerate((('Rear',(0,1,.15)),('Side',(1,0,.15)),('Oblique',(-1,2,.6)))):
        direction=np.array(direction);direction=direction/np.linalg.norm(direction);right=-np.cross(direction,[0,0,1]);right/=np.linalg.norm(right);up=np.cross(right,-direction)
        if up[2]<0:up=-up
        im=Image.new('RGB',(size,size),(52,56,66));draw=ImageDraw.Draw(im);tri=v[T];normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);normal/=np.maximum(np.linalg.norm(normal,axis=1,keepdims=True),1e-9)
        for i in np.argsort((tri.mean(1)-centre)@direction):
            colour=np.array([230,170,45] if face[i] else [105,115,130]);colour=colour*(.35+.65*abs(normal[i]@np.array([.3,.4,.86])))
            draw.polygon([((q-centre)@right*scale+size/2,size/2-(q-centre)@up*scale) for q in tri[i]],fill=tuple(colour.astype(int)))
        draw.rectangle((0,0,size,52),fill=(24,27,33));draw.text((8,7),f'{label} - {view}',font=font,fill='white');draw.text((8,29),'Gold: disconnected 922-vertex ornament',font=font,fill=(245,195,65));sheet.paste(im,(col*size,row*size))
sheet.save(out/'ornament-selection.png');print(json.dumps({k:v for k,v in report.items() if k not in ('vertex_indices','face_indices')},indent=2))
