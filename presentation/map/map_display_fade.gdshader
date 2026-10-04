shader_type canvas_item;
// The map's display while its screen fades (`MapFilmGrain.FADE_SHADER`): it
// blends like any canvas item, so the land fades with the screen's modulate.
render_mode unshaded;
#include "res://presentation/map/map_display.gdshaderinc"
