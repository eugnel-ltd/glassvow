shader_type canvas_item;
// The map's display at rest (`MapFilmGrain.SHADER`): it covers the screen
// opaque, so it writes over what is beneath without blending, which saves the
// A12 about 0.4 ms a frame at the iPad's resolution.
render_mode unshaded, blend_disabled;
#include "res://presentation/map/map_display.gdshaderinc"
