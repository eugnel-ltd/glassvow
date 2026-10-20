// The card glass fragment shader, ported from the game's card .gdshader files (WebGL1).
// Tiers: 1 silver rim, 2 spectral frame, 3 cut glass, 4 oil, 5 back panes, 6 the unnamed glass.
export const FRAG = `
precision highp float;
varying vec2 vUv;
uniform sampler2D uTex;
uniform vec2 tilt;
uniform int tier;
uniform float warm;
uniform int bandMode;
uniform float bandAngle;
uniform vec2 centre;
uniform vec3 palette;
uniform float paletteMix;
uniform float strength;
uniform float pscale;
const vec2 STAGE = vec2(200.0, 264.0);
const vec2 PAD = vec2(24.0, 24.0);
const vec2 CARD = vec2(152.0, 216.0);
const float RADIUS = 11.0;
const vec4 ART = vec4(2.0, 2.0, 148.0, 91.0);
float sq(float v){ return v*v; }
float rrect(vec2 cp, vec2 lo, vec2 hi, float r){ vec2 c=(lo+hi)*0.5; vec2 h=(hi-lo)*0.5; vec2 q=abs(cp-c)-h+vec2(r); float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-r; return 1.0-smoothstep(-0.6,0.6,d); }
float hface(vec2 cp){ return rrect(cp, vec2(0.0), CARD, RADIUS); }
float hart(vec2 cp){ return rrect(cp, ART.xy, ART.xy+ART.zw, 1.0); }
float inset(vec2 cp){ vec2 h=CARD*0.5; vec2 q=abs(cp-h)-h+vec2(RADIUS); float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-RADIUS; return -d; }
vec3 rainbow(float x){ return 0.5+0.5*cos(6.2831853*(x+vec3(0.0,0.333,0.667))); }
float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
vec2 hash2(vec2 p){ float a=hash(p); return vec2(a, hash(p+a+17.0)); }
float noise(vec2 p){ vec2 i=floor(p); vec2 f=fract(p); vec2 u=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),u.x), mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),u.x), u.y); }
float luma(vec3 c){ return dot(c, vec3(0.299,0.587,0.114)); }
vec3 screen(vec3 b, vec3 a){ return 1.0-(1.0-b)*(1.0-clamp(a,0.0,1.0)); }
float gem(vec2 cp){ vec2 p=abs((cp-vec2(10.0,10.0)).yx); vec3 k=vec3(-0.866025404,0.5,0.577350269); p-=2.0*min(dot(k.xy,p),0.0)*k.xy; p-=vec2(clamp(p.x,-k.z*15.48,k.z*15.48),15.48); float d=length(p)*sign(p.y)-2.0; return 1.0-smoothstep(-0.5,0.5,d); }
float gemAlong(vec2 cp, vec2 dir){ return dot(cp-vec2(10.0,10.0), normalize(dir))/18.0; }
vec3 gemKeep(vec3 col, vec3 base, vec2 cp, vec3 glint){ float facet=smoothstep(0.35,0.60,luma(base)); return mix(col, screen(base, glint*facet), gem(cp)); }
float backBand(vec2 cp){ vec2 c=cp-centre; if(bandMode==1) return length(c)/152.0; if(bandMode==2) return atan(c.y,c.x)/6.2831853; float a=radians(bandAngle); return dot(c, vec2(cos(a),sin(a)))/152.0; }
float backSlide(){ if(bandMode==1) return dot(tilt, vec2(0.30,0.22)); if(bandMode==2) return atan(tilt.y, tilt.x+1e-4)/6.2831853*clamp(length(tilt)*1.4,0.0,1.0); float a=radians(bandAngle); return dot(tilt, vec2(cos(a),sin(a)))*0.42; }
vec3 backSpectrum(float x){ vec3 rb=rainbow(x); return mix(rb, palette*(0.55+0.45*luma(rb)*1.6), paletteMix); }
float wallShade(vec2 local){ vec2 px=local*ART.zw; vec2 far=(1.0-local)*ART.zw; float w=0.0;
  w+=1.0-smoothstep(0.0,6.0*(0.4+0.9*max(0.0,tilt.x)),px.x); w+=1.0-smoothstep(0.0,6.0*(0.4+0.9*max(0.0,-tilt.x)),far.x);
  w+=1.0-smoothstep(0.0,6.0*(0.4+0.9*max(0.0,tilt.y)),px.y); w+=1.0-smoothstep(0.0,6.0*(0.4+0.9*max(0.0,-tilt.y)),far.y); return clamp(w,0.0,1.0); }
float motes(vec2 cp, float px, float density, float slide){ vec2 mp=(cp+tilt*slide)/px; vec2 mi=floor(mp); vec2 mh=hash2(mi); float md=length(fract(mp)-mh); float on=step(1.0-density, hash(mi+4.4)); float tw=0.35+0.65*abs(sin(dot(tilt,vec2(5.0,4.0))+mh.x*6.28)); return (1.0-smoothstep(0.03,0.12,md))*on*tw; }
vec3 mythGrade(vec3 base, vec2 cp, float face){
  vec3 SAP=vec3(0.14,0.42,1.0); vec3 AMB=vec3(1.0,0.64,0.18);
  float ins=inset(cp); float band=(1.0-smoothstep(8.5-0.6,8.5+0.6,ins))*face;
  vec2 c=cp-CARD*0.5; vec2 h=CARD*0.5;
  float side=(h.x-abs(c.x))<(h.y-abs(c.y))?1.0:0.0;
  float s=side>0.5?(c.y+(c.x>0.0?400.0:0.0)):(c.x+(c.y>0.0?800.0:1200.0));
  float sw=s/15.0+0.22*sin(s*0.09); float pid=floor(sw); float pf=fract(sw);
  float camex=1.0-smoothstep(0.035,0.075,min(pf,1.0-pf));
  float camey=max(1.0-smoothstep(0.7,1.4,ins), smoothstep(8.5-1.6,8.5-0.6,ins));
  float came=max(camex,camey);
  vec2 od=normalize(c*vec2(1.0,0.75)+0.001);
  float j=hash(vec2(pid,3.0))-0.5;
  float turn=dot(tilt,od)*1.5+j*0.9+warm*2.0-0.1;
  float f=smoothstep(-0.45,0.45,turn);
  vec3 jewel=mix(SAP,AMB,f); jewel=mix(jewel, vec3(0.70,0.36,0.88), 4.0*f*(1.0-f)*0.45);
  float lit=exp(-sq(dot(tilt,od)-0.45-j*0.6)*5.0);
  float across=(ins-0.8)/(8.5-1.6);
  float body=0.62+0.38*sin(clamp(across,0.0,1.0)*3.14159);
  body*=0.78+0.34*noise(vec2(s*0.22, ins*0.7+pid*3.1)); body*=0.85+0.3*hash(vec2(pid,7.0));
  vec3 pane=jewel*body*(0.70+0.65*lit)+vec3(1.0,0.97,0.9)*pow(lit,6.0)*0.45;
  vec3 lead=vec3(0.16,0.17,0.20);
  vec3 oil=rainbow(s*0.012+dot(tilt,vec2(0.7,0.5)));
  float glt=exp(-sq((dot(normalize(c+0.001),normalize(tilt+0.001))-0.8)*3.0))*clamp(length(tilt)*1.5,0.2,1.0);
  lead+=mix(vec3(0.55),oil,0.55)*glt*0.45;
  vec3 frame=mix(pane,lead,came);
  vec3 col=mix(base,frame,band);
  vec2 sp=(cp-vec2(76.0,93.5))/9.0; float r=length(sp); float sa=atan(sp.y,sp.x);
  float seal=1.0-smoothstep(0.64+0.26*cos(6.0*sa),0.74+0.26*cos(6.0*sa),r);
  float hub=1.0-smoothstep(0.24,0.32,r);
  vec3 gold=vec3(1.0,0.82,0.44)*(0.75+0.35*lit);
  vec3 sealc=mix(gold, mix(SAP,AMB,f)*1.2, hub);
  return mix(col, sealc, seal*face);
}
void main(){
  vec4 base=texture2D(uTex, vUv);
  vec2 cp=vUv*STAGE-PAD;
  float face=hface(cp);
  vec3 col=base.rgb;
  float gs=dot(tilt, vec2(0.55,0.4));
  float ga=gemAlong(cp, vec2(1.0,1.0));
  vec3 glint=vec3(0.0);
  if(tier==1){
    float rim=(1.0-smoothstep(3.2-0.7,3.2+0.7,inset(cp)))*face;
    vec2 c=cp-CARD*0.5;
    float ang=atan(c.y*0.70,c.x)/6.2831853; float aim=atan(-tilt.y,tilt.x+1e-4)/6.2831853;
    float reach=clamp(length(tilt),0.0,1.0); float dist=abs(fract(ang-aim+0.5)-0.5);
    float g=exp(-sq(dist/0.10))*(0.35+0.65*reach);
    vec3 rb=rainbow(ang*2.0+dot(tilt,vec2(0.6,0.4))); vec3 silver=vec3(0.80,0.83,0.90);
    vec3 foil=silver*(0.45+0.55*g)+rb*0.18*g;
    col=mix(base.rgb, screen(base.rgb*0.4, foil), rim);
    glint=silver*0.32*exp(-sq((ga-gs)/0.30));
  } else if(tier==2){
    float band=1.0-smoothstep(5.5-0.7,5.5+0.7,inset(cp));
    float rule=(1.0-smoothstep(1.6-0.5,1.6+0.5,abs(cp.y-93.0)))*step(5.5,cp.x)*step(cp.x,CARD.x-5.5);
    float m=max(band,rule)*face; vec2 q=cp/CARD;
    float along=dot(q-0.5, normalize(vec2(-0.55,1.0))); float slide=tilt.y*0.40-tilt.x*0.25;
    vec3 rb=rainbow(along*2.6+slide*1.3); float env=exp(-sq((along-slide)*2.4));
    vec3 foil=mix(vec3(0.78,0.81,0.88), rb, 0.75)*(0.45+0.55*env);
    col=mix(base.rgb, screen(base.rgb*0.45, foil*0.48), m);
    glint=rainbow(ga*1.4+gs*1.3)*0.34*exp(-sq((ga-gs)/0.32));
  } else if(tier==3){
    float m=face*hart(cp);
    if(m>0.0){
      vec2 lt=tilt+vec2(0.45,-0.35); vec2 g=cp/12.0; vec2 gi=floor(g); vec2 gf=fract(g);
      float d1=8.0; float d2=8.0; vec2 p1=vec2(0.0); vec2 p2=vec2(0.0); vec2 c1=vec2(0.0);
      for(int y=-1;y<=1;y++){ for(int x=-1;x<=1;x++){ vec2 o=vec2(float(x),float(y)); vec2 pt=o+hash2(gi+o); float dd=length(pt-gf);
        if(dd<d1){ d2=d1; p2=p1; d1=dd; p1=pt; c1=gi+o; } else if(dd<d2){ d2=dd; p2=pt; } } }
      vec2 lean=(hash2(c1+9.1)-0.5)*2.0;
      vec2 shift=(lean*0.6+tilt*0.4)*1.6*m/STAGE;
      vec3 art=texture2D(uTex, vUv+shift).rgb;
      vec3 jewel=mix(vec3(0.35,0.65,1.0), vec3(1.0,0.55,0.30), smoothstep(-0.4,0.4, dot(lt, normalize(lean+0.001))+hash(c1)-0.5));
      vec2 rel=lt-lean*0.8; float sl=exp(-dot(rel,rel)*4.5);
      vec3 glass=mix(art, art*jewel*1.9, 0.10+0.80*sl);
      float gap=d2-d1; vec2 fn=normalize(p2-p1+1e-4);
      float reach=clamp(length(lt)*1.4,0.0,1.0); float facing=dot(-fn, normalize(lt+vec2(0.0001)))*reach;
      float bevel=1.0-smoothstep(0.0,0.09,gap); float seam=1.0-smoothstep(0.0,0.09*0.45,gap);
      float hi=bevel*smoothstep(0.25,0.85,facing); float lo=bevel*smoothstep(0.25,0.85,-facing);
      float fz=(1.0-smoothstep(0.09,0.20,gap))*step(0.09*0.6,gap);
      vec3 spec=rainbow(gap*5.0+dot(fn,vec2(0.3,0.2))+dot(lt,vec2(0.6,0.4)));
      vec3 cc=glass*(1.0-0.22*seam); cc*=1.0-0.35*lo;
      cc=screen(cc, spec*fz*smoothstep(0.45,0.95,facing)*0.85);
      cc=screen(cc, vec3(1.0,0.97,0.92)*hi*1.15);
      col=mix(base.rgb, cc, m);
    }
    glint=mix(vec3(0.35,0.65,1.0), vec3(1.0,0.55,0.30), smoothstep(-0.6,0.6,gs))*0.40*exp(-sq((ga-gs)/0.30));
  } else if(tier==4){
    vec2 p=cp/34.0+tilt*vec2(0.35,0.30);
    float n=noise(p)*0.6+noise(p*2.1+3.3)*0.3+noise(p*4.3-1.7)*0.1;
    float film=n*1.6+dot(tilt,vec2(0.55,0.40))*1.1;
    vec3 iri=rainbow(film)*vec3(0.55,0.75,0.85);
    float lum=luma(base.rgb); float dark=1.0-smoothstep(0.10,0.55,lum); float pool=smoothstep(0.48,0.72,n);
    vec3 cc=base.rgb*(1.0-0.22*(1.0-dark)); float plate=smoothstep(96.0,104.0,cp.y)*0.6;
    cc+=iri*0.34*dark*(0.08+0.92*pool)*(1.0-plate);
    col=mix(base.rgb, cc, face);
    glint=iri*0.16*exp(-sq((ga-gs)/0.34));
  } else if(tier==5){
    float lum=luma(base.rgb); float glass=smoothstep(0.10,0.45,lum);
    vec2 p=cp/(18.0*pscale); vec2 nn=vec2(noise(p),noise(p+7.3))*2.0-1.0; nn*=0.85;
    vec2 rel=tilt-nn; float lit=exp(-dot(rel,rel)*5.0);
    float b=backBand(cp);
    vec3 rb=backSpectrum(b*1.6+noise(p*0.5+2.0)*0.6+dot(tilt,vec2(0.5,0.35)));
    vec3 add=rb*(0.12+0.88*lit)*glass*strength;
    vec3 cc=screen(base.rgb, add);
    float lead=1.0-smoothstep(0.04,0.12,lum); float run=exp(-sq((b-backSlide())*3.0));
    cc+=vec3(0.45,0.48,0.55)*lead*run*0.35*strength;
    col=mix(base.rgb, cc, face);
  } else if(tier==6){
    float m=face*hart(cp);
    vec2 local=(cp-ART.xy)/ART.zw;
    col=mix(col, col*(1.0-0.55*wallShade(local)), m);
    col=screen(col, vec3(1.0,0.92,0.75)*motes(cp,9.0,0.16,6.0)*m*0.55);
    col=mythGrade(col, cp, face);
    col=mix(col, base.rgb, gem(cp));
    gl_FragColor=vec4(col, base.a);
    return;
  }
  if(tier>=1 && tier<=4) col=gemKeep(col, base.rgb, cp, glint);
  gl_FragColor=vec4(col, base.a);
}`;
