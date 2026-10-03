shader_type spatial;
// The river on phones and tablets (`MapScene.lean_profile`): river.gdshader's
// water without its two costliest parts, measured on the iPad 8 at the 40°
// journey camera. No screen or depth read (they force a colour and a depth
// copy of the frame): the bed seen through the shallows is a warm stone tint.
// The ripple normal is the waves' analytic slope, without the pier field,
// instead of four finite differences through it. Vertex waves, depth tint,
// foam, sky glints and pier wakes are the full shader's.
// The ravine's line: MapRavine.centre(river_cut, z), on the GPU's sine.
uniform float river_cut = 0.0;
uniform float channel = 1.0;
uniform float river_length_m = 70.0;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D bathymetry : filter_linear, repeat_disable;
uniform vec3 bed_tint = vec3(.15,.125,.105);
uniform float flow_time = 0.0;
uniform int pier_count = 0;
uniform vec4 piers[16];
varying vec3 world_at;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float river_line(float z) { return river_cut+sin(z*.19)*1.4+sin(z*.61)*.3; }
vec2 river_uv(vec2 p) { return vec2((p.x-river_line(p.y))/(8.0*channel)+.5,p.y/river_length_m+.5); }
vec2 current(vec2 p) {
 vec2 q=vec2(p.x-river_line(p.y),p.y);
 // Streamlines bend around the immersed support footprints.
 for(int i=0;i<pier_count;i++) {
  vec2 delta=p-piers[i].xy;
  float influence=exp(-dot(delta,delta)/3.5);
  q.x+=delta.x*influence*.42;
  q.y-=delta.y*influence*.26;
 }
 return q;
}
float flowing_noise(vec2 p,float distance) {
 float phase=fract(flow_time/8.0);
 float a=noise(p-vec2(0,phase*distance));
 float b=noise(p-vec2(0,fract(phase+.5)*distance));
 return mix(a,b,abs(phase*2.0-1.0));
}
float waves(vec2 p) {
 vec2 q=current(p);
 float t=flow_time*TAU/8.0;
 float bend=sin(q.y*.73+q.x*1.1)*.52+noise(q*1.3)*1.5;
 return sin(q.y*6.2+q.x*1.4+bend-t*2.0)*.011
       +sin(q.y*12.4-q.x*5.1-t*4.0)*.005
       +sin(q.x*10.8+q.y*3.3+t)*.005;
}
void vertex() {
 world_at=VERTEX;
 float depth=texture(bathymetry,UV).r;
 VERTEX.y+=waves(VERTEX.xz)*smoothstep(.0,.5,depth);
 world_at.y=VERTEX.y;
}
void fragment() {
 vec2 p=world_at.xz;
 vec2 q=current(p);
 float depth=texture(bathymetry,river_uv(p)).r;
 if(depth<=.003) { discard; }
 float ripples=smoothstep(.0,.5,depth);
 // d(waves)/d(x, z) on the unbent current: q = (x - line(z), z).
 vec2 u=vec2(p.x-river_line(p.y),p.y);
 float line_dz=cos(p.y*.19)*1.4*.19+cos(p.y*.61)*.3*.61;
 float t=flow_time*TAU/8.0;
 float bend=sin(u.y*.73+u.x*1.1)*.52;
 float bend_x=cos(u.y*.73+u.x*1.1)*.52*1.1;
 float bend_y=cos(u.y*.73+u.x*1.1)*.52*.73;
 float a=u.y*6.2+u.x*1.4+bend-t*2.0;
 float b=u.y*12.4-u.x*5.1-t*4.0;
 float c=u.x*10.8+u.y*3.3+t;
 float wx=cos(a)*.011*(1.4+bend_x)-cos(b)*.005*5.1+cos(c)*.005*10.8;
 float wy=cos(a)*.011*(6.2+bend_y)+cos(b)*.005*12.4+cos(c)*.005*3.3;
 float dx=wx*ripples;
 float dz=(wy-wx*line_dz)*ripples;
 vec3 n=normalize(vec3(-dx,1,-dz));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 float flow=flowing_noise(vec2(q.x*2.1,q.y*.42),1.04);
 float broad=flowing_noise(vec2(q.x*.67,q.y*.16),.32);
 // Depth tint, with warm stone visible only through the shallow margins.
 vec3 deep=vec3(.029,.067,.078);
 vec3 shallow=vec3(.083,.127,.128);
 vec3 water=mix(shallow,deep,smoothstep(.12,1.8,depth));
 water*=.85+.23*broad+.08*flow;
 float transmission=exp(-depth*1.7)*.48;
 water=mix(water,bed_tint*(.9+.2*broad),transmission);
 // Short, broken foam traces follow the submerged ledge, not a white outline.
 float shore=1.0-smoothstep(.035,.22,depth);
 float wash=sin(depth*21.0-flow_time*TAU/8.0+noise(p*2.2)*3.0)*.5+.5;
 float broken=smoothstep(.47,.69,flowing_noise(vec2(q.x*5.0,q.y*2.4),1.28));
 float foam=shore*wash*broken*.30;
 water=mix(water,vec3(.30,.36,.35),foam);
 // The broad overcast sky breaks into small reflections on the moving
 // normals. Brightness belongs to the reflected angle, not painted stripes.
 vec3 world_view=normalize((INV_VIEW_MATRIX*vec4(VIEW,0)).xyz);
 vec3 reflected=reflect(-world_view,n);
 vec2 sky_at=reflected.xz/max(.25,reflected.y)*1.2;
 float cloud=noise(sky_at*2.3)*.7+noise(sky_at*5.1)*.3;
 vec3 sky=mix(vec3(.08,.13,.17),vec3(.45,.48,.48),smoothstep(.20,.80,cloud));
 float fresnel=.04+.35*pow(1.0-max(0.0,dot(n,world_view)),4.0);
 water=mix(water,sky,fresnel*smoothstep(.03,.45,depth));
 // A broken capillary wake curls around each immersed pier and drifts away.
 float wake=0.0;
 for(int i=0;i<pier_count;i++) {
  vec2 delta=p-piers[i].xy;
  float radius=length(delta);
  float rim=exp(-pow((radius-piers[i].z-.10)/.14,2.0));
  float curl=.5+.5*sin(atan(delta.y,delta.x)*3.0-radius*5.0+flow_time*TAU/8.0);
  float tail=exp(-pow(delta.x/.55,2.0))*smoothstep(.4,1.1,delta.y)*(1.0-smoothstep(1.1,2.8,delta.y));
  wake=max(wake,(rim*.28+tail*.12)*smoothstep(.35,.8,curl)*flow);
 }
 water=mix(water,vec3(.26,.32,.32),wake);
 ALBEDO=water;
 METALLIC=.18;
 SPECULAR=.75;
 ROUGHNESS=mix(.19,.33,foam);
 ALPHA=1.0;
}
