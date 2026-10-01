class_name MapScreenKeep
extends RefCounted
## Holds the act's built map screen while another route is up, so a return to
## the map re-attaches it instead of building it again (`WorldMapScreen.reopen`).
##
## One screen, detached from the tree, with the identity it was built for (the
## owner's key: its map, run, act, shape and language). `take` hands it back only
## for that identity and frees it for any other, so a stale screen is never
## shown. The owner releases it when its map is replaced (an act change, a new or
## resumed run, the title) and when the run ends; dropping the keep frees it too.

var _screen: WorldMapScreen = null
var _key: Array = []


## The kept screen when it was kept for `key`, detached and ready to re-attach.
## Otherwise null, and whatever was kept is freed. Either way nothing stays kept:
## the caller owns what it is given.
func take(key: Array) -> WorldMapScreen:
	var screen: WorldMapScreen = _screen if is_instance_valid(_screen) else null
	var same: bool = key == _key
	_screen = null
	_key = []
	if screen == null or same:
		return screen
	screen.queue_free()
	return null


## Detaches `screen` from its parent and keeps it for `key`, in place of anything
## kept before. A screen that could not come back as it stands
## (`WorldMapScreen.can_keep`) is freed instead, as every route change freed it
## before the keep existed.
func keep(screen: WorldMapScreen, key: Array) -> void:
	if screen == null:
		return
	if screen != _screen:
		release()
	if not screen.can_keep():
		_screen = null
		_key = []
		screen.queue_free()
		return
	var parent: Node = screen.get_parent()
	if parent != null:
		parent.remove_child(screen)
	_screen = screen
	_key = key.duplicate()


## The screen kept now, or null. For tests and benches.
func kept() -> WorldMapScreen:
	return _screen if is_instance_valid(_screen) else null


## Frees the kept screen, if any. Deferred, because a release can be reached
## from a signal the kept screen itself emitted before it was detached.
func release() -> void:
	if is_instance_valid(_screen) and not _screen.is_queued_for_deletion():
		_screen.queue_free()
	_screen = null
	_key = []


func _notification(what: int) -> void:
	# The keep's owner is going (Main at exit or a test's teardown): the frame
	# that would run a deferred free may never come.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_screen) \
			and not _screen.is_queued_for_deletion():
		_screen.free()
