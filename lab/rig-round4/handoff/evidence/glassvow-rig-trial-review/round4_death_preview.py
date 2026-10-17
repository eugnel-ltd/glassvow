"""Second visual trial: loss of support, a brief catch, then a spent prone shell.
The long front door stays intact. The arms cease to hold the body after the catch.
"""
def build(mo, body):
    keys=[(1,{}),
          (4,dict(P=-3,t=-5,k=9,cx=2,arm=(-4,-8))),
          (9,dict(P=5,t=-32,k=60,cx=-5,arm=(-10,-14))),
          (12,dict(P=13,t=-37,k=68,cx=-8,arm=(-20,-18))),
          (16,dict(P=29,t=-35,k=62,cx=-4,arm=(-24,-20))),
          (20,dict(P=43,t=-33,k=58,cx=6,arm=(-35,-35))),
          (23,dict(P=48,t=-33,k=56,cx=5,arm=(-28,-45))),
          (27,dict(P=65,t=-25,k=45,cx=4,toe=65,arm=(-4,-32))),
          (31,dict(P=85,t=-10,k=25,cx=0,toe=95,arm=(2,-22))),
          (34,dict(P=92,t=-5,k=20,cx=-2,toe=107,arm=(5,-15))),
          (37,dict(P=90.5,t=-5,k=20,cx=-2,toe=105.5,fin=-3,arm=(4,-17))),
          (40,dict(P=92.3,t=-5,k=20,cx=-2,toe=107.3,fin=1.5,arm=(5,-15))),
          (43,dict(P=92,t=-5,k=20,cx=-2,toe=107,fin=-.5,arm=(5,-15))),
          (46,dict(P=92,t=-5,k=20,cx=-2,toe=107,fin=0,arm=(5,-15))),
          (52,dict(P=92,t=-5,k=20,cx=-2,toe=107,fin=0,arm=(5,-15)))]
    return mo.Clip(body,[(f,dict(sp,plant=mo.SIDES if f<16 else ())) for f,sp in keys])
