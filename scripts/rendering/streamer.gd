extends Node3D
const PerfLog = preload("res://scripts/core/performance_log.gd")

const Job = preload("res://scripts/rendering/chunk_job.gd")
const Atlas = preload("res://scripts/rendering/atlas.gd")
const Generator = preload("res://scripts/core/generator.gd")
const BaseCache = preload("res://scripts/rendering/base_cache.gd")
var base_cache = BaseCache.new()
var model: RefCounted
var material: Material
var chunks: Dictionary = {}
var desired: Dictionary = {}
var tasks: Dictionary = {}
var view_distance: int = 96
var collision_distance: int = 32
var max_tasks: int = 2
var elapsed: float = 1
var shutting_down: bool = false
var last_position := Vector3.ZERO
var desired_anchor:=Vector3(INF,INF,INF)
var desired_distance: int=-1
var desired_dirty: bool=true
var view_forward:=Vector3.FORWARD
var scheduling_order: Array=[]
var maintenance: Array=[]
var maintenance_index: int=0
var work_budget_usec: int=2000
var max_installs_per_frame: int=1
var last_installs: int=0
var last_maintenance: int=0

func configure(data: RefCounted) -> void:
	model = data
	material = Atlas.material()
	model.block_changed.connect(changed)

func changed(_cell: Vector3i) -> void:
	elapsed = 1
	desired_dirty=true

func build_now(key: Vector3i) -> void:
	var job := Job.new(model.seed_value, key, model.worker_edits(key), base_cache, model.worker_chest_pairs(key),model.generator.version)
	job.run()
	apply(key, job.result, int(model.revisions.get(key, 0)), true)

func warm_start(position: Vector3) -> void:
	last_position = position
	var center: Vector3i = model.key(Vector3i(position.floor()))
	for x in range(-1, 2):
		for z in range(-1, 2):
			for y in range(-1, 2):
				build_now(center + Vector3i(x, y, z))
	refresh_desired(position)

func refresh_desired(position: Vector3) -> void:
	last_position = position
	desired_anchor=position
	desired_distance=view_distance
	desired_dirty=false
	desired.clear()
	var center: Vector3i = model.key(Vector3i(position.floor()))
	var radius: int = ceili(float(view_distance) / 16)
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.z - radius, center.z + radius + 1):
			var distance: float = Vector2(x * 16 + 8 - position.x, z * 16 + 8 - position.z).length()
			if distance > view_distance + 16 or x * 16 < -model.generator.world_limit() or x * 16 >= model.generator.world_limit() or z * 16 < -model.generator.world_limit() or z * 16 >= model.generator.world_limit():
				continue
			var surface: int = floori(float(model.generator.height(x * 16 + 8, z * 16 + 8)) / 16)
			var levels: Dictionary = {surface: true, surface - 1: true, surface + 1: true}
			if model.generator.version>=4:
				# Include intervening vertical sections on steep faces, not just
				# the summit and the player's level. The distance budget is unchanged.
				var low_surface: int=surface
				var high_surface: int=surface
				for offset in [Vector2i(-8,-8),Vector2i(8,-8),Vector2i(-8,8),Vector2i(8,8)]:
					var corner: int=floori(float(model.generator.height(x*16+8+offset.x,z*16+8+offset.y))/16)
					low_surface=mini(low_surface,corner)
					high_surface=maxi(high_surface,corner)
				for y in range(low_surface-1,high_surface+2):
					levels[y]=true
			if position.y < model.generator.height(int(position.x), int(position.z)) + 2 or distance < collision_distance + 16:
				for y in range(center.y - 1, center.y + 2):
					levels[y] = true
			for y: int in levels:
				if y >= floori(float(Generator.MIN_Y)/16)-1 and y <= floori(float(model.generator.max_y())/16)+1:
					var key := Vector3i(x, y, z)
					var ahead: float=Vector2(x*16+8-position.x,z*16+8-position.z).normalized().dot(Vector2(view_forward.x,view_forward.z))
					var footing: bool=distance<32 and absi(y-center.y)<=1
					desired[key] = distance + absf(y * 16 + 8 - position.y) * 0.5 - maxf(0,ahead)*12 - (64 if footing else 0)
	scheduling_order=desired.keys()
	scheduling_order.sort_custom(func(a: Vector3i,b: Vector3i) -> bool: return desired[a]<desired[b])
	# Near collisions first; remote unloads follow. Work is consumed incrementally.
	maintenance=scheduling_order.filter(func(key: Vector3i) -> bool: return chunks.has(key))
	for key: Vector3i in chunks:
		if not desired.has(key):
			maintenance.append(key)
	maintenance_index=0

func _measuredtick(position: Vector3, delta: float, forward: Vector3=Vector3.ZERO) -> void:
	if shutting_down:
		return
	last_position=position
	if forward.length_squared()>0.01:
		view_forward=forward.normalized()
	elapsed+=delta
	if elapsed>=0.4 and (desired_dirty or desired_distance!=view_distance or desired_anchor.distance_squared_to(position)>=16):
		elapsed=0
		refresh_desired(position)
	var started: int=Time.get_ticks_usec()
	last_installs=0
	last_maintenance=0
	# Tasks remain queued when the budget runs out; nothing is synchronously waited
	# on unless the worker is already finished. At most one new mesh per frame.
	var ready: Array=tasks.keys().filter(func(key: Vector3i) -> bool: return WorkerThreadPool.is_task_completed(tasks[key].id))
	ready.sort_custom(func(a: Vector3i,b: Vector3i) -> bool: return desired.get(a,INF)<desired.get(b,INF))
	for key: Vector3i in ready:
		if last_installs>=max_installs_per_frame or Time.get_ticks_usec()-started>=work_budget_usec:
			break
		var task: Dictionary=tasks[key]
		WorkerThreadPool.wait_for_task_completion(task.id)
		if desired.has(key) and task.revision==int(model.revisions.get(key,0)):
			apply(key,task.job.result,task.revision,false)
			last_installs+=1
		tasks.erase(key)
	while maintenance_index<maintenance.size() and last_maintenance<4 and Time.get_ticks_usec()-started<work_budget_usec:
		var key: Vector3i=maintenance[maintenance_index]
		maintenance_index+=1
		last_maintenance+=1
		if not chunks.has(key):
			continue
		if not desired.has(key):
			remove_chunk(key)
		else:
			update_collision(key)
	if tasks.size()>=max_tasks or Time.get_ticks_usec()-started>=work_budget_usec:
		return
	for key: Vector3i in scheduling_order:
		if tasks.has(key) or (chunks.has(key) and chunks[key].revision==int(model.revisions.get(key,0))):
			continue
		var job:=Job.new(model.seed_value,key,model.worker_edits(key),base_cache,model.worker_chest_pairs(key),model.generator.version)
		var id: int=WorkerThreadPool.add_task(job.run,false,"Voxel chunk")
		tasks[key]={"id":id,"job":job,"revision":int(model.revisions.get(key,0))}
		if tasks.size()>=max_tasks or Time.get_ticks_usec()-started>=work_budget_usec:
			break

func _measuredapply(key: Vector3i, result: Dictionary, revision: int, collision: bool) -> void:
	remove_chunk(key)
	var body := StaticBody3D.new()
	body.position = Vector3(key * 16)
	body.set_meta("build_surface", true)
	add_child(body)
	var mesh := ArrayMesh.new()
	if result.vertices > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result.arrays)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = material
		body.add_child(visual)
	chunks[key] = {"node": body, "mesh": mesh, "revision": revision, "collision": false}
	if collision:
		add_collision(key)
	else:
		update_collision(key)

func add_collision(key: Vector3i) -> void:
	var record: Dictionary = chunks[key]
	if record.collision:
		return
	if record.mesh.get_surface_count() > 0:
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(record.mesh.get_faces())
		collision.shape = shape
		record.node.add_child(collision)
	record.collision = true

func _measuredupdate_collision(key: Vector3i) -> void:
	var near: bool = Vector2(key.x * 16 + 8 - last_position.x, key.z * 16 + 8 - last_position.z).length() < collision_distance + 24 and absf(key.y * 16 + 8 - last_position.y) < 40
	if near:
		add_collision(key)
	elif chunks[key].collision:
		var collision: Node = chunks[key].node.get_node_or_null("Collision")
		if collision != null:
			collision.queue_free()
		chunks[key].collision = false

func ready_at(position: Vector3) -> bool:
	var feet: Vector3i = Vector3i(position.floor())
	for offset in [Vector3i.ZERO, Vector3i.DOWN]:
		var key: Vector3i = model.key(feet + offset)
		if not chunks.has(key) or not chunks[key].collision:
			return false
	return true

func remove_chunk(key: Vector3i) -> void:
	if chunks.has(key):
		var node: StaticBody3D = chunks[key].node
		node.collision_layer = 0
		remove_child(node)
		node.queue_free()
		chunks.erase(key)

func shutdown() -> void:
	shutting_down = true
	for task: Dictionary in tasks.values():
		WorkerThreadPool.wait_for_task_completion(task.id)
	tasks.clear()

func _exit_tree() -> void:
	shutdown()

func tick(position: Vector3, delta: float, forward: Vector3=Vector3.ZERO) -> void:
	var stamp: int=PerfLog.begin()
	_measuredtick(position, delta, forward)
	PerfLog.finish("terrain_streaming",stamp)

func apply(key: Vector3i, result: Dictionary, revision: int, collision: bool) -> void:
	var stamp: int=PerfLog.begin()
	_measuredapply(key, result, revision, collision)
	PerfLog.finish("terrain_mesh_install",stamp)

func update_collision(key: Vector3i) -> void:
	var stamp: int=PerfLog.begin()
	_measuredupdate_collision(key)
	PerfLog.finish("terrain_collision",stamp)
