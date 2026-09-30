class_name MapLayoutJob
extends RefCounted
## One MapLayoutCompiler.compile on the WorkerThreadPool, so the main thread
## keeps drawing while a world layout compiles. On an A12 the compile runs for
## minutes; on the main thread iOS killed the app as a hang (Sentry 1ec0d817).
## The compiler is pure static code over plain data; the job hands it private
## deep copies of the registries, so nothing it reads is shared with the main
## thread. The result is byte-identical to a main-thread compile.

## Input digest this job compiles; the owner's cache key.
var digest: String = ""
var _task: int = -1
## The pool forgets a task once it is waited on, so completion is remembered here.
var _joined: bool = false
## Written once by the worker. The bound task keeps it alive even if the job
## itself is dropped, so a late finish never writes into freed memory.
var _out: Array = []


static func start(input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> MapLayoutJob:
	var job: MapLayoutJob = MapLayoutJob.new()
	job.digest = input.digest()
	job._task = WorkerThreadPool.add_task(_compile_into.bind(job._out, input,
		quality.duplicate(true), assets.duplicate(true)), false,
		"map layout compile")
	return job


static func _compile_into(out: Array, input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> void:
	out.append(MapLayoutCompiler.compile(input, quality, assets))


func is_done() -> bool:
	return _joined or WorkerThreadPool.is_task_completed(_task)


## Joins the task (blocking until it ends) and returns the compiled packet.
## Safe to call again once joined.
func finish() -> Dictionary:
	if not _joined:
		WorkerThreadPool.wait_for_task_completion(_task)
		_joined = true
	var packet: Dictionary = _out[0]
	return packet
