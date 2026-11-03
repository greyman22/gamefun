extends Node3D
const Visuals=preload("res://scripts/item_visuals.gd")
func configure(record: Dictionary) -> void:
	Visuals.arrow_model(self,Visuals.PROJECTILE_ARROW_SCALE)
	update_flight(record)
func update_flight(record: Dictionary) -> void:
	position=record.position
	var direction: Vector3=record.get("direction",Vector3.FORWARD)
	if direction.length_squared()>0.001:
		quaternion=Quaternion(Vector3.FORWARD,direction.normalized())
