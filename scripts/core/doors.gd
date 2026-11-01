extends RefCounted
const Space = preload("res://scripts/core/actor_space.gd")
const Registry = preload("res://scripts/core/registry.gd")
const PARTS = ["door","door_top","door_open","door_top_open","gate","gate_open"]
static func entity_id(model: RefCounted, cell: Vector3i) -> String:
	if model.kind_at(cell) in ["door_top","door_top_open"]:
		cell += Vector3i.DOWN
	return "door_" + model.text_key(cell)
static func can_place(model: RefCounted, cell: Vector3i, kind: String = "door") -> bool:
	if kind == "gate":
		return model.block(cell)==0 and Registry.cube(model.block(cell+Vector3i.DOWN))
	return cell.y < 63 and model.block(cell) == 0 and model.block(cell + Vector3i.UP) == 0 and Registry.cube(model.block(cell + Vector3i.DOWN))
static func place(model: RefCounted, cell: Vector3i, yaw: float, kind: String = "door") -> void:
	model.set_block(cell,kind)
	if kind == "door":
		model.set_block(cell + Vector3i.UP,"door_top")
	model.entities[entity_id(model,cell)] = {"type":"door","kind":kind,"cell":cell,"position":Vector3(cell)+Vector3(0.5,0,0.5),"yaw":yaw,"open":false,"state":{}}
static func toggle(system: Node, cell: Vector3i, player: CharacterBody3D = null) -> bool:
	var id := entity_id(system.model,cell)
	if not system.model.entities.has(id):
		return false
	var record: Dictionary = system.model.entities[id]
	var gate: bool = record.get("kind","door")=="gate"
	var plane: float = 0.0 if gate else -0.38
	if record.open:
		var bodies: Array[Node3D] = []
		if player != null:
			bodies.append(player)
		for other: String in system.active:
			if system.model.entities[other].type in ["zombie","hen"]:
				bodies.append(system.active[other])
		var displacements: Array[Dictionary] = []
		for body in bodies:
			if body.position.y >= record.cell.y+(1 if gate else 2) or body.position.y+1.8 <= record.cell.y:
				continue
			var local: Vector3 = (body.position-record.position).rotated(Vector3.UP,-float(record.yaw))
			var radius: float = 0.35 if body == player else 0.34
			if absf(local.x)>0.42+radius or absf(local.z-plane)>radius+0.08:
				continue
			var side: float = 1.0 if local.z-plane >= 0 else -1.0
			var destination: Variant = null
			for chosen in [side,-side]:
				var candidate := local
				candidate.z = plane+chosen*(radius+0.09)
				if body != player:
					candidate.z = 0.87 if chosen>0 else -0.87
				candidate = record.position+candidate.rotated(Vector3.UP,float(record.yaw))
				if Space.clear(system.model,candidate,radius*0.85,1.8):
					destination = candidate
					break
			if destination == null:
				return false
			displacements.append({"body":body,"point":destination})
		for change in displacements:
			var shift: Vector3 = change.point-change.body.position
			change.body.position = change.point
			if change.body.has_method("serialize_state") and change.body.get("record") != null:
				change.body.step_from += shift
				change.body.step_to += shift
	if gate and not record.open and player != null:
		var local_player: Vector3 = (player.position-record.position).rotated(Vector3.UP,-float(record.yaw))
		record.swing_sign = -1.0 if local_player.z>=0 else 1.0
	record.open = not record.open
	if gate:
		system.model.set_block(record.cell,"gate_open" if record.open else "gate")
	else:
		system.model.set_block(record.cell,"door_open" if record.open else "door")
		system.model.set_block(record.cell+Vector3i.UP,"door_top_open" if record.open else "door_top")
	if system.active.has(id):
		system.active[id].refresh()
	return true
static func remove(system: Node, cell: Vector3i) -> void:
	var id := entity_id(system.model,cell)
	if system.model.entities.has(id):
		var gate: bool = system.model.entities[id].get("kind","door")=="gate"
		var bottom: Vector3i = system.model.entities[id].cell
		system.deactivate(id)
		system.model.entities.erase(id)
		system.model.set_block(bottom,"air")
		if not gate:
			system.model.set_block(bottom+Vector3i.UP,"air")

static func pick(system: Node, from: Vector3, to: Vector3, exclude: Array[RID]) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(from,to,33,exclude)
	query.collide_with_areas = true
	var hit: Dictionary = system.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("door_cell"):
		return hit.collider.get_meta("door_cell")
	if not hit.is_empty() and hit.collider.has_meta("cell"):
		var cell: Vector3i = hit.collider.get_meta("cell")
		if system.model.kind_at(cell) in PARTS:
			return cell
	return null
