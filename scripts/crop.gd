extends Node3D
const Farming = preload("res://scripts/core/farming.gd")
var model: RefCounted
var record: Dictionary
var shown: int = -1
var ready_shown: bool = false
func configure(data: RefCounted, value: Dictionary) -> void:
	model=data
	record=value
func _ready() -> void:
	refresh()
func refresh() -> void:
	var growth: int = Farming.stage(record,model.game_time)
	var ripe: bool = Farming.ripe(record,model.game_time)
	if growth==shown and ripe==ready_shown:
		return
	shown=growth
	ready_shown=ripe
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var surface := StandardMaterial3D.new()
	surface.albedo_color=Color("dbb54e") if ripe else Color("538931")
	surface.roughness=1
	var height: float = [0.15,0.35,0.6,0.85][growth]
	for i in range(5):
		var x: float = float(i%3-1)*0.16
		var z: float = float(i/3)*0.2-0.1
		part(Vector3(x,height*0.5,z),Vector3(0.025,height,0.025),surface)
		for side in [-1,1]:
			var leaf = part(Vector3(x+side*0.06,height*0.5,z),Vector3(0.14,0.035,0.04),surface)
			leaf.rotation.z=side*0.45
		if growth>=2:
			part(Vector3(x,height+0.04,z),Vector3(0.075,0.2 if ripe else 0.12,0.065),surface)
func part(point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=size
	mesh.mesh=box
	mesh.material_override=material
	mesh.position=point
	add_child(mesh)
	return mesh
