@tool
extends EditorPlugin


class PaintingExporter:
	extends EditorExportPlugin

	const Builder = preload("res://tools/painting_export_builder.gd")
	var _inputs: Dictionary = {}
	var _converted: Dictionary = {}
	var _failures: Array[String] = []
	var _directory: String = ""

	func _get_name() -> String:
		return "glassvow_bounded_paintings"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		_inputs.clear()
		_converted.clear()
		_failures.clear()
		_directory = OS.get_cache_dir().path_join("glassvow-painting-export")
		if DirAccess.make_dir_recursive_absolute(_directory) != OK:
			_failures.append("cannot create painting build cache")
		for row: Dictionary in Builder.rows():
			_inputs[row["path"]] = row
		if _inputs.size() != 21:
			_failures.append("expected exactly 21 painting inputs")

	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		if not _failures.is_empty():
			# Even an invalid input manifest cannot restore uncapped source imports.
			if path.begins_with("res://assets/art/scenes/") or path.begins_with("res://assets/art/stage/"):
				skip()
			return
		if not _inputs.has(path):
			return
		# A failed conversion must never fall back to the oversized original.
		skip()
		var row: Dictionary = _inputs[path]
		var built: Dictionary = Builder.save(row, _directory, _failures)
		if built.is_empty():
			return
		var bytes: PackedByteArray = built["bytes"]
		var virtual: String = built["path"]
		add_file(virtual, bytes, true)
		_converted[path] = {"path": virtual, "sha256": Builder.sha(bytes)}

	func _export_end() -> void:
		if _converted.size() != 21:
			_failures.append("only %d of 21 paintings were exported" % _converted.size())
		var receipt_path: String = OS.get_environment("GLASSVOW_PAINTING_RECEIPT")
		if not receipt_path.is_empty():
			var receipt: FileAccess = FileAccess.open(receipt_path, FileAccess.WRITE)
			if receipt != null:
				receipt.store_string(JSON.stringify({"converted": _converted, "failures": _failures}, "\t") + "\n")
		for failure: String in _failures:
			push_error("painting export: " + failure)
		# The checked export command grades this receipt and the actual isolated
		# pack. EditorExportPlugin logging alone cannot set the CLI exit status.


var _exporter: PaintingExporter


func _enter_tree() -> void:
	_exporter = PaintingExporter.new()
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null
