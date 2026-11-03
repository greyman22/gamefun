extends RefCounted
# Initial structure/site preparation removes complete intersecting natural trees.
# This is a voxel edit transaction, not gameplay chopping or timed leaf decay.
static func cells(model: RefCounted, tree: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i]=[]
	if tree.has("voxels"):
		for offset: Vector3i in tree.voxels:
			if int(tree.voxels[offset]) in [3,4]:
				result.append(tree.base+offset)
	else:
		for y in range(int(tree.height)+2):
			for x in range(-1,2):
				for z in range(-1,2):
					var point: Vector3i=tree.base+Vector3i(x,y,z)
					if model.generator.tree_kind(point,tree) in [3,4]:
						result.append(point)
	return result

static func clear_area(model: RefCounted, minimum: Vector2i, maximum: Vector2i, writer: Callable) -> int:
	# Maximum is exclusive, matching range() in the terrain preparation code.
	var trees: Dictionary={}
	for x in range(floori(float(minimum.x)/16),floori(float(maximum.x-1)/16)+1):
		for z in range(floori(float(minimum.y)/16),floori(float(maximum.y-1)/16)+1):
			for tree: Dictionary in model.generator.trees_in_chunk(Vector3i(x,0,z)):
				trees[tree.base]=tree
	var removed: int=0
	for tree: Dictionary in trees.values():
		var points: Array[Vector3i]=cells(model,tree)
		var overlaps: bool=false
		for point: Vector3i in points:
			if point.x>=minimum.x and point.x<maximum.x and point.z>=minimum.y and point.z<maximum.y:
				overlaps=true
				break
		if not overlaps:
			continue
		for point: Vector3i in points:
			# Preserve existing explicit building/player edits, including planted logs.
			if model.edits.get(model.key(point),{}).has(model.index(point)):
				continue
			var natural: int=model.generator.tree_kind(point,tree)
			if model.sample_block(point)==natural:
				writer.call(point,"air")
				removed+=1
			model.decay.erase(point)
	return removed
