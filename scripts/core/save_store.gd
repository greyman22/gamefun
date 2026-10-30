extends RefCounted

const FORMAT_VERSION: int = 1
const ROOT: String = "user://worlds"

static func valid_id(id: String) -> bool:
	return not id.is_empty() and id == id.validate_filename() and not id.contains(".")

static func save(snapshot: Dictionary, root_path: String = ROOT) -> Error:
	var id: String = snapshot.world.world_id
	if not valid_id(id):
		return ERR_INVALID_PARAMETER
	var folder: String = root_path.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join("world.save")
	var temp: String = path + ".tmp"
	snapshot["format_version"] = FORMAT_VERSION
	snapshot["saved_at"] = Time.get_unix_time_from_system()
	var file := FileAccess.open_compressed(temp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(snapshot, false)
	file.flush()
	file.close()
	if read_file(temp).is_empty():
		return ERR_FILE_CORRUPT
	var backup: String = path + ".backup"
	if FileAccess.file_exists(path):
		if read_file(path).is_empty():
			# Preserve the last good backup when recovering a damaged primary.
			var removed: Error = DirAccess.remove_absolute(path)
			if removed != OK:
				return removed
		else:
			if FileAccess.file_exists(backup):
				DirAccess.remove_absolute(backup)
			var moved: Error = DirAccess.rename_absolute(path, backup)
			if moved != OK:
				return moved
	var result: Error = DirAccess.rename_absolute(temp, path)
	if result == OK:
		var index := FileAccess.open(root_path.path_join("last.txt"), FileAccess.WRITE)
		if index != null:
			index.store_string(id)
	return result

static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	var value: Variant = file.get_var(false)
	file.close()
	if not value is Dictionary or value.get("format_version", -1) != FORMAT_VERSION:
		return {}
	if not value.has_all(["world", "player", "inventory", "crafting", "selected"]):
		return {}
	return value

static func load_world(id: String, root_path: String = ROOT) -> Dictionary:
	if not valid_id(id):
		return {}
	var path: String = root_path.path_join(id).path_join("world.save")
	var snapshot := read_file(path)
	return read_file(path + ".backup") if snapshot.is_empty() else snapshot

static func last_id(root_path: String = ROOT) -> String:
	var path: String = root_path.path_join("last.txt")
	return FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""

static func worlds(root_path: String = ROOT) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root_path):
		return result
	for id in DirAccess.get_directories_at(root_path):
		var snapshot := load_world(id, root_path)
		if not snapshot.is_empty():
			result.append({"id": id, "seed": snapshot.world.seed, "saved_at": snapshot.saved_at})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_at > b.saved_at)
	return result
