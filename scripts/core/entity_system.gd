extends Node3D

const Registry = preload("res://scripts/core/registry.gd")
const Visuals = preload("res://scripts/item_visuals.gd")
const Pickup = preload("res://scripts/pickup.gd")
var model: RefCounted
var active: Dictionary = {}
var factories: Dictionary = {}
var elapsed: float = 1
var shadow_light_limit: int = 4
var torch_light_limit: int = 12

func register_actor(kind: String, scene: PackedScene) -> void:
	factories[kind] = scene

func configure(data: RefCounted) -> void:
	model = data

func tick(position: Vector3, delta: float) -> void:
	elapsed += delta
	if elapsed < 0.3:
		return
	elapsed = 0
	var nearby: Array = []
	for id: String in model.entities:
		var record: Dictionary = model.entities[id]
		var distance: float = position.distance_to(record.position)
		var radius: float = float(Registry.catalog.actors.get(record.type, {}).get("active_distance", 32))
		if distance <= radius:
			nearby.append({"id": id, "distance": distance})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	var wanted: Dictionary = {}
	var lights: int = 0
	for entry: Dictionary in nearby:
		var record: Dictionary = model.entities[entry.id]
		if record.type == "torch":
			lights += 1
		wanted[entry.id] = true
		if not active.has(entry.id):
			activate(entry.id, record)
		if record.type == "torch" and active.has(entry.id):
			var sources: Array[Node] = active[entry.id].find_children("*", "OmniLight3D", true, false)
			for source in sources:
				source.visible = lights <= torch_light_limit
				source.shadow_enabled = lights <= shadow_light_limit
	for id: String in active.keys():
		if not wanted.has(id):
			deactivate(id)

func activate(id: String, record: Dictionary) -> void:
	var node: Node3D
	match record.type:
		"pickup":
			node = Pickup.new()
			node.configure(record.kind)
			if not record.get("state", {}).get("falling", false):
				var title := Label3D.new()
				title.text = Registry.label(record.kind)
				title.position.y = 0.6
				title.font_size = 36
				title.pixel_size = 0.007
				title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				node.add_child(title)
		"torch":
			node = StaticBody3D.new()
			node.set_meta("build_surface", true)
			node.set_meta("cell", record.cell)
			Visuals.torch_model(node, 2.5)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.1, 0.6, 0.1)
			collision.shape = shape
			node.add_child(collision)
		_:
			if not factories.has(record.type):
				return
			node = factories[record.type].instantiate()
			if node.has_method("restore_state"):
				node.restore_state(record.get("state", {}))
	node.position = record.position
	node.set_meta("entity_id", id)
	add_child(node)
	active[id] = node

func deactivate(id: String) -> void:
	if not active.has(id):
		return
	var node: Node3D = active[id]
	if model.entities.has(id):
		model.entities[id].position = node.position
		if node.has_method("serialize_state"):
			model.entities[id].state = node.serialize_state()
	remove_child(node)
	node.queue_free()
	active.erase(id)

func collect(position: Vector3, inventory: RefCounted) -> bool:
	var changed: bool = false
	for id: String in active.keys():
		if not model.entities.has(id):
			continue
		var record: Dictionary = model.entities[id]
		if record.type == "pickup" and model.game_time >= float(record.get("ready_at", 0)) and position.distance_to(record.position) <= 1.5:
			var remaining: int = int(record.get("count", 1))
			while remaining > 0 and inventory.add_item(record.kind):
				remaining -= 1
				changed = true
			record.count = remaining
			if remaining == 0:
				model.entities.erase(id)
				deactivate(id)
	return changed

func spawn_drop(kind: String, position: Vector3, count: int = 1) -> String:
	var id: String = "drop_%d_%d" % [Time.get_ticks_usec(), randi()]
	# A small sideways impulse carries high drops farther during their longer flight.
	var angle: float = randf() * TAU
	var speed: float = randf_range(1.0, 1.8)
	model.entities[id] = {"type": "pickup", "kind": kind, "position": position, "count": count, "ready_at": model.game_time + 0.5, "state": {"falling": true, "velocity_y": 0.0, "velocity_x": cos(angle) * speed, "velocity_z": sin(angle) * speed}}
	elapsed = 1
	return id

func simulate_drops(delta: float) -> void:
	for id: String in active:
		if not model.entities.has(id):
			continue
		var record: Dictionary = model.entities[id]
		if record.type != "pickup" or not record.get("state", {}).get("falling", false):
			continue
		var position: Vector3 = record.position
		var velocity: float = maxf(-30, float(record.state.get("velocity_y", 0)) - 18 * delta)
		var sideways := Vector3(float(record.state.get("velocity_x", 0)), 0, float(record.state.get("velocity_z", 0)))
		var movement := Vector3(sideways.x, velocity, sideways.z) * delta
		var steps: int = maxi(1, ceili(movement.length() / 0.1))
		for step in range(steps):
			for axis in [0, 2]:
				var proposed: Vector3 = position
				proposed[axis] += sideways[axis] * delta / steps
				if drop_overlaps_block(proposed):
					sideways[axis] = 0
				else:
					position = proposed
			var proposed_y: float = position.y + velocity * delta / steps
			var floor_top: float = -INF
			for x in [-0.124, 0.124]:
				for z in [-0.124, 0.124]:
					var cell := Vector3i(floori(position.x + x), floori(proposed_y - 0.125), floori(position.z + z))
					if Registry.cube(model.block(cell)):
						floor_top = maxf(floor_top, cell.y + 1.125)
			if floor_top > -INF:
				position.y = floor_top
				velocity = 0
				sideways = Vector3.ZERO
				break
			position.y = proposed_y
		record.state.velocity_x = sideways.x
		record.state.velocity_z = sideways.z
		record.position = position
		record.state.velocity_y = velocity
		active[id].position = position

func drop_overlaps_block(position: Vector3) -> bool:
	for x in [-0.124, 0.124]:
		for y in [-0.124, 0.124]:
			for z in [-0.124, 0.124]:
				if Registry.cube(model.block(Vector3i(floori(position.x + x), floori(position.y + y), floori(position.z + z)))):
					return true
	return false

func snapshot_active() -> void:
	for id: String in active:
		if model.entities.has(id):
			model.entities[id].position = active[id].position
			if active[id].has_method("serialize_state"):
				model.entities[id].state = active[id].serialize_state()
