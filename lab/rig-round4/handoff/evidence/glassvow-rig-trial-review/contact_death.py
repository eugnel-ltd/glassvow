"""A bounded visual trial: 8 cm recessed forearm, early knuckle catch, yielding elbows.
Shoulder pitch keeps the fist shell on the floor while the elbow gives. Contact can roll/slide;
this first visual does not claim a no-slip grip.
"""
import numpy as np

def build(mo,body):
    keys=[(1,{}),(4,dict(P=-3,t=-5,k=9,cx=2)),
          (9,dict(P=4,t=-25,k=45,cx=-4)),
          (13,dict(P=13,t=-32,k=58,cx=-6)),
          (17,dict(P=24,t=-35,k=60,cx=-3)),
          (20,dict(P=31,t=-34,k=60,cx=1)),
          (23,dict(P=37,t=-33,k=58,cx=4)),
          (25,dict(P=42,t=-30,k=56,cx=4)),
          (29,dict(P=65,t=-24,k=42,cx=3,toe=68)),
          (33,dict(P=89,t=-10,k=24,cx=0,toe=100)),
          (35,dict(P=92,t=-5,k=20,cx=-2,toe=107)),
          (38,dict(P=90.5,t=-5,k=20,cx=-2,toe=105.5,fin=-3)),
          (41,dict(P=92.2,t=-5,k=20,cx=-2,toe=107.2,fin=1)),
          (43,dict(P=92,t=-5,k=20,cx=-2,toe=107,fin=0)),
          (49,dict(P=92,t=-5,k=20,cx=-2,toe=107,fin=0))]
    heads={n:np.asarray(h) for n,h,_,_ in body.bones}
    ang=lambda v:np.degrees(np.arctan2(v[1],v[0]))
    straight={}
    for s in mo.SIDES:
        q=body.p[(body.bone==s+'LowerArm')&~body.ball];point=q[np.argmin(q[:,2])]
        u=heads[s+'LowerArm'][1:]-heads[s+'UpperArm'][1:]
        straight[s]=(-90-ang(u),(ang(point[1:]-heads[s+'LowerArm'][1:])-ang(u)+180)%360-180)
    new=[]
    for f,sp in keys:
        sp=dict(sp);w=min(1.,max(0.,(f-4)/9));w=w*w*(3-2*w)
        total=sp.get('P',0)+sp.get('cx',0)
        sp['arm']=tuple(((-total+straight[s][0])*w,-straight[s][1]*w) for s in mo.SIDES)
        sp['plant']=mo.SIDES if f<20 else ()
        new.append((f,sp))
    clip=mo.Clip(body,new);cache={};events={};previous={}
    arms=np.isin(body.bone,[s+n for s in mo.SIDES for n in ('UpperArm','LowerArm')])
    for f in range(1,50):
        pose=mo.stance(clip.angles(f));xy=clip._xy[f];pose['loc']=(xy[0],xy[1],0)
        height=mo.GROUND-float(body.posed(pose)[~arms,2].min());pose['loc']=(xy[0],xy[1],height)
        for s in mo.SIDES:
            on=(body.bone==s+'LowerArm')&~body.ball
            if s not in events and f>=13 and body.posed(pose)[on,2].min()<=mo.GROUND:events[s]=f
            if s in events:
                # Each arm releases at a different time. After release, the elbow opens under
                # its own weight and the knuckles slide/roll beside the dropping shell.
                age=f-events[s];el=-straight[s][1]-min(30.,age*4.)
                release=26 if s=='Left' else 29
                if f>=release:
                    w=min(1.,(f-release)/8);w=w*w*(3-2*w)
                    el=el+(-15.-el)*w
                pose[s+'LowerArm']=[(mo.X,el)]
                centre=previous.get(s,pose[s+'UpperArm'][0][1])
                def gap(sh):
                    pose[s+'UpperArm']=[(mo.X,sh)]
                    return float(body.posed(pose)[on,2].min()-mo.GROUND)
                grid=np.linspace(centre-65,centre+65,53);values=[gap(sh) for sh in grid]
                roots=[mo.bisect(gap,float(a),float(b),it=25) for a,b,fa,fb in zip(grid[:-1],grid[1:],values[:-1],values[1:]) if fa*fb<=0]
                sh=min(roots,key=lambda x:abs(x-centre)) if roots else centre
                pose[s+'UpperArm']=[(mo.X,sh)]
                previous[s]=sh
        cache[f]=body.grounded(pose)
    clip.pose=lambda f:cache[f];clip.contact_events=events
    return clip
