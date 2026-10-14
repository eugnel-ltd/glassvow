// Act I's river (R3.4, issue #660), shared by the full shader
// (`river.gdshader`) and the lean one (`river_lite.gdshader`): the channel's
// line and current, the vertex waves, and the water's colour. The two differ
// only in the ripple normal and in what shows through the shallows.
//
// The look (a lane pick; the owner may re-pick): a cold river at the foot of a
// gorge at golden hour. The open water is dark and deep; the warm sky shows in
// it only at a grazing angle and along slick current lines; white water
// breaks at the cliffs' feet, round each pier and in drifting flecks; and the
// gorge's walls shade the water next to them.
//
// The ravine's line: MapRavine.centre(river_cut, z), on the GPU's sine.
uniform float river_cut = 0.0;
uniform float channel = 1.0;
uniform float river_length_m = 70.0;
uniform sampler2D bathymetry : filter_linear, repeat_disable;
uniform float flow_time = 0.0;
uniform int pier_count = 0;
uniform vec4 piers[16];
// The palette, linear. `deep_tint` and `shallow_tint` are the water by depth;
// `foam_tint` the white water, lit by the key like the land; `sky_low` and
// `sky_high` what the water reflects, from the gorge's shade overhead to the
// warm glow toward the horizon.
uniform vec3 deep_tint = vec3(.012,.032,.040);
uniform vec3 shallow_tint = vec3(.040,.074,.076);
uniform vec3 foam_tint = vec3(.58,.60,.57);
uniform vec3 sky_low = vec3(.62,.44,.28);
uniform vec3 sky_high = vec3(.07,.10,.13);
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
// Noise carried downstream by `distance` over each 8 s cycle, cross-faded
// between two half-cycle phases so it never jumps.
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
// The surface lifted by the waves, which die out toward the banks. Both
// shaders' vertex(): `VERTEX = river_vertex(VERTEX, UV); world_at = VERTEX;`.
vec3 river_vertex(vec3 vertex,vec2 uv) {
 float depth=texture(bathymetry,uv).r;
 return vertex+vec3(0,waves(vertex.xz)*smoothstep(.0,.5,depth),0);
}

// The water's colour at `p` (world xz) under the world-space normal `n`, with
// `bed` what shows through the shallows; `foam` is how white it breaks there.
vec3 river_colour(vec2 p,vec3 n,float depth,vec3 bed,vec3 world_view,out float foam) {
 vec2 q=current(p);
 // 0 on the line, 1 at the mesh's edge. The gorge's cliffs hide the water
 // beyond about .55; their feet stand in it from about .4.
 float across=abs(river_uv(p).x-.5)*2.0;
 float broad=flowing_noise(vec2(q.x*.67,q.y*.16),.32);
 vec3 water=mix(shallow_tint,deep_tint,smoothstep(.12,1.6,depth));
 water*=.88+.24*broad;
 float transmission=exp(-depth*2.2)*.42;
 water=mix(water,bed,transmission);
 // The gorge's walls shade the water at their feet.
 water*=mix(1.0,.6,smoothstep(.30,.55,across));
 // The sky: the gorge's shade overhead, warm glow toward the horizon, seen
 // at a grazing angle and along long, slick current lines.
 vec3 reflected=reflect(-world_view,n);
 vec3 sky=mix(sky_low,sky_high,smoothstep(.15,.85,reflected.y));
 float fresnel=.03+.40*pow(1.0-max(0.0,dot(n,world_view)),4.0);
 float lines=flowing_noise(vec2(q.x*3.4,q.y*.28),1.6);
 float sheen=smoothstep(.62,.86,lines)*.12*(1.0-smoothstep(.25,.5,across));
 water=mix(water,sky,(fresnel+sheen)*smoothstep(.03,.40,depth));
 // White water, as lace: two scales of noise carried downstream, multiplied.
 float lace=flowing_noise(vec2(q.x*7.0,q.y*2.2),2.4)*flowing_noise(vec2(q.x*17.0,q.y*5.2),3.2);
 // At the banks: where the water meets the cliffs' feet and the shallows.
 float shore=max(1.0-smoothstep(.04,.26,depth),smoothstep(.40,.56,across));
 float bank=shore*smoothstep(.08,.46,lace+.10*shore);
 // In the open: sparse, faint flecks drifting with the current.
 float fleck=smoothstep(.42,.62,lace)*smoothstep(.20,.60,depth)*(1.0-shore);
 // Round each pier: a ring at the stone and a tail downstream.
 float wake=0.0;
 for(int i=0;i<pier_count;i++) {
  vec2 delta=p-piers[i].xy;
  float radius=length(delta);
  float rim=exp(-pow((radius-piers[i].z-.10)/.16,2.0));
  float curl=.5+.5*sin(atan(delta.y,delta.x)*3.0-radius*5.0+flow_time*TAU/8.0);
  float tail=exp(-pow(delta.x/.6,2.0))*smoothstep(.3,1.0,delta.y)*(1.0-smoothstep(1.2,3.2,delta.y));
  wake=max(wake,(rim*.8+tail*.4)*smoothstep(.30,.75,curl)*smoothstep(.05,.30,lace));
 }
 foam=clamp(max(max(bank*.50,fleck*.26),wake),0.0,1.0);
 return mix(water,foam_tint,foam);
}
