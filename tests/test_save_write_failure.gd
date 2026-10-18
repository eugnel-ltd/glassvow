extends RefCounted
## Exercise a real short write in a child so the suite's own file limits stay
## unchanged. Existing save roundtrips cover platforms without POSIX ulimit.


static func run(fails: Array[String]) -> void:
	if OS.get_name() not in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		print("save short-write injection: skipped (requires POSIX ulimit)")
		return
	var output: Array = []
	var status: int = OS.execute("/bin/sh", PackedStringArray([
		ProjectSettings.globalize_path("res://tests/support/save_write_failure.sh"),
		OS.get_executable_path(), "--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s",
		"res://tests/support/save_write_failure.gd",
	]), output, true)
	var log: String = "\n".join(output)
	if status != 0 or not log.contains("save short-write injection: PASS"):
		fails.append("save short-write injection: child exited %d\n%s" % [status, log])
