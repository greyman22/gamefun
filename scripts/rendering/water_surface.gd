extends Node3D
const Water=preload("res://scripts/core/water.gd")
const Registry=preload("res://scripts/core/registry.gd")
var model: RefCounted
var player: Node3D
var nodes: Dictionary={}
var dirty: Dictionary={}
var material: ShaderMaterial
var natural_seen: Dictionary={}
var elapsed: float=1
var view_distance: int=96
func configure(data: RefCounted, avatar: Node3D) -> void:
	model=data
	player=avatar
	model.water_changed.connect(changed)
	model.block_changed.connect(changed)
	material=ShaderMaterial.new()
	material.shader=preload("res://scripts/rendering/water.gdshader")
func changed(cell: Vector3i) -> void:
	var offsets: Array=[Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.UP,Vector3i.DOWN]
	var near_water: bool=false
	for offset in offsets:
		near_water=near_water or Water.wet(model.kind_at(cell+offset))
	if not near_water and not nodes.has(model.key(cell)):
		return
	for offset in offsets:
		var key: Vector3i=model.key(cell+offset)
		if (near_water and model.generator.version>=3) or model.water.chunks.has(key) or nodes.has(key):
			dirty[key]=true
func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed>=0.2:
		elapsed=0
		if model.generator.version>=3:
			var center: Vector3i=model.key(Vector3i(player.position.floor()))
			var radius: int=ceili(float(view_distance)/16)
			var candidates: Array[Vector3i]=[]
			for x in range(center.x-radius,center.x+radius+1):
				for z in range(center.z-radius,center.z+radius+1):
					var key:=Vector3i(x,-1,z)
					if not natural_seen.has(key) and Vector2(x*16+8-player.position.x,z*16+8-player.position.z).length()<view_distance+16:
						candidates.append(key)
			candidates.sort_custom(func(a: Vector3i,b: Vector3i) -> bool: return Vector2(a.x*16-player.position.x,a.z*16-player.position.z).length_squared()<Vector2(b.x*16-player.position.x,b.z*16-player.position.z).length_squared())
			for i in range(mini(4,candidates.size())):
				natural_seen[candidates[i]]=true
				dirty[candidates[i]]=true
			for key in natural_seen.keys():
				if Vector2(key.x*16+8-player.position.x,key.z*16+8-player.position.z).length()>view_distance+48:
					natural_seen.erase(key)
		for key in model.water.chunks:
			if (Vector3(key*16)+Vector3.ONE*8).distance_to(player.position)<view_distance+24 and not nodes.has(key):
				dirty[key]=true
		for key in nodes.keys():
			if (Vector3(key*16)+Vector3.ONE*8).distance_to(player.position)>view_distance+40:
				nodes[key].queue_free()
				nodes.erase(key)
	var budget: int=3
	for key in dirty.keys():
		dirty.erase(key)
		if (Vector3(key*16)+Vector3.ONE*8).distance_to(player.position)<=view_distance+40:
			build(key)
		budget-=1
		if budget<=0:
			break
func quad(surface: SurfaceTool, points: Array, normal: Vector3, flow: Vector2, falling: bool, bottom: float, running: bool, center: Vector3, depth: float) -> void:
	for index in [0,1,2,0,2,3]:
		surface.set_color(Color(1 if falling else 0,1 if running else 0,depth,1))
		var direction: Vector2=flow
		if running and not falling and direction.is_zero_approx():
			# A source can discharge on several sides; interpolate outward
			# directions across its surface instead of cancelling them to zero.
			direction=Vector2(points[index].x-center.x,points[index].z-center.z).normalized()
		surface.set_uv2(direction)
		surface.set_uv(Vector2(0,1 if points[index].y>bottom+0.001 else 0))
		surface.set_normal(normal)
		surface.add_vertex(points[index])
func build(key: Vector3i) -> void:
	var cells: Dictionary=model.water.render_cells(key)
	if cells.is_empty():
		if nodes.has(key):
			nodes[key].queue_free()
			nodes.erase(key)
		return
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: int=0
	for cell in cells:
		var local:=Vector3(cell-key*16)
		var water_kind: String=model.kind_at(cell)
		var h: float=Water.height(water_kind)
		var falling: bool=water_kind.begins_with("water_fall")
		var appearance: Dictionary=flow_at(cell)
		var flow: Vector2=appearance.direction
		var running: bool=appearance.running
		var depth: float=clampf(float(model.generator.SEA_LEVEL-model.generator.height(cell.x,cell.z))/12,0,1) if model.generator.version>=3 else 0.0
		if not Water.wet(model.kind_at(cell+Vector3i.UP)):
			quad(surface,[local+Vector3(0,h,0),local+Vector3(1,h,0),local+Vector3(1,h,1),local+Vector3(0,h,1)],Vector3.UP,flow,falling,local.y,running,local+Vector3(0.5,0,0.5),depth)
			faces+=1
		for side in Water.SIDES:
			var next: Vector3i=cell+side
			var kind: String=model.kind_at(next)
			if Registry.cube(model.block(next)):
				continue
			var low: float=Water.height(kind)
			if low>=h:
				continue
			var a: Vector3
			var b: Vector3
			if side.x!=0:
				a=local+Vector3(1 if side.x>0 else 0,low,0)
				b=local+Vector3(1 if side.x>0 else 0,low,1)
			else:
				a=local+Vector3(0,low,1 if side.z>0 else 0)
				b=local+Vector3(1,low,1 if side.z>0 else 0)
			quad(surface,[a,b,b+Vector3.UP*(h-low),a+Vector3.UP*(h-low)],Vector3(side),flow,falling,local.y,running,local+Vector3(0.5,0,0.5),depth)
			faces+=1
		if not Water.wet(model.kind_at(cell+Vector3i.DOWN)) and not Registry.cube(model.block(cell+Vector3i.DOWN)):
			quad(surface,[local,local+Vector3(0,0,1),local+Vector3(1,0,1),local+Vector3(1,0,0)],Vector3.DOWN,flow,falling,local.y,running,local+Vector3(0.5,0,0.5),depth)
			faces+=1
	if not nodes.has(key):
		var node:=MeshInstance3D.new()
		node.position=Vector3(key*16)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		nodes[key]=node
	# Keep the old mesh displayed until its replacement is complete.
	nodes[key].mesh=surface.commit() if faces>0 else null
	nodes[key].material_override=material

func flow_at(cell: Vector3i) -> Dictionary:
	var kind: String=model.kind_at(cell)
	var h: float=Water.height(kind)
	var direction:=Vector2.ZERO
	var running: bool=kind!="water_source"
	if model.water.supported(cell):
		for side in Water.SIDES:
			var next: Vector3i=cell+side
			if not Registry.cube(model.block(next)):
				var difference: float=maxf(0,h-Water.height(model.kind_at(next)))
				if difference>0:
					running=true
					direction+=Vector2(side.x,side.z)*difference
	return {"direction":direction.normalized(),"running":running}
