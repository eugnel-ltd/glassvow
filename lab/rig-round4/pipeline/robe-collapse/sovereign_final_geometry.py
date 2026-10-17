# One geometry-specific sovereign rebuild. Rest geometry stays unchanged; only measured pivots and ownership change.
import json
from pathlib import Path
import numpy as np


def apply(rig, c, selection):
    original = {n: m.copy() for n,m in rig.rest.items()}
    points = {n: rig.head(n).copy() for n in rig.names}
    for n,z,y in [('Hips',.60,-.13),('Spine',.75,-.16),('Chest',.90,-.18),('UpperChest',1.02,-.18),('Neck',1.14,-.21),('Head',1.32,-.32)]:
        points[n]=np.array([0.,y,z])
    points['RightHand']=np.array([-.61,-.18,.61])
    ends = {'Hips':'Spine','Spine':'Chest','Chest':'UpperChest','UpperChest':'Neck','Neck':'Head','RightLowerArm':'RightHand'}
    for n,target in ends.items():
        head,tail=points[n],points[target]
        M=rig.rest[n].copy();M[:3,:3]=c.between(M[:3,1],c.unit(tail-head))@M[:3,:3];M[:3,3]=head
        rig.rest[n]=M;rig.length[n]=float(np.linalg.norm(tail-head))
    for n,tail in [('Head',np.array([0.,-.32,1.76])),('RightHand',np.array([-.66,-.22,.49]))]:
        head=points[n];M=rig.rest[n].copy();M[:3,:3]=c.between(M[:3,1],c.unit(tail-head))@M[:3,:3];M[:3,3]=head;rig.rest[n]=M;rig.length[n]=float(np.linalg.norm(tail-head))
    v=rig.verts
    ring=np.array(json.loads(Path(selection).read_text())['vertex_indices'])
    trunk=['Hips','Spine','Chest','UpperChest','Neck','Head']
    total=sum(rig.W[n] for n in trunk)
    z=np.array([points[n][2] for n in trunk]);coord=np.interp(v[:,2],z,np.arange(len(trunk)))
    # The actual trunk share blends continuously between adjacent centre-line pivots.
    for j,n in enumerate(trunk):rig.W[n]=total*np.maximum(1-np.abs(coord-j),0)
    for n in rig.names:rig.W[n][ring]=0
    rig.W['Head'][ring]=1
    # Palm surface landmark: centre of the triangle closest to the observed front palm, not the old named pivot.
    centres=v[rig.tris].mean(1)
    eligible=(centres[:,0]<-.59)&(centres[:,0]>-.68)&(centres[:,1]<-.145)&(centres[:,1]>-.21)&(centres[:,2]>.51)&(centres[:,2]<.58)
    face_ids=np.nonzero(eligible)[0];assert len(face_ids)
    face=int(face_ids[np.linalg.norm(centres[face_ids]-[-.64,-.175,.55],axis=1).argmin()]);anchor=centres[face]
    # Keep the palm/finger patch rigid on Hand, feathered over the wrist. Never change unrelated upper-body weights.
    arm_names=[n for n in rig.names if n.startswith('Right') and any(k in n for k in ('Arm','Hand','Shoulder'))]
    dist=np.linalg.norm(v-anchor,axis=1);amount=np.array([1-c.smooth((r-.075)/.075) for r in dist])*(v[:,0]<-.52)
    share=sum(rig.W[n] for n in arm_names)
    for n in arm_names:rig.W[n]*=1-amount
    rig.W['RightHand']+=share*amount
    grip_ids=rig.tris[face]
    for n in rig.names:rig.W[n][grip_ids]=0
    rig.W['RightHand'][grip_ids]=1
    # Align one actual shaft-surface point with that palm material point. This is a rest alignment, never a floor correction.
    bone,pv,tris=rig.props[0]
    shaft_axis=np.linalg.svd(pv-pv.mean(0),full_matrices=False)[2][0]
    section=np.abs(pv[:,2]-.55)<.04
    choices=np.nonzero(section)[0];assert len(choices)
    point_id=int(choices[np.linalg.norm(pv[choices]-[-.62,-.085,.55],axis=1).argmin()]);material=pv[point_id].copy()
    shifted=pv+anchor-material
    rig.props[0]=(bone,shifted,tris)
    rig.rest[bone]=rig.rest[bone].copy();rig.rest[bone][:3,3]=anchor
    return {'moved_pivots':{n:{'before':original[n][:3,3].tolist(),'after':rig.head(n).tolist()} for n in rig.names if not np.allclose(original[n],rig.rest[n])},
            'ring_vertices':len(ring),'palm_face':face,'palm_vertices':grip_ids.tolist(),'palm_material_anchor':anchor.tolist(),
            'shaft_material_vertex':point_id,'shaft_material_before':material.tolist(),'rest_prop_translation':(anchor-material).tolist(),
            'hand_local_anchor':(np.linalg.inv(rig.rest['RightHand'])@np.r_[anchor,1]).tolist(),'shaft_axis':shaft_axis.tolist()}
