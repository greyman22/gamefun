extends Node3D
const Visuals=preload("res://scripts/item_visuals.gd")
var record: Dictionary
func configure(value: Dictionary) -> void:
	record=value
func _ready() -> void:
	Visuals.sapling_model(self,3.0)
	var area:=Area3D.new()
	area.collision_layer=4
	area.collision_mask=0
	area.set_meta("build_surface",true)
	area.set_meta("cell",record.cell)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(0.6,0.7,0.6)
	shape.shape=box
	shape.position.y=0.35
	area.add_child(shape)
	add_child(area)
