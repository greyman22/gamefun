extends Node3D

const Berries = preload("res://scripts/core/berries.gd")
var model: RefCounted
var record: Dictionary
var visual: Node3D
var collision: CollisionShape3D
var shown_stage: int = -1
var shown_ripe: bool = false

func configure(data: RefCounted, entity: Dictionary) -> void:
	model = data
	record = entity

func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	area.set_meta("berry_bush", true)
	collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	area.add_child(collision)
	add_child(area)
	refresh()

func part(point: Vector3, dimensions: Vector3, color: Color, round_shape: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	if round_shape:
		var sphere := SphereMesh.new()
		sphere.radius = dimensions.x * 0.5
		sphere.height = dimensions.y
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh.mesh = sphere
	else:
		var box := BoxMesh.new()
		box.size = dimensions
		mesh.mesh = box
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 1
	mesh.material_override = surface
	mesh.position = point
	visual.add_child(mesh)

func refresh() -> void:
	if not is_instance_valid(visual):
		return
	var growth: int = Berries.stage(record, model.game_time)
	var ready: bool = Berries.ripe(record, model.game_time)
	if growth == shown_stage and ready == shown_ripe:
		return
	shown_stage = growth
	shown_ripe = ready
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	var height: float = [0.2, 0.4, 0.65, 0.9][growth]
	var width: float = [0.35, 0.6, 0.85, 1.0][growth]
	collision.shape.size = Vector3(width, height, width)
	collision.position.y = height * 0.5
	part(Vector3(0, height * 0.35, 0), Vector3(0.045, height * 0.7, 0.045), Color(0.35, 0.22, 0.1))
	var size_value: float = [0.15, 0.26, 0.38, 0.48][growth]
	for index in range(2 + growth):
		var angle: float = index * TAU / (2 + growth)
		var offset := Vector3(cos(angle), 0, sin(angle)) * size_value * 0.35
		part(Vector3(0, height * (0.5 + float(index % 2) * 0.2), 0) + offset, Vector3(size_value, size_value * 0.7, size_value), Color(0.19 + index * 0.015, 0.42 + index * 0.02, 0.12))
	if ready:
		for index in range(8):
			var angle: float = index * TAU / 8
			var offset := Vector3(cos(angle) * 0.42, 0.45 + (index % 3) * 0.1, sin(angle) * 0.42)
			part(offset, Vector3.ONE * 0.1, Color(0.1, 0.18, 0.72), true)
		part(Vector3(0.1, 0.83, 0.05), Vector3.ONE * 0.1, Color(0.12, 0.22, 0.8), true)

