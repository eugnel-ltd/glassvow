class_name SharedShaders
extends RefCounted
## One Shader per code string, for the process (#682 Part 2).
##
## The renderer keeps a material's pipelines with its Shader: each Shader has
## its own pipeline cache, keyed by the draw's state (target format, vertex
## format, lights, ...). Two Shaders made from one string compile the same
## pipelines twice, and on the iPad 8 each compile holds the frame that needs
## it. So every shader the game builds from a string comes from here: the
## title's warm (`PathWarm`) and every use wear the same Shader, and the
## pipelines the warm drew serve the use. Materials stay per use; a Shader is
## only its code, so sharing one changes no picture.
##
## Held for the process: the engine frees a Shader's compiled variants and
## every pipeline built for it with its last reference, so a Shader let go
## between the warm and the use would have to compile again.

static var _by_code: Dictionary[String, Shader] = {}


## The process's Shader for `code`, made at its first request.
static func of(code: String) -> Shader:
	var shader: Shader = _by_code.get(code)
	if shader == null:
		shader = Shader.new()
		shader.code = code
		_by_code[code] = shader
	return shader
