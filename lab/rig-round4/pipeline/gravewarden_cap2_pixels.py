# Screen-space attribution of the old cap changes, using Godot-baked vertices.
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
p=Path(__file__).resolve().parent
ns={"__file__":str(p/"gravewarden_round3_validate.py")}
exec((p/"gravewarden_round3_validate.py").read_text().rsplit("\nmain()",1)[0],ns)
g=ns["load"](ns["CAP"]); m=ns["mesh"](g); mb=ns["mesh"](ns["load"](ns["BASE"]))
base_keys=ns["keys"](mb); keys=ns["keys"](m)
base_faces={ns["canon"](tuple(base_keys[i] for i in f))[0] for f in mb["F"]}
extra=np.array([ns["canon"](tuple(keys[i] for i in f))[0] not in base_faces for f in m["F"]])
names=[g[0]["nodes"][j]["name"] for j in g[0]["skins"][0]["joints"]]
records=json.loads(Path("/tmp/gravewarden-cap2-probe-old/gravewarden/probe.json").read_text())
def raster(P,F):
    depth=np.full((640,640),np.inf); face=np.full((640,640),-1)
    for i,f in enumerate(F):
        v=P[f]; xy=v[:,:2]
        lo=np.maximum(np.floor(xy.min(0)).astype(int),0); hi=np.minimum(np.ceil(xy.max(0)).astype(int),639)
        if np.any(lo>hi): continue
        x,y=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
        a,b,c=xy; den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(den)<1e-10: continue
        u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
        w=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den; t=1-u-w
        z=u*v[0,2]+w*v[1,2]+t*v[2,2]
        sl=np.s_[lo[1]:hi[1]+1,lo[0]:hi[0]+1]; take=(u>=0)&(w>=0)&(t>=0)&(z<depth[sl])
        depth[sl][take]=z[take]; face[sl][take]=i
    return face,depth
for record,frame in zip(records,[0,109,210]):
    P=np.array(record["vertices"]); face,dep=raster(P,m["F"])
    a=np.array(Image.open(p/"godot-preview-round3-gravewarden-baseline"/"gravewarden"/f"frame-{frame:04d}.png").convert("RGB"))
    b=np.array(Image.open(p/"godot-preview-round3-gravewarden-capped"/"gravewarden"/f"frame-{frame:04d}.png").convert("RGB"))
    change=np.abs(b.astype(int)-a.astype(int)).sum(2)>60
    print(record["clip"],"changed pixels",int(change.sum()))
    for label,box in [("door",(285,305,370,440)),("shoulder",(390,300,440,340)),("all",(0,45,640,640))]:
        mask=np.zeros((640,640),bool); x0,y0,x1,y1=box; mask[y0:y1,x0:x1]=True
        hits=face[change&mask&(face>=0)]
        print(label,[(names[int(j)],int(n)) for j,n in zip(*np.unique(m["J"][m["F"][hits,0]],return_counts=True))],"caps",int(extra[hits].sum()))
        if label=="door" and frame==109:
            for f,n in zip(*np.unique(hits[extra[hits]],return_counts=True)):
                v=m["P"][m["F"][f]]
                print("door cap",int(f),int(n),names[int(m["J"][m["F"][f,0]])],"centroid",np.round(v.mean(0),4).tolist())
    canvas=Image.new("RGB",(960,480),"#30333a")
    for k,im in enumerate([a,b,np.where(change[...,None],b//2+np.array([100,0,0]),b//3).clip(0,255).astype(np.uint8)]):
        crop=Image.fromarray(im).crop((250,190,450,490)).resize((320,480))
        canvas.paste(crop,(320*k,0))
    canvas.save(f"/tmp/gravewarden-cap2-diagnosis-{frame:04d}.png")
