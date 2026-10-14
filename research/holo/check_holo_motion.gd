extends SceneTree
## Research (#657 holo): the motion signal's fusion, on synthetic readings.
##   godot --headless -s res://research/holo/check_holo_motion.gd

var _fails: int = 0


func _check(name: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1


func _run(m: HoloMotion, g: Vector3, w: Vector3, secs: float) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	var n: int = int(secs * 60.0)
	for _i: int in range(n):
		out = m.step(g, w, 1.0 / 60.0)
	return out


func _init() -> void:
	var up: Vector3 = Vector3(0.0, -9.81, 0.0)          # upright, landscape
	var m: HoloMotion = HoloMotion.new()
	var o: Vector2 = _run(m, up, Vector3.ZERO, 1.0)
	_check("upright at rest", o.length() < 0.01, str(o))
	o = _run(m, up, up.normalized() * 0.5, 0.4)          # 11.5 deg twist about gravity
	_check("upright twist reads as a left-right lean", absf(o.x) > 0.5 and absf(o.y) < 0.05, str(o))
	o = _run(m, up, Vector3.ZERO, 30.0)
	_check("twist leaks home with no rate", o.length() < 0.05, str(o))
	var m2: HoloMotion = HoloMotion.new()
	o = _run(m2, up, Vector3.ZERO, 0.5)
	o = _run(m2, up, up.normalized() * 1000.0, 1.0)
	_check("gyro glitch clamped to the budget", absf(o.x) <= tanh(1.3) + 0.001, str(o))
	var m3: HoloMotion = HoloMotion.new()
	o = _run(m3, up, Vector3(NAN, 0.0, 0.0), 1.0)
	_check("non-finite gyro ignored", o.length() < 0.01, str(o))
	var m4: HoloMotion = HoloMotion.new()
	var flat: Vector3 = Vector3(0.0, 0.0, -9.81)
	_run(m4, flat, Vector3.ZERO, 0.5)
	var lean: Vector3 = flat.rotated(Vector3(1.0, 0.0, 0.0), deg_to_rad(10.0))
	o = m4.step(lean, Vector3.ZERO, 1.0 / 60.0)
	_check("flat device, 10 deg lean, gravity only", absf(o.y) > 0.55 and absf(o.x) < 0.02, str(o))
	var m5: HoloMotion = HoloMotion.new()
	_run(m5, up, Vector3.ZERO, 0.5)
	var pitch: Vector3 = up.rotated(Vector3(1.0, 0.0, 0.0), deg_to_rad(10.0))
	o = m5.step(pitch, Vector3.ZERO, 1.0 / 60.0)
	_check("upright, 10 deg pitch, gravity only", absf(o.y) > 0.55, str(o))
	print("%d failure(s)" % _fails)
	m.free(); m2.free(); m3.free(); m4.free(); m5.free()
	quit(1 if _fails > 0 else 0)
