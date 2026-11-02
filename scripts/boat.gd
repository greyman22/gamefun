extends Node3D
const Visuals=preload("res://scripts/item_visuals.gd")
var record: Dictionary
var visual: Node3D
var phase: float=0
var moving: bool=false
func configure(value: Dictionary) -> void:
	record=value
	rotation.y=float(record.get("state",{}).get("yaw",0))
func _ready() -> void:
	visual=Visuals.boat_model(self)
	var area:=Area3D.new()
	area.collision_layer=32
	area.collision_mask=0
	area.set_meta("boat_id",get_meta("entity_id"))
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(1,0.7,2)
	shape.shape=box
	shape.position.y=0.2
	area.add_child(shape)
	add_child(area)
func _process(delta: float) -> void:
	phase+=delta*(6 if moving else 1)
	visual.position.y=sin(phase)*0.018
	for i in range(2):
		var oar: Node3D=visual.get_node("Oar%d"%i)
		oar.rotation.y=sin(phase)*0.6 if moving else 0
		oar.rotation.z=(-1 if i==0 else 1)*(0.15+cos(phase)*0.15 if moving else 0.15)
func serialize_state() -> Dictionary:
	return {"yaw":rotation.y,"hits":int(record.get("state",{}).get("hits",0))}
