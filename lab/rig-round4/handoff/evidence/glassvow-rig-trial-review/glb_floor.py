"""Sample final glTF skin matrices directly. No renderer or Blender is started."""
import json
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).parent))
from read_glb import load

def matrix(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1]);r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    out=np.eye(4);out[:3,:3]=r*np.array(node.get('scale',[1,1,1]));out[:3,3]=node.get('translation',[0,0,0]);return out

def sample(path):
    doc,acc=load(path);nodes=[dict(n) for n in doc['nodes']]
    death=next(a for a in doc['animations'] if a['name']=='death')
    for channel in death['channels']:
        sampler=death['samplers'][channel['sampler']];value=acc(sampler['output'])[-1]
        nodes[channel['target']['node']][channel['target']['path']]=value.tolist()
    parent={c:i for i,n in enumerate(nodes) for c in n.get('children',[])};world={}
    def visit(i):
        if i not in world:world[i]=(visit(parent[i]) if i in parent else np.eye(4))@matrix(nodes[i])
        return world[i]
    floor={'all':float('inf'),'front_ornament_region':float('inf')};counts={}
    for ni,node in enumerate(nodes):
        if 'mesh' not in node:continue
        skin=doc['skins'][node['skin']];ib=acc(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        joint=[visit(i)@bind for i,bind in zip(skin['joints'],ib)]
        names=np.array([nodes[i]['name'] for i in skin['joints']])
        for prim in doc['meshes'][node['mesh']]['primitives']:
            a=prim['attributes'];p=acc(a['POSITION']);w=acc(a['WEIGHTS_0']);j=acc(a['JOINTS_0']).astype(int);out=np.zeros_like(p,dtype=float);hp=np.c_[p,np.ones(len(p))]
            for slot in range(w.shape[1]):out+=np.einsum('nij,nj->ni',np.array(joint)[j[:,slot]],hp)[:,:3]*w[:,slot,None]
            labels=names[j[np.arange(len(p)),w.argmax(1)]]
            floor['all']=min(floor['all'],float(out[:,1].min()))
            for name in np.unique(labels):
                on=labels==name;floor[name]=min(floor.get(name,float('inf')),float(out[on,1].min()));counts[name]=counts.get(name,0)+int(on.sum())
            on=(labels=='Chest')&(p[:,2]>.35)&(p[:,1]>1.15)
            if on.any():floor['front_ornament_region']=min(floor['front_ornament_region'],float(out[on,1].min()))
    print(json.dumps({'path':str(path),'method':'Final glTF channel samples and full linear skinning, all primitive vertices','floor_min_m':floor,'vertices':counts},indent=2))
    return doc

if __name__=='__main__':sample(Path(sys.argv[1]))
