class_name AppExit
extends RefCounted
## Whether this build may close itself. A desktop app may; the web has no
## process to leave and the tab owns close; iOS and Android do not let an app
## quit itself (Godot's SceneTree.quit() is ignored there — the player leaves
## with the system gesture). Every Quit the game offers asks this first.


## Tests pin the answer (true or false); null asks the platform.
static var forced: Variant = null


static func available() -> bool:
	if forced != null:
		return forced == true
	return not (OS.has_feature("web") or OS.has_feature("mobile"))
