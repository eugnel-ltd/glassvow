extends SceneTree
## Launched by test_save_write_failure.gd with an 8-block file-size ceiling.
## SIGXFSZ is ignored so FileAccess reports the failed write to its caller.

var _fails: Array[String] = []
var _paths: Array[String] = []


func _initialize() -> void:
	var stem: String = "user://test_save_write_failure_%d_" % OS.get_process_id()
	var probe_path: String = stem + "probe"
	_paths.append(probe_path)
	var probe: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		_fails.append("could not open write-error control")
	else:
		probe.store_string("x".repeat(65536))
		probe.flush()
		if probe.get_error() == OK:
			_fails.append("file limit did not produce a real write error")
		probe.close()
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 717, "run-short-write")
	var run_path: String = stem + "run.json"
	_paths.append(run_path)
	if not SaveService.store(run, run_path):
		_fails.append("healthy run store failed")
	var accepted_run: String = FileAccess.get_file_as_string(run_path)
	run.quest_scratch["writeProbe"] = "x".repeat(65536)
	_check_failure(SaveService.store(run, run_path), run_path, accepted_run, "run")
	if SaveService.load_run(content, run_path) == null:
		_fails.append("accepted run no longer loads after failed store")
	var vigil: VigilState = VigilState.blank()
	var vigil_path: String = stem + "vigil.json"
	_paths.append(vigil_path)
	if not SaveService.store_vigil(vigil, vigil_path):
		_fails.append("healthy Vigil store failed")
	var accepted_vigil: String = FileAccess.get_file_as_string(vigil_path)
	vigil.scenes_seen.append("x".repeat(65536))
	_check_failure(SaveService.store_vigil(vigil, vigil_path),
		vigil_path, accepted_vigil, "Vigil")
	var ref_path: String = stem + "scenario.json"
	_paths.append(ref_path)
	var kernel: ScenarioKernel = ScenarioKernel.new(content, run_path, vigil_path, ref_path)
	var reference: ScenarioReference = ScenarioReference.new()
	if not kernel._store_ref(reference):
		_fails.append("healthy Scenario reference store failed")
	var accepted_ref: String = FileAccess.get_file_as_string(ref_path)
	reference.build = "x".repeat(65536)
	_check_failure(kernel._store_ref(reference), ref_path, accepted_ref, "Scenario reference")
	# A failed attempt must not poison the next healthy checkpoint.
	run.quest_scratch.erase("writeProbe")
	run.player.gold += 1
	if not SaveService.store(run, run_path):
		_fails.append("healthy store after a short write failed")
	var reloaded: RunState = SaveService.load_run(content, run_path)
	if reloaded == null or reloaded.player.gold != run.player.gold:
		_fails.append("healthy store after a short write did not roundtrip")
	for path: String in _paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	if _fails.is_empty():
		print("save short-write injection: PASS")
		quit(0)
	else:
		for failure: String in _fails:
			print("save short-write injection: FAIL: ", failure)
		quit(1)


func _check_failure(stored: bool, path: String, accepted: String, label: String) -> void:
	if stored:
		_fails.append("%s short write reported success" % label)
	if FileAccess.get_file_as_string(path) != accepted:
		_fails.append("%s short write replaced the accepted checkpoint" % label)
	if FileAccess.file_exists(path + ".tmp"):
		_fails.append("%s short write left its temporary file" % label)
