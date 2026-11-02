extends "res://scripts/core/storage_cursor.gd"
const Furnaces=preload("res://scripts/core/furnaces.gd")
func accepts(index: int, kind: String) -> bool:
	if index<36:
		return true
	if index==36:
		return not Furnaces.recipe(kind).is_empty()
	if index==37:
		return Furnaces.fuel_seconds(kind)>0
	return false
func storage_order() -> Array[int]:
	return [36,37]
func move_into(origin: Dictionary, order: Array[int]) -> void:
	var allowed: Array[int]=[]
	for index in order:
		if accepts(index,origin.kind):
			allowed.append(index)
	super.move_into(origin,allowed)
func press(index: int, button: int, shift: bool=false) -> void:
	if held.count>0 and not accepts(index,held.kind):
		return
	super.press(index,button,shift)
func touch(index: int) -> void:
	if index>=0 and (held.count==0 or accepts(index,held.kind)):
		super.touch(index)
func distribution_plan(indices: Array[int], allow_swap: bool) -> Dictionary:
	var allowed: Array[int]=[]
	for index in indices:
		if accepts(index,held.kind):
			allowed.append(index)
	return super.distribution_plan(allowed,allow_swap)
