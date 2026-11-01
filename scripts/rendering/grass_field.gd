extends Node3D
const Farming = preload("res://scripts/core/farming.gd")
var model: RefCounted
var patches: Dictionary = {}
var patch_cells: Dictionary = {}
var patch_indices: Dictionary = {}
var mesh: ArrayMesh
var elapsed: float = 1
func configure(data: RefCounted) -> void:
	if model!=null and model.block_changed.is_connected(changed):
		model.block_changed.disconnect(changed)
	model=data
	model.block_changed.connect(changed)
	for patch in patches.values():
		patch.queue_free()
	patches.clear()
	patch_cells.clear()
	patch_indices.clear()
	mesh=grass_mesh()
func changed(cell: Vector3i) -> void:
	invalidate(cell)
func tuft_transform(cell: Vector3i) -> Transform3D:
	var angle: float = float(model.generator.hash_at(cell.x,cell.z,619)%628)/100
	return Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(Farming.wild_width(model,cell)/0.6,Farming.wild_height(model,cell)/0.6,Farming.wild_width(model,cell)/0.6)),Vector3(cell)+Vector3(0.5,0,0.5))

func invalidate(cell: Vector3i) -> void:
	# Update only this column, retaining the patch node, mesh and GPU buffer.
	var key := Vector2i(floori(float(cell.x)/16),floori(float(cell.z)/16))
	if not patches.has(key):
		return
	var target := Vector3i(cell.x,model.generator.height(cell.x,cell.z),cell.z)
	var cells: Array = patch_cells[key]
	var indices: Dictionary = patch_indices[key]
	var multimesh: MultiMesh = patches[key].multimesh
	if Farming.wild_at(model,target):
		if not indices.has(target):
			indices[target]=cells.size()
			multimesh.set_instance_transform(cells.size(),tuft_transform(target))
			cells.append(target)
	elif indices.has(target):
		var index: int = indices[target]
		var last: int = cells.size()-1
		if index!=last:
			var moved: Vector3i = cells[last]
			multimesh.set_instance_transform(index,multimesh.get_instance_transform(last))
			cells[index]=moved
			indices[moved]=index
		cells.pop_back()
		indices.erase(target)
	multimesh.visible_instance_count=cells.size()

func grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var random := RandomNumberGenerator.new()
	random.seed=842173
	# Roots fill the interior of the tuft instead of lining up as a cylinder.
	# Each narrow ribbon has its own height, curve, twist and colour gradient.
	for i in range(34):
		var root_angle: float=random.randf()*TAU
		var radius: float=sqrt(random.randf())*0.17
		var base:=Vector3(sin(root_angle)*radius,0,cos(root_angle)*radius)
		var angle: float=random.randf()*TAU
		var direction:=Vector3(sin(angle),0,cos(angle))
		var height: float=0.6 if i==0 else random.randf_range(0.32,0.59)
		var width: float=random.randf_range(0.008,0.017)
		var bend: float=random.randf_range(0.035,0.115)
		var twist: float=random.randf_range(-0.6,0.6)
		var shade: float=random.randf_range(0.86,1.1)
		var levels: Array[float]=[0.0,0.25,0.5,0.78,1.0]
		var widths: Array[float]=[0.25,0.9,0.8,0.45,0.0]
		var left: Array[Vector3]=[]
		var right: Array[Vector3]=[]
		for j in range(levels.size()):
			var t: float=levels[j]
			var centre: Vector3=base+Vector3(0,height*t,0)+direction*bend*t*t
			var across:=Vector3(cos(angle+twist*t),0,-sin(angle+twist*t))*width*widths[j]
			left.append(centre-across)
			right.append(centre+across)
		for j in range(levels.size()-1):
			var points: Array[Vector3]=[left[j],right[j],left[j+1],right[j+1]]
			var triangles: Array=[0,1,2] if j==levels.size()-2 else [0,1,2,1,3,2]
			for index in triangles:
				var t: float=levels[j if index<2 else j+1]
				var colour: Color=Color("345d2b").lerp(Color("91ac53"),t*0.8)
				surface.set_color(Color(colour.r*shade,colour.g*shade,colour.b*shade))
				surface.add_vertex(points[index])
	surface.generate_normals()
	var result: ArrayMesh=surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color=Color.WHITE
	material.vertex_color_use_as_albedo=true
	material.roughness=1
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	result.surface_set_material(0,material)
	return result
func tick(position: Vector3, delta: float) -> void:
	elapsed+=delta
	if elapsed<0.15 or model==null:
		return
	elapsed=0
	var centre := Vector2i(floori(position.x/16),floori(position.z/16))
	for key in patches.keys():
		if absi(key.x-centre.x)>2 or absi(key.y-centre.y)>2:
			patches[key].queue_free()
			patches.erase(key)
			patch_cells.erase(key)
			patch_indices.erase(key)
	var budget: int = 3
	for dx in [0,-1,1,-2,2]:
		for dz in [0,-1,1,-2,2]:
			var key := centre+Vector2i(dx,dz)
			if patches.has(key):
				continue
			build(key)
			budget-=1
			if budget==0:
				return
func build(key: Vector2i) -> void:
	if patches.has(key):
		return
	var cells: Array = []
	var indices: Dictionary = {}
	for x in range(key.x*16,key.x*16+16):
		for z in range(key.y*16,key.y*16+16):
			var cell := Vector3i(x,model.generator.height(x,z),z)
			if Farming.wild_at(model,cell):
				indices[cell]=cells.size()
				cells.append(cell)
	var node := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=mesh
	# Fixed one-slot-per-column capacity permits local additions as well as
	# swap-removal without reallocating the instance buffer.
	multimesh.instance_count=256
	multimesh.visible_instance_count=cells.size()
	multimesh.custom_aabb=AABB(Vector3(key.x*16-0.8,-64,key.y*16-0.8),Vector3(17.6,130,17.6))
	for i in range(cells.size()):
		multimesh.set_instance_transform(i,tuft_transform(cells[i]))
	node.multimesh=multimesh
	add_child(node)
	patches[key]=node
	patch_cells[key]=cells
	patch_indices[key]=indices
