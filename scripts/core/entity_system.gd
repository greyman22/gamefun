extends Node3D
const PerfLog = preload("res://scripts/core/performance_log.gd")

signal zombie_died(position: Vector3)

const Farming = preload("res://scripts/core/farming.gd")
const Boat=preload("res://scripts/boat.gd")
const Sapling=preload("res://scripts/sapling.gd")
const Crop = preload("res://scripts/crop.gd")
const GrassField = preload("res://scripts/rendering/grass_field.gd")
var grass_field: Node3D
const Access = preload("res://scripts/core/pursuit_access.gd")
const AIBudget=preload("res://scripts/core/ai_budget.gd")
var ai_budget=AIBudget.new()
const AnimalHomes=preload("res://scripts/core/animal_homes.gd")
var animal_homes=AnimalHomes.new()
var pursuit_access = Access.new()
const Fence = preload("res://scripts/fence.gd")
const Doors = preload("res://scripts/core/doors.gd")
const Door = preload("res://scripts/door.gd")
const ActorSpace = preload("res://scripts/core/actor_space.gd")
const Hens = preload("res://scripts/core/hens.gd")
const Sheep=preload("res://scripts/sheep.gd")
const SheepLogic=preload("res://scripts/core/sheep.gd")
const NightPopulation=preload("res://scripts/core/night_population.gd")
var night_population=NightPopulation.new()
var grain_lure: Variant=null
const Hen = preload("res://scripts/hen.gd")
const DROP_LIFETIME: float = 300
var game_mode: String = "play"
const Berries = preload("res://scripts/core/berries.gd")
const Cotton=preload("res://scripts/core/cotton.gd")
const CottonPlant=preload("res://scripts/cotton_plant.gd")
const BerryBush = preload("res://scripts/berry_bush.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Registry = preload("res://scripts/core/registry.gd")
const Visuals = preload("res://scripts/item_visuals.gd")
const Skeleton=preload("res://scripts/skeleton.gd")
const SkeletonLoot=preload("res://scripts/core/skeleton_loot.gd")
const ArrowFlight=preload("res://scripts/arrow_flight.gd")
const Arrows=preload("res://scripts/core/arrows.gd")
const Zombie = preload("res://scripts/zombie.gd")
const Pickup = preload("res://scripts/pickup.gd")
var seed_lure: Variant = null
var model: RefCounted
var death_respawn_delay: float = 180
var active: Dictionary = {}
var projectile_ids: Dictionary={}
var factories: Dictionary = {}
var elapsed: float = 1
var shadow_light_limit: int = 4
var torch_light_limit: int = 12

func register_actor(kind: String, scene: PackedScene) -> void:
	factories[kind] = scene

func configure(data: RefCounted, mode: String = "play") -> void:
	model = data
	projectile_ids.clear()
	for id: String in model.entities:
		if model.entities[id].type=="arrow_flight":
			projectile_ids[id]=true
	pursuit_access.configure(data)
	pursuit_access.budget=ai_budget
	model.block_changed.connect(ai_budget.invalidate)
	model.water_changed.connect(ai_budget.invalidate)
	if not model.block_changed.is_connected(refresh_fences):
		model.block_changed.connect(refresh_fences)
	if not model.foliage_fell.is_connected(fallen_foliage):
		model.foliage_fell.connect(fallen_foliage)
	if not model.block_changed.is_connected(check_door_support):
		model.block_changed.connect(check_door_support)
	grass_field = GrassField.new()
	grass_field.configure(data)
	add_child(grass_field)
	game_mode = mode
	death_respawn_delay = Combat.respawn_seconds(mode)

func tick(position: Vector3, delta: float) -> void:
	var night_stamp: int=PerfLog.begin()
	night_population.tick(self,position,delta)
	PerfLog.finish("night_monsters",night_stamp)
	elapsed += delta
	if elapsed < 0.3:
		return
	elapsed = 0
	expire_drops()
	grass_field.tick(position,0.3)
	Berries.ensure_nearby(model, position)
	Cotton.ensure_nearby(model,position,game_mode)
	Hens.ensure_nearby(model, position, game_mode)
	SheepLogic.ensure_nearby(model,position,game_mode)
	var nearby: Array = []
	for id: String in model.entities:
		var record: Dictionary = model.entities[id]
		if record.get("state", {}).get("dead", false):
			continue
		var distance: float = position.distance_to(record.position)
		var radius: float = 104.0 if record.get("night_spawn",false) else float(Registry.catalog.actors.get(record.type, {}).get("active_distance", 32))
		if distance <= radius:
			nearby.append({"id": id, "distance": distance})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	var wanted: Dictionary = {}
	var lights: int = 0
	for entry: Dictionary in nearby:
		var record: Dictionary = model.entities[entry.id]
		if record.type == "torch":
			lights += 1
		wanted[entry.id] = true
		if not active.has(entry.id):
			activate(entry.id, record)
		if record.type=="cotton_plant" and model.kind_at(record.cell+Vector3i.DOWN) not in ["dirt","farmland"]:
			var shoots: Dictionary=Cotton.harvest(model,entry.id,"")
			deactivate(entry.id)
			for kind: String in shoots:
				var drop: String=spawn_drop(kind,record.position,int(shoots[kind]))
				model.entities[drop].ground_before_pickup=true
			continue
		if record.type in ["berry_bush","cotton_plant","crop"] and active.has(entry.id):
			active[entry.id].refresh()
		if record.type == "torch" and active.has(entry.id):
			var sources: Array[Node] = active[entry.id].find_children("*", "OmniLight3D", true, false)
			for source in sources:
				source.visible = lights <= torch_light_limit
				source.shadow_enabled = false
	for id: String in active.keys():
		if not wanted.has(id):
			deactivate(id)

func activate(id: String, record: Dictionary) -> void:
	if record.type == "door" and not Registry.cube(model.block(record.cell+Vector3i.DOWN)):
		var point: Vector3 = record.position+Vector3(0,0.6,0)
		Doors.remove(self,record.cell)
		spawn_drop(record.get("kind","door"),point)
		return
	if record.type=="crop" and model.kind_at(record.cell+Vector3i.DOWN)!="farmland":
		model.entities.erase(id)
		return
	var node: Node3D
	match record.type:
		"boat":
			node=Boat.new()
			node.configure(record)
		"sapling":
			node=Sapling.new()
			node.configure(record)
		"crop":
			node = Crop.new()
			node.configure(model,record)
		"fence":
			node = Fence.new()
			node.configure(model,record)
		"door":
			node = Door.new()
			node.configure(record)
		"sheep":
			node=Sheep.new()
			node.configure(model,record)
		"hen":
			node = Hen.new()
			node.configure(model, record)
		"cotton_plant":
			node=CottonPlant.new()
			node.configure(model,record)
		"berry_bush":
			node = BerryBush.new()
			node.configure(model, record)
		"skeleton":
			node=Skeleton.new()
			node.configure(model,record)
			node.arrow_released.connect(func(point: Vector3,velocity: Vector3,attack_value: float) -> void: Arrows.spawn(self,id,point,velocity,attack_value,"enemy"))
		"arrow_flight":
			projectile_ids[id]=true
			node=ArrowFlight.new()
			node.configure(record)
		"zombie":
			node = Zombie.new()
			node.configure(model, record)
		"pickup":
			node = Pickup.new()
			node.configure(record.kind)
			if not record.get("state", {}).get("falling", false):
				var title := Label3D.new()
				title.text = Registry.label(record.kind)
				title.position.y = 0.6
				title.font_size = 36
				title.pixel_size = 0.007
				title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				node.add_child(title)
		"torch":
			node = StaticBody3D.new()
			node.collision_layer = 16
			node.set_meta("build_surface", true)
			node.set_meta("cell", record.cell)
			var normal: Vector3 = record.get("normal",Vector3.UP)
			record.position = Visuals.torch_anchor(record.cell,normal)
			node.quaternion = Visuals.torch_tilt(normal)
			Visuals.torch_model(node, 2.5)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.1, 0.6, 0.1)
			collision.shape = shape
			node.add_child(collision)
		_:
			if not factories.has(record.type):
				return
			node = factories[record.type].instantiate()
			if node.has_method("restore_state"):
				node.restore_state(record.get("state", {}))
	if record.type in ["hen","sheep","zombie","skeleton"]:
		node.navigation.budget=ai_budget
	node.position = record.position
	node.set_meta("entity_id", id)
	add_child(node)
	record.position = node.position
	active[id] = node
	if record.type in ["zombie","skeleton"] and node.health <= 0:
		mark_dead(id, death_respawn_delay)

func deactivate(id: String) -> void:
	if not active.has(id):
		return
	var node: Node3D = active[id]
	if model.entities.has(id):
		model.entities[id].position = node.position
		if node.has_method("serialize_state"):
			model.entities[id].state = node.serialize_state()
	remove_child(node)
	node.queue_free()
	active.erase(id)

func damage_actor(id: String, amount: float, respawn_delay: float, attacker: Variant = null) -> float:
	if not active.has(id) or not model.entities.has(id) or model.entities[id].type not in ["zombie", "skeleton", "hen", "sheep"]:
		return 0
	var actor: Node3D = active[id]
	var taken: float = minf(actor.health, maxf(0, amount))
	actor.receive_hit(taken)
	if attacker is Vector3 and actor.health > 0:
		actor.apply_knockback(attacker, taken)
	model.entities[id].state = actor.serialize_state()
	if actor.health <= 0:
		if model.entities[id].type in ["hen","sheep"]:
			var record: Dictionary = model.entities[id]
			var adult: bool = Hens.adult(record, model.game_time)
			var point: Vector3 = actor.position + Vector3(0, 0.4, 0)
			Hens.cancel_pair(model, record)
			deactivate(id)
			model.entities.erase(id)
			if adult:
				var drop: String=spawn_drop("raw_chicken" if record.type=="hen" else "raw_mutton",point)
				if record.type=="hen":
					var feathers: int=randi_range(0,2)
					if feathers>0:
						spawn_drop("feather",point,feathers)
				if record.type=="sheep":
					for i in range(randi_range(1,3)):
						var wool_drop: String=spawn_drop("wool",point)
						if attacker is Vector3:
							model.entities[wool_drop].needs_approach=true
							model.entities[wool_drop].collection_origin=attacker
					model.entities[drop].ready_at=model.game_time+0.8
					if attacker is Vector3:
						model.entities[drop].needs_approach=true
						model.entities[drop].collection_origin=attacker
		else:
			mark_dead(id, respawn_delay)
	return taken

func mark_dead(id: String, delay: float) -> void:
	if not model.entities.has(id) or model.entities[id].get("state", {}).get("dead", false):
		return
	deactivate(id)
	var position: Vector3 = model.entities[id].position
	model.entities[id].state.dead = true
	var night_spawn: bool=model.entities[id].get("night_spawn",false)
	if not night_spawn:
		model.entities[id].state.respawn_at = model.game_time + delay
	if model.entities[id].type=="skeleton":
		for item: Dictionary in SkeletonLoot.roll():
			var dropped: String=spawn_drop(item.kind,position+Vector3.UP*0.9,int(item.count))
			model.entities[dropped].item=item
			model.entities[dropped].ground_before_pickup=true
		model.entities.erase(id)
	else:
		var drop: String = spawn_drop("soul_remnant", position + Vector3(0, 0.95, 0))
		model.entities[drop].state.velocity_x = 0.0
		model.entities[drop].state.velocity_z = 0.0
		model.entities[drop].ready_at = model.game_time + 1.0
		if night_spawn:
			model.entities.erase(id)
		zombie_died.emit(position)

func respawn_zombies() -> void:
	if NightPopulation.cleanup(model):
		return
	for record: Dictionary in model.entities.values():
		if record.type != "zombie" or record.get("night_spawn",false) or not record.get("state", {}).get("dead", false) or model.game_time < float(record.state.respawn_at):
			continue
		var spawn: Vector3 = record.get("spawn_position", record.position)
		var surface: Variant=AnimalHomes.surface(model,floori(spawn.x),floori(spawn.z),spawn.y)
		if surface is Vector3:
			spawn=surface
		record.position = spawn
		record.state = {"wait": 0.5}
		record.erase("health_factor")
		Combat.starting_health(record,record.type)
		record.erase("cleanup_at_real")
		record.erase("cleanup_key")
		elapsed = 1

func _measuredsimulate_actors(delta: float, player: CharacterBody3D = null) -> void:
	ai_budget.begin_frame(delta,model.game_time)
	if player != null:
		for id: String in active:
			if not model.entities.has(id) or model.entities[id].type not in ["hen","sheep","zombie","skeleton"]:
				continue
			var actor: Node3D = active[id]
			var distance: float=actor.position.distance_to(player.position)
			actor.navigation.priority=20 if distance<12 else (5 if distance<28 else 0)
			actor.decision_interval=0.25 if distance<20 else 1.0
			var interested: bool = distance<=20.0
			if model.entities[id].type in ["hen","sheep"]:
				var lure: Variant=grain_lure if model.entities[id].type=="sheep" else seed_lure
				interested = lure is Vector3 and actor.position.distance_to(lure)<=10
			actor.pursuit_allowed = pursuit_access.allowed(actor.position,player.position) if interested else true
	var home_stamp: int=PerfLog.begin()
	animal_homes.tick(self)
	PerfLog.finish("animal_home_planning",home_stamp)
	Hens.tick(self, delta)
	SheepLogic.tick(self,delta)
	respawn_zombies()
	for id: String in active.keys():
		if not active.has(id) or not model.entities.has(id) or model.entities[id].type not in ["zombie","skeleton"]:
			continue
		active[id].simulate(delta, player)
		if not active.has(id):
			continue
		if active[id].health <= 0:
			mark_dead(id, death_respawn_delay)
			continue
		if player != null:
			active[id].attack(player)
		if not active.has(id):
			continue
		model.entities[id].position = active[id].position
		model.entities[id].state = active[id].serialize_state()
	var arrow_stamp: int=PerfLog.begin()
	Arrows.tick(self,delta,player)
	PerfLog.finish("arrows",arrow_stamp)
	var separation_stamp: int=PerfLog.begin()
	ActorSpace.separate(self, player)
	PerfLog.finish("creature_separation",separation_stamp)

func within_pickup_reach(position: Vector3, record: Dictionary) -> bool:
	if position.distance_to(record.position) <= 1.0:
		return true
	if not record.get("state", {}).get("grounded", false):
		return false
	# Reach the entire top of a neighbouring one-metre block, including its far corners.
	var support := Vector3i((record.position - Vector3(0, drop_radius(record)+0.001, 0)).floor())
	if not Registry.cube(model.block(support)):
		return false
	var height_above_feet: float = support.y + 1.0 - position.y
	if height_above_feet < -0.15 or height_above_feet > 1.15:
		return false
	var nearest := Vector2(clampf(position.x, support.x, support.x + 1), clampf(position.z, support.z, support.z + 1))
	return Vector2(position.x, position.z).distance_to(nearest) <= 0.42

func collect(position: Vector3, inventory: RefCounted) -> bool:
	var changed: bool = false
	for id: String in active.keys():
		if not model.entities.has(id):
			continue
		var record: Dictionary = model.entities[id]
		if record.type=="arrow_flight" and record.get("stuck",false) and record.get("team","")=="player":
			var chest: Vector3=position+Vector3(0,1,0)
			if chest.distance_to(record.position)<=1.25 and Arrows.first_wall(model,chest,record.position)==null and inventory.add_stack(Registry.stack("arrow",1)):
				Arrows.remove(self,id)
				changed=true
			continue
		if record.type == "pickup" and (record.kind in ["blueberry","wool"] or record.get("ground_before_pickup",false) or record.get("needs_approach",false)):
			if not record.get("state", {}).get("grounded", false):
				continue
			if record.get("needs_approach", false):
				var origin: Vector3 = record.collection_origin
				var moved: float = Vector2(position.x - origin.x, position.z - origin.z).length()
				if moved < 0.15 or position.distance_to(record.position) > maxf(0.2, origin.distance_to(record.position) - 0.15):
					continue
				record.needs_approach = false
		if record.type == "pickup" and model.game_time >= float(record.get("ready_at", 0)) and within_pickup_reach(position, record):
			var remaining: int = int(record.get("count", 1))
			while remaining > 0 and inventory.add_stack(Registry.stack(record.kind, 1, record.get("item", {}))):
				remaining -= 1
				changed = true
			record.count = remaining
			if remaining == 0:
				model.entities.erase(id)
				deactivate(id)
	return changed

func spawn_drop(kind: String, position: Vector3, count: int = 1) -> String:
	var id: String = "drop_%d_%d" % [Time.get_ticks_usec(), randi()]
	# A small sideways impulse carries high drops farther during their longer flight.
	var angle: float = randf() * TAU
	var speed: float = randf_range(1.0, 1.8)
	model.entities[id] = {"type": "pickup", "kind": kind, "position": position, "count": count, "ground_before_pickup": kind in ["wool","raw_mutton","feather"], "expires_at": model.game_time + DROP_LIFETIME, "ready_at": model.game_time + 0.5, "state": {"falling": true, "grounded": false, "velocity_y": 0.0, "velocity_x": cos(angle) * speed, "velocity_z": sin(angle) * speed}}
	elapsed = 1
	return id

func _measuredsimulate_drops(delta: float) -> void:
	for id: String in active:
		if not model.entities.has(id):
			continue
		var record: Dictionary = model.entities[id]
		if record.type != "pickup" or not record.get("state", {}).get("falling", false):
			continue
		if record.state.get("floating",false) and model.water.contains(record.position-Vector3.UP*0.3):
			record.state.grounded=true
			active[id].position=record.position
			continue
		var radius: float = drop_radius(record)
		var was_grounded: bool = record.state.get("grounded", false)
		record.state.grounded = false
		var position: Vector3 = record.position
		var velocity: float = maxf(-30, float(record.state.get("velocity_y", 0)) - 18 * delta)
		var sideways := Vector3(float(record.state.get("velocity_x", 0)), 0, float(record.state.get("velocity_z", 0)))
		var movement := Vector3(sideways.x, velocity, sideways.z) * delta
		var steps: int = maxi(1, ceili(movement.length() / 0.1))
		for step in range(steps):
			for axis in [0, 2]:
				var proposed: Vector3 = position
				proposed[axis] += sideways[axis] * delta / steps
				if drop_overlaps_block(proposed,radius):
					sideways[axis] = 0
				else:
					position = proposed
			var proposed_y: float = position.y + velocity * delta / steps
			var floor_top: float = -INF
			for x in [-radius+0.001, radius-0.001]:
				for z in [-radius+0.001, radius-0.001]:
					var cell := Vector3i(floori(position.x + x), floori(proposed_y - radius), floori(position.z + z))
					if Registry.cube(model.block(cell)):
						floor_top = maxf(floor_top, cell.y + 1.0 + radius)
			if floor_top > -INF:
				record.state.grounded = true
				if not was_grounded and (record.kind in ["blueberry","wool"] or record.get("ground_before_pickup",false)):
					record.ready_at = maxf(float(record.get("ready_at", 0)), model.game_time + 0.2)
				position.y = floor_top
				velocity = 0
				sideways = Vector3.ZERO
				break
			position.y = proposed_y
		record.state.velocity_x = sideways.x
		record.state.velocity_z = sideways.z
		record.position = position
		record.state.velocity_y = velocity
		active[id].position = position

func drop_overlaps_block(position: Vector3, radius: float = 0.125) -> bool:
	for x in [-radius+0.001, radius-0.001]:
		for y in [-radius+0.001, radius-0.001]:
			for z in [-radius+0.001, radius-0.001]:
				if Registry.cube(model.block(Vector3i(floori(position.x + x), floori(position.y + y), floori(position.z + z)))):
					return true
	return false

func snapshot_active() -> void:
	for id: String in active:
		if model.entities.has(id):
			model.entities[id].position = active[id].position
			if active[id].has_method("serialize_state"):
				model.entities[id].state = active[id].serialize_state()

func expire_drops() -> void:
	for id: String in model.entities.keys():
		var record: Dictionary = model.entities[id]
		if record.type == "pickup" and record.get("kind","") == "egg" and not record.has("expires_at"):
			record.expires_at = model.game_time + DROP_LIFETIME
		if record.type == "pickup" and model.game_time >= float(record.get("expires_at", INF)):
			model.entities.erase(id)
			deactivate(id)

func fallen_foliage(cell: Vector3i, kind: String) -> void:
	spawn_drop(kind,Vector3(cell)+Vector3.ONE*0.5)

func check_door_support(changed: Vector3i) -> void:
	var crop_id: String = Farming.crop_at(model,changed+Vector3i.UP)
	if not crop_id.is_empty() and model.kind_at(changed)!="farmland":
		model.entities.erase(crop_id)
		deactivate(crop_id)
	var id: String = Doors.entity_id(model,changed+Vector3i.UP)
	if not model.entities.has(id) or model.entities[id].type != "door":
		return
	var record: Dictionary = model.entities[id]
	if not Registry.cube(model.block(record.cell+Vector3i.DOWN)):
		var point: Vector3 = record.position+Vector3(0,0.6,0)
		Doors.remove(self,record.cell)
		spawn_drop(record.get("kind","door"),point)

func creature_occupies(cell: Vector3i, blocks_high: int = 1) -> bool:
	var volume := AABB(Vector3(cell),Vector3(1,blocks_high,1))
	for id: String in model.entities:
		var record: Dictionary = model.entities[id]
		if record.type in ["pickup","torch","door","fence","berry_bush","cotton_plant","crop","sapling","boat","arrow_flight"] or record.get("state",{}).get("dead",false):
			continue
		if not Registry.catalog.actors.has(record.type) and not factories.has(record.type):
			continue
		var point: Vector3 = active[id].position if active.has(id) else record.position
		var width: float = float(Registry.catalog.actors.get(record.type,{}).get("body_radius",0.34))
		var tall: float = float(Registry.catalog.actors.get(record.type,{}).get("body_height",1.8))
		if record.type in ["hen","sheep"]:
			var grown: bool = Hens.adult(record,model.game_time)
			width = 0.34 if grown else 0.18
			tall = 0.92 if grown else 0.48
			if record.type=="sheep":
				width=0.43 if grown else 0.24
				tall=1.15 if grown else 0.6
		if volume.intersects(AABB(point-Vector3(width,0,width),Vector3(width*2,tall,width*2))):
			return true
	return false

static func drop_radius(record: Dictionary) -> float:
	return 0.15625 if record.get("kind","") in ["stick","foliage","wood","dirt","stone"] else 0.125

func refresh_fences(cell: Vector3i) -> void:
	for offset in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		var id: String = "fence_"+model.text_key(cell+offset)
		if active.has(id):
			active[id].refresh()

func simulate_actors(delta: float, player: CharacterBody3D = null) -> void:
	var stamp: int=PerfLog.begin()
	_measuredsimulate_actors(delta, player)
	PerfLog.finish("creatures",stamp)

func simulate_drops(delta: float) -> void:
	var stamp: int=PerfLog.begin()
	_measuredsimulate_drops(delta)
	PerfLog.finish("dropped_items",stamp)
