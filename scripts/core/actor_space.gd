extends RefCounted
const HEN_WANDER_RADIUS: float=20.0
const Registry = preload("res://scripts/core/registry.gd")

static func radius(kind: String, node: Node3D) -> float:
	return (0.24 if node.chick else 0.43) if kind=="sheep" else ((0.18 if node.chick else 0.34) if kind == "hen" else 0.34)

static func height(kind: String, node: Node3D) -> float:
	return (0.6 if node.chick else 1.15) if kind=="sheep" else ((0.48 if node.chick else 0.92) if kind == "hen" else 1.8)

static func clear(model: RefCounted, point: Vector3, width: float, tall: float) -> bool:
	for x in [-width, width]:
		for z in [-width, width]:
			for y in [0.06, tall * 0.5, tall - 0.04]:
				if Registry.cube(model.sample_block(Vector3i((point + Vector3(x, y, z)).floor()))):
					return false
	return true

static func move(system: Node, entry: Dictionary, offset: Vector3) -> float:
	var node: Node3D = entry.node
	var before := node.position
	for axis in [0, 2]:
		var candidate := node.position
		candidate[axis] += offset[axis]
		if (entry.kind in ["zombie","skeleton"] and not node.clear_at(candidate)) or (entry.kind not in ["zombie","skeleton"] and not clear(system.model, candidate, entry.radius * 0.72, entry.height)):
			continue
		if entry.kind in ["hen","sheep"] and not node.following_seeds and not node.family_following and not node.record.get("settling_home",false) and Vector2(node.position.x-node.record.home.x,node.position.z-node.record.home.z).length()<=node.wander_radius and Vector2(candidate.x - node.record.home.x, candidate.z - node.record.home.z).length() > node.wander_radius:
			continue
		node.position = candidate
	var shift := node.position - before
	if shift.length_squared() > 0.000001 and entry.kind in ["hen","sheep"]:
		# Keep a moving bird's interpolation aligned with its corrected body.
		node.step_from += shift
		node.step_to += shift
	return shift.length()

static func separate(system: Node, player: CharacterBody3D = null) -> void:
	var actors: Array[Dictionary] = []
	for id: String in system.active:
		if not system.model.entities.has(id):
			continue
		var kind: String = system.model.entities[id].type
		if kind not in ["hen", "sheep", "zombie", "skeleton"]:
			continue
		var node: Node3D = system.active[id]
		actors.append({"id":id, "kind":kind, "node":node, "radius":radius(kind, node), "height":height(kind, node)})
	# A few bounded passes also repair overlapping actors from older saves.
	for iteration in range(5):
		var overlaps: bool=false
		for index in range(actors.size()):
			var a: Dictionary = actors[index]
			for other in range(index + 1, actors.size()):
				var b: Dictionary = actors[other]
				var reach: float=a.radius+b.radius+0.02
				if absf(a.node.position.x-b.node.position.x)>reach or absf(a.node.position.z-b.node.position.z)>reach:
					continue
				if a.node.position.y + a.height <= b.node.position.y or b.node.position.y + b.height <= a.node.position.y:
					continue
				var offset: Vector3 = a.node.position - b.node.position
				offset.y = 0
				var distance := offset.length()
				var overlap: float = a.radius + b.radius + 0.02 - distance
				if overlap <= 0.001:
					continue
				overlaps=true
				var direction: Vector3 = offset / distance if distance > 0.0001 else Vector3.RIGHT.rotated(Vector3.UP, float((index * 7 + other * 13) % 17) * 0.37)
				var first := move(system, a, direction * overlap * 0.5)
				var second := move(system, b, -direction * (overlap - first))
				if first + second < overlap - 0.001:
					move(system, a, direction * (overlap - first - second))
			if player == null or a.node.position.y + a.height <= player.position.y or player.position.y + 1.8 <= a.node.position.y:
				continue
			var offset: Vector3 = a.node.position - player.position
			offset.y = 0
			var gap: float = a.radius + 0.34 + 0.02 - offset.length()
			if gap > 0.001:
				overlaps=true
				var direction: Vector3 = offset.normalized() if offset.length() > 0.0001 else Vector3.RIGHT
				var moved: float = move(system, a, direction * gap)
				# If terrain pins the creature, stop/push the player on a free axis instead.
				if moved < gap - 0.001:
					for axis in [0, 2]:
						var candidate: Vector3 = player.position
						candidate[axis] -= direction[axis] * (gap - moved)
						if clear(system.model, candidate, 0.3, 1.8):
							player.position = candidate
		if not overlaps:
			break
	for actor: Dictionary in actors:
		system.model.entities[actor.id].position = actor.node.position
