extends Resource
## Act I's hero stone as the land builds it (R3.3, issue #660): each granite
## outcrop's and cliff piece's mesh as plain arrays, packed from the Blender
## kit's GLBs (`tools/map_atelier/journey/stone/pack_stone.gd`). A land merges
## them on its worker (`land_stone.gd`); an imported mesh's arrays could only
## be read back from the renderer there, a stall per read.

## Per kind: `Mesh.ARRAY_*` arrays (vertex, normal, tangent, UV, index).
@export var arrays: Dictionary = {}
## Per kind: its extent in its own space (x along, y up, z toward its face).
@export var bounds: Dictionary = {}
