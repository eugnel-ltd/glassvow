shader_type spatial;
render_mode cull_disabled;
// Coursed stone in world space: the masonry under the decks at its default
// tint (linear), the parapets lighter (`bridge_geometry.gd` `PARAPET_TINT`, R3.5).
uniform vec3 tint = vec3(.075,.067,.070);
varying vec3 world_at;
void vertex() { world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float row=floor(world_at.y/.32);
 vec2 tile=vec2((world_at.x+world_at.z)*1.3+mod(row,2.0)*.5,world_at.y/.32);
 vec2 edge=abs(fract(tile)-.5);
 float mortar=max(smoothstep(.477,.499,edge.x),smoothstep(.469,.499,edge.y));
 float block=fract(sin(dot(floor(tile),vec2(12.98,78.23)))*43758.54);
 ALBEDO=tint.rgb*(.91+.16*block)*(1.0-.14*mortar);
 ROUGHNESS=.96;
 SPECULAR=.08;
}
