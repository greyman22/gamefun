extends StaticBody3D
const Visuals = preload("res://scripts/item_visuals.gd")
var model: RefCounted
var record: Dictionary
func configure(data: RefCounted, value: Dictionary) -> void:
	model = data
	record = value
func _ready() -> void:
	add_to_group("wooden_fences")
	set_meta("build_surface",true)
	set_meta("cell",record.cell)
	refresh()
func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var cell: Vector3i = record.cell
	var connections: Array[Vector3i] = []
	for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		if model.kind_at(cell+direction) in ["fence","gate","gate_open"]:
			connections.append(direction)
	Visuals.fence_model(self,1.0,connections)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	collision.shape = box
	collision.position.y = 0.5
	add_child(collision)
