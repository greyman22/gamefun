extends RefCounted

var mutex := Mutex.new()
var chunks: Dictionary = {}
var limit: int = 384

func get_base(seed_value: int, key: Vector3i, generator: RefCounted) -> PackedByteArray:
	var cache_key: String = "%d:%d,%d,%d" % [seed_value, key.x, key.y, key.z]
	mutex.lock()
	if chunks.has(cache_key):
		var existing: PackedByteArray = chunks[cache_key]
		mutex.unlock()
		return existing
	mutex.unlock()
	# Generate outside the lock. Published arrays are immutable/COW.
	var data: PackedByteArray = generator.generate(key)
	mutex.lock()
	if chunks.size() >= limit:
		chunks.erase(chunks.keys()[0])
	chunks[cache_key] = data
	mutex.unlock()
	return data
