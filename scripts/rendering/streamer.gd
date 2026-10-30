extends Node3D

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

func configure(data: RefCounted) -> void:
	model = data
	material = Atlas.material()
	model.block_changed.connect(changed)

func changed(_cell: Vector3i) -> void:
	elapsed = 1

func build_now(key: Vector3i) -> void:
	var job := Job.new(model.seed_value, key, model.worker_edits(key), base_cache)
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
	desired.clear()
	var center: Vector3i = model.key(Vector3i(position.floor()))
	var radius: int = ceili(float(view_distance) / 16)
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.z - radius, center.z + radius + 1):
			var distance: float = Vector2(x * 16 + 8 - position.x, z * 16 + 8 - position.z).length()
			if distance > view_distance + 16 or absi(x) > 16 or absi(z) > 16:
				continue
			var surface: int = floori(float(model.generator.height(x * 16 + 8, z * 16 + 8)) / 16)
			var levels: Dictionary = {surface: true, surface - 1: true, surface + 1: true}
			if position.y < model.generator.height(int(position.x), int(position.z)) + 2 or distance < collision_distance + 16:
				for y in range(center.y - 1, center.y + 2):
					levels[y] = true
			for y: int in levels:
				if y >= -5 and y <= 4:
					var key := Vector3i(x, y, z)
					desired[key] = distance + absf(y * 16 + 8 - position.y) * 0.5
	for key: Vector3i in chunks.keys():
		if not desired.has(key):
			remove_chunk(key)
		else:
			update_collision(key)

func tick(position: Vector3, delta: float) -> void:
	if shutting_down:
		return
	elapsed += delta
	if elapsed >= 0.4:
		elapsed = 0
		refresh_desired(position)
	var applied: int = 0
	for key: Vector3i in tasks.keys():
		var task: Dictionary = tasks[key]
		if WorkerThreadPool.is_task_completed(task.id):
			WorkerThreadPool.wait_for_task_completion(task.id)
			if desired.has(key) and task.revision == int(model.revisions.get(key, 0)):
				apply(key, task.job.result, task.revision, false)
			tasks.erase(key)
			applied += 1
			if applied >= 2:
				break
	if tasks.size() >= max_tasks:
		return
	var order: Array = desired.keys()
	order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return desired[a] < desired[b])
	for key: Vector3i in order:
		if tasks.has(key) or (chunks.has(key) and chunks[key].revision == int(model.revisions.get(key, 0))):
			continue
		var job := Job.new(model.seed_value, key, model.worker_edits(key), base_cache)
		var id: int = WorkerThreadPool.add_task(job.run, false, "Voxel chunk")
		tasks[key] = {"id": id, "job": job, "revision": int(model.revisions.get(key, 0))}
		if tasks.size() >= max_tasks:
			break

func apply(key: Vector3i, result: Dictionary, revision: int, collision: bool) -> void:
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

func update_collision(key: Vector3i) -> void:
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
