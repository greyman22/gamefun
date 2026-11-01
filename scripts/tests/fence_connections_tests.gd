extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Fence = preload("res://scripts/fence.gd")
const Visuals = preload("res://scripts/item_visuals.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func meshes(node: Node) -> Array:
	return node.get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D)
func run() -> void:
	Registry.initialize()
	var data := Data.new()
	var cell := Vector3i(3,35,3)
	data.set_block(cell,"fence")
	var fence := Fence.new()
	fence.configure(data,{"cell":cell})
	root.add_child(fence)
	expect(meshes(fence).size()==1,"Isolated fence must be only a post")
	data.set_block(cell+Vector3i.RIGHT,"fence")
	fence.refresh()
	expect(meshes(fence).size()==3,"One neighbour gets two half-rails")
	for mesh in meshes(fence):
		if mesh.position.y != 0.5:
			expect(mesh.position.x==0.25 and mesh.mesh.size.x==0.5,"Rails only extend toward right neighbour")
	data.set_block(cell+Vector3i.FORWARD,"gate")
	fence.refresh()
	expect(meshes(fence).size()==5,"Corner connects independently to gate")
	data.set_block(cell+Vector3i.RIGHT,"air")
	data.set_block(cell+Vector3i.FORWARD,"air")
	fence.refresh()
	expect(meshes(fence).size()==1,"Removing receivers removes their rails")
	var icon: Image = Visuals.icon("fence").get_image()
	var min_x: int = 96
	var max_x: int = -1
	for y in range(96):
		for x in range(96):
			if icon.get_pixel(x,y).a>0.1:
				min_x=mini(min_x,x)
				max_x=maxi(max_x,x)
	expect(max_x-min_x<60,"Fence icon must be narrower")
	fence.queue_free()
	await process_frame
	print("FENCE CONNECTION TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
