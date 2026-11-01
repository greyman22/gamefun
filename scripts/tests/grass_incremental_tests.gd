extends SceneTree
const Data = preload("res://scripts/core/world_data.gd")
const Farm = preload("res://scripts/core/farming.gd")
const Field = preload("res://scripts/rendering/grass_field.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var data := Data.new()
	var field := Field.new()
	root.add_child(field)
	field.configure(data)
	var key := Vector2i.ZERO
	field.build(key)
	var node: MultiMeshInstance3D = field.patches[key]
	var buffer: MultiMesh = node.multimesh
	var original: Dictionary = {}
	for cell in field.patch_cells[key]:
		original[cell]=buffer.get_instance_transform(field.patch_indices[key][cell])
	expect(original.size()>2,"Test patch contains grass")
	var harvested: Vector3i = field.patch_cells[key][1]
	var count: int = buffer.visible_instance_count
	Farm.harvest(data,{"wild":true,"cell":harvested})
	field.invalidate(harvested)
	expect(field.patches[key]==node and node.multimesh==buffer and not node.is_queued_for_deletion(),"Harvest retains patch node and GPU buffer immediately")
	expect(buffer.visible_instance_count==count-1 and not field.patch_indices[key].has(harvested),"Exactly one tuft removed immediately")
	for cell in original:
		if cell==harvested:
			continue
		expect(buffer.get_instance_transform(field.patch_indices[key][cell]).is_equal_approx(original[cell]),"Every other tuft keeps its world transform")
	await process_frame
	field.tick(Vector3(8,0,8),0.3)
	expect(field.patches[key]==node and node.multimesh==buffer,"Next stream tick does not rebuild harvested patch")
	var covered: Vector3i = field.patch_cells[key][0]
	data.set_block(covered,"stone")
	expect(buffer.visible_instance_count==count-2,"Block change removes only affected grass column")
	data.set_block(covered,"air")
	expect(buffer.visible_instance_count==count-1 and field.patch_indices[key].has(covered),"Removing cover restores only affected grass using spare capacity")
	var remaining: Array = field.patch_cells[key].duplicate()
	for cell in remaining:
		Farm.remove_wild(data,cell)
		field.invalidate(cell)
	expect(buffer.visible_instance_count==0 and field.patches[key]==node,"Removing final tuft leaves stable empty patch")
	field.invalidate(harvested)
	expect(buffer.visible_instance_count==0,"Repeated update is harmless")
	data.landmarks.grass_removed.erase(data.text_key(harvested))
	field.invalidate(harvested)
	expect(buffer.visible_instance_count==1 and field.patch_indices[key].has(harvested),"Empty patch accepts local addition without reconstruction")
	field.queue_free()
	await process_frame
	print("INCREMENTAL GRASS TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
