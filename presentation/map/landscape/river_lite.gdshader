shader_type spatial;
// The river on phones and tablets (`MapScene.lean_profile`): river.gdshader's
// water without its two costliest parts, measured on the iPad 8 at the 40°
// journey camera. No screen or depth read (they force a colour and a depth
// copy of the frame): the bed seen through the shallows is a wet stone tint.
// The ripple normal is the waves' analytic slope, without the pier field,
// instead of four finite differences through it. Everything else is
// `river_water.gdshaderinc`'s, shared with the full shader.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://presentation/map/landscape/river_water.gdshaderinc"
uniform vec3 bed_tint = vec3(.075,.060,.050);
void vertex() {
 VERTEX=river_vertex(VERTEX,UV);
 world_at=VERTEX;
}
void fragment() {
 vec2 p=world_at.xz;
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
 // Half the waves' slope: the swell reads as moving water, not as stripes.
 vec3 n=normalize(vec3(-dx*.5,1,-dz*.5));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 vec3 world_view=normalize((INV_VIEW_MATRIX*vec4(VIEW,0)).xyz);
 float foam;
 ALBEDO=river_colour(p,n,depth,bed_tint,world_view,foam);
 METALLIC=.18*(1.0-foam);
 SPECULAR=.75;
 ROUGHNESS=mix(.14,.55,foam);
 ALPHA=1.0;
}
