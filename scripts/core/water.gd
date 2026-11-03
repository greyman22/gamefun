extends RefCounted
const Registry=preload("res://scripts/core/registry.gd")
const SIDES=[Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const LEVELS={"water_source":4,"water_flow_3":3,"water_flow_2":2,"water_flow_1":1,"water_fall_4":4,"water_fall_3":3,"water_fall_2":2,"water_fall_1":1}
const BUDGET: int=128
var model_ref: WeakRef
var model: RefCounted:
	get:
		return model_ref.get_ref() if model_ref!=null else null
var pending: Array=[]
var queued: Dictionary={}
var chunks: Dictionary={}
var elapsed: float=0
static func wet(kind: String) -> bool:
	return LEVELS.has(kind)
static func height(kind: String) -> float:
	return 1.0 if kind.begins_with("water_fall") else float(LEVELS.get(kind,0))/4.0
func configure(data: RefCounted) -> void:
	model_ref=weakref(data)
	pending=model.landmarks.get_or_add("water_queue",[])
	queued.clear()
	chunks.clear()
	for cell in pending:
		queued[cell]=true
	if not model.block_changed.is_connected(changed):
		model.block_changed.connect(changed)
	if not model.water_changed.is_connected(changed):
		model.water_changed.connect(changed)
	for key in model.edits:
		for index in model.edits[key]:
			if wet(Registry.kind(model.edits[key][index])):
				var cell: Vector3i=key*16+Vector3i(index%16,(index/16)%16,index/256)
				track(cell)
				enqueue(cell)
func track(cell: Vector3i) -> void:
	var key: Vector3i=model.key(cell)
	if wet(model.kind_at(cell)):
		if not chunks.has(key):
			chunks[key]={}
		chunks[key][cell]=true
	elif chunks.has(key):
		chunks[key].erase(cell)
		if chunks[key].is_empty():
			chunks.erase(key)
func enqueue(cell: Vector3i) -> void:
	if cell.y< -64 or cell.y>model.generator.max_y() or absi(cell.x)>=model.generator.world_limit() or absi(cell.z)>=model.generator.world_limit() or queued.has(cell):
		return
	queued[cell]=true
	pending.append(cell)
func changed(cell: Vector3i) -> void:
	track(cell)
	if chunks.is_empty() and model.generator.version<3:
		return
	var nearby: bool=wet(model.kind_at(cell))
	for offset in [Vector3i.UP,Vector3i.DOWN,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		nearby=nearby or wet(model.kind_at(cell+offset))
	if not nearby:
		return
	enqueue(cell)
	enqueue(cell+Vector3i.UP)
	enqueue(cell+Vector3i.DOWN)
	for side in SIDES:
		enqueue(cell+side)
func supported(cell: Vector3i) -> bool:
	var below: String=model.kind_at(cell+Vector3i.DOWN)
	return Registry.cube(model.block(cell+Vector3i.DOWN)) or below=="water_source" or below.begins_with("water_flow")
func desired(cell: Vector3i) -> String:
	var current: String=model.kind_at(cell)
	if current=="water_source" or (current!="air" and not wet(current)):
		return current
	# Only real sources on opposite sides create a new source. A solid floor
	# prevents source creation in mid-air waterfalls; ordinary flow cannot multiply.
	if Registry.cube(model.block(cell+Vector3i.DOWN)) or model.kind_at(cell+Vector3i.DOWN)=="water_source":
		for axis in [Vector3i.RIGHT,Vector3i.BACK]:
			if model.kind_at(cell-axis)=="water_source" and model.kind_at(cell+axis)=="water_source":
				return "water_source"
	var above: String=model.kind_at(cell+Vector3i.UP)
	if wet(above):
		return "water_fall_%d"%int(LEVELS[above])
	var level: int=0
	for side in SIDES:
		var other: Vector3i=cell+side
		var kind: String=model.kind_at(other)
		if wet(kind) and supported(other):
			level=maxi(level,int(LEVELS[kind])-1)
	return "water_flow_%d"%level if level>0 else "air"
func process_pending(budget: int=BUDGET) -> int:
	var done: int=0
	while not pending.is_empty() and done<budget:
		var cell: Vector3i=pending.pop_front()
		queued.erase(cell)
		var target: String=desired(cell)
		if target!=model.kind_at(cell):
			model.set_block(cell,target)
		done+=1
	return done
func tick(delta: float) -> void:
	elapsed+=delta
	if elapsed>=0.12:
		elapsed=0
		process_pending()
func source(cell: Vector3i) -> bool:
	if cell.y< -64 or cell.y>model.generator.max_y() or absi(cell.x)>=model.generator.world_limit() or absi(cell.z)>=model.generator.world_limit() or (model.kind_at(cell)!="air" and not wet(model.kind_at(cell))) or model.kind_at(cell)=="water_source":
		return false
	return model.set_block(cell,"water_source")
func take(cell: Vector3i) -> bool:
	return model.set_block(cell,"air") if model.kind_at(cell)=="water_source" else false
func contains(point: Vector3) -> bool:
	var cell:=Vector3i(point.floor())
	var kind: String=model.kind_at(cell)
	return wet(kind) and point.y<float(cell.y)+height(kind)
func pick(start: Vector3, finish: Vector3, sources_only: bool=false) -> Dictionary:
	var seen: Dictionary={}
	var steps: int=maxi(1,ceili(start.distance_to(finish)/0.06))
	for i in range(steps+1):
		var cell:=Vector3i(start.lerp(finish,float(i)/steps).floor())
		if seen.has(cell):
			continue
		seen[cell]=true
		var kind: String=model.kind_at(cell)
		if not wet(kind) or (sources_only and kind!="water_source"):
			continue
		var hit: Variant=AABB(Vector3(cell),Vector3(1,height(kind),1)).intersects_segment(start,finish)
		if hit!=null:
			return {"cell":cell,"point":hit}
	return {}

func render_cells(key: Vector3i) -> Dictionary:
	var result: Dictionary=chunks.get(key,{}).duplicate()
	if model.generator.version<3:
		return result
	# Only visit the generated surface and edits that can expose submerged water.
	# Interior lake volume is implicit in the generator, never indexed per block.
	var y: int=model.generator.SEA_LEVEL-1
	if model.key(Vector3i(0,y,0)).y==key.y:
		for x in range(key.x*16,key.x*16+16):
			for z in range(key.z*16,key.z*16+16):
				var cell:=Vector3i(x,y,z)
				if wet(model.kind_at(cell)):
					result[cell]=true
	for chunk_key in [key,key+Vector3i.LEFT,key+Vector3i.RIGHT,key+Vector3i.UP,key+Vector3i.DOWN,key+Vector3i.FORWARD,key+Vector3i.BACK]:
		for index in model.edits.get(chunk_key,{}):
			# Only excavated air can expose internal generated lake faces.
			# Local flowing/source edits are already in the sparse index above.
			if int(model.edits[chunk_key][index])!=0:
				continue
			var changed: Vector3i=chunk_key*16+Vector3i(index%16,(index/16)%16,index/256)
			if changed.y>=model.generator.SEA_LEVEL:
				continue
			for offset in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
				var cell: Vector3i=changed+offset
				if model.key(cell)==key and wet(model.kind_at(cell)):
					result[cell]=true
	return result
