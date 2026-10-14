shader_type spatial;
// The river on the desktop: `river_water.gdshaderinc`'s water, with the ripple
// normal from finite differences through the pier field and the real bed
// refracted through the shallows (a screen and a depth read).
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://presentation/map/landscape/river_water.gdshaderinc"
uniform sampler2D scene_colour : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
void vertex() {
 VERTEX=river_vertex(VERTEX,UV);
 world_at=VERTEX;
}
void fragment() {
 vec2 p=world_at.xz;
 float depth=texture(bathymetry,river_uv(p)).r;
 if(depth<=.003) { discard; }
 float ripples=smoothstep(.0,.5,depth);
 float dx=(waves(p+vec2(.025,0))-waves(p-vec2(.025,0)))/.05*ripples;
 float dz=(waves(p+vec2(0,.025))-waves(p-vec2(0,.025)))/.05*ripples;
 // Half the waves' slope: the swell reads as moving water, not as stripes.
 vec3 n=normalize(vec3(-dx*.5,1,-dz*.5));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 vec2 distortion=NORMAL.xz*.009*smoothstep(.0,.35,depth);
 vec2 sample_uv=clamp(SCREEN_UV+distortion,vec2(.001),vec2(.999));
 float raw_depth=texture(scene_depth,sample_uv).r;
 float ndc_depth=OUTPUT_IS_SRGB ? raw_depth*2.0-1.0 : raw_depth;
 vec4 position=INV_PROJECTION_MATRIX*vec4(sample_uv*2.0-1.0,ndc_depth,1.0);
 position/=position.w;
 vec3 behind=(INV_VIEW_MATRIX*position).xyz;
 // Never refract a foreground bridge, tree or bank into the water.
 if(behind.y>world_at.y+.04) { sample_uv=SCREEN_UV; }
 vec3 bed=textureLod(scene_colour,sample_uv,0.0).rgb;
 vec3 world_view=normalize((INV_VIEW_MATRIX*vec4(VIEW,0)).xyz);
 float foam;
 ALBEDO=river_colour(p,n,depth,bed,world_view,foam);
 METALLIC=.18*(1.0-foam);
 SPECULAR=.75;
 ROUGHNESS=mix(.14,.55,foam);
 ALPHA=1.0;
}
