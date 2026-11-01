extends StaticBody3D
const Visuals = preload("res://scripts/item_visuals.gd")
var record: Dictionary
var hinge: Node3D
var gate_hinges: Array[Node3D] = []
func configure(value: Dictionary) -> void:
	record = value
func _ready() -> void:
	set_meta("build_surface",true)
	set_meta("cell",record.cell)
	rotation.y = float(record.yaw)
	if record.get("kind","door")=="gate":
		build_gate()
		refresh()
		return
	hinge = Node3D.new()
	hinge.position = Vector3(-0.42,0,-0.42)
	add_child(hinge)
	Visuals.door_model(hinge)
	# Collision is a child body so the actual leaf rotates with its hinge.
	var leaf := StaticBody3D.new()
	hinge.add_child(leaf)
	leaf.set_meta("build_surface",true)
	leaf.set_meta("cell",record.cell)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.84,2,0.12)
	collision.shape = box
	collision.position = Vector3(0.42,1,0.04)
	leaf.add_child(collision)
	var interaction := Area3D.new()
	interaction.collision_layer = 32
	interaction.collision_mask = 0
	interaction.set_meta("door_cell",record.cell)
	var hitbox := CollisionShape3D.new()
	var region := BoxShape3D.new()
	region.size = Vector3(1.5,2.2,1.1)
	hitbox.shape = region
	hitbox.position.y = 1
	interaction.add_child(hitbox)
	add_child(interaction)
	refresh()
func build_gate() -> void:
	for side in [-1,1]:
		var pivot := Node3D.new()
		pivot.position.x = side*0.46
		add_child(pivot)
		gate_hinges.append(pivot)
		Visuals.gate_leaf(pivot,side)
		var leaf := StaticBody3D.new()
		leaf.set_meta("build_surface",true)
		leaf.set_meta("cell",record.cell)
		pivot.add_child(leaf)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.46,1,0.12)
		collider.shape = shape
		collider.position = Vector3(-side*0.23,0.5,0)
		leaf.add_child(collider)
	var interaction := Area3D.new()
	interaction.collision_layer = 32
	interaction.collision_mask = 0
	interaction.set_meta("door_cell",record.cell)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3,1.1,1.1)
	collider.shape = shape
	collider.position.y = 0.5
	interaction.add_child(collider)
	add_child(interaction)

func refresh() -> void:
	if record.get("kind","door")=="gate":
		for i in range(2):
			gate_hinges[i].rotation.y = (-1 if i==0 else 1)*float(record.get("swing_sign",1.0))*PI/2 if record.open else 0.0
		if record.open and is_in_group("wooden_fences"):
			remove_from_group("wooden_fences")
		elif not record.open and not is_in_group("wooden_fences"):
			add_to_group("wooden_fences")
		return
	hinge.rotation.y = -PI/2 if record.open else 0
