extends RefCounted
const Navigation = preload("res://scripts/core/zombie_navigation.gd")
const Perf=preload("res://scripts/core/performance_log.gd")
var budget: RefCounted
var model: RefCounted
var cache: Dictionary = {}
var searches: Dictionary={}
var sealed: Dictionary={}
func configure(data: RefCounted) -> void:
	model = data
	cache.clear()
	searches.clear()
	model.block_changed.connect(invalidate)
func invalidate(_cell: Vector3i) -> void:
	cache.clear()
	searches.clear()
	sealed.clear()
func allowed(from: Vector3, target: Vector3) -> bool:
	var start := Vector3i(target.floor())
	var finish := Vector3i(from.floor())
	if sealed.has(start):
		var room: Dictionary=sealed[start]
		if room.until>model.game_time:
			return room.cells.has(finish) or room.cells.has(finish+Vector3i.UP) or room.cells.has(finish+Vector3i.DOWN)
		sealed.erase(start)
	var key := "%s:%s"%[start,finish]
	if cache.has(key) and float(cache[key].until)>model.game_time:
		return cache[key].allowed
	var nav: RefCounted=searches.get(key)
	if nav==null:
		nav=Navigation.new()
		if searches.size()>=128:
			searches.clear()
		searches[key]=nav
	nav.model = model
	nav.budget=budget
	nav.work_key="access:"+key
	nav.priority=25
	# A jumping/falling player is not declared sheltered just for being airborne.
	var grounded: bool = false
	for down in range(4):
		if nav.clear_at(start+Vector3i.DOWN*down):
			start += Vector3i.DOWN*down
			grounded = true
			break
	var can_follow: bool = true
	if grounded:
		var stamp: int=Perf.begin()
		nav.path(Vector3(start)+Vector3(0.5,0,0.5),Vector3(finish)+Vector3(0.5,0,0.5))
		Perf.finish("creature_access",stamp)
		if nav.deferred:
			return bool(cache.get(key,{}).get("allowed",true))
		# Only a fully explored sealed component proves protection. Fences deliberately
		# preserve attraction, and a search-budget limit never grants false immunity.
		can_follow = nav.reached or nav.fence_seen or nav.incomplete
		if not can_follow and not nav.completed_component.is_empty():
			if sealed.size()>=32:
				sealed.clear()
			sealed[Vector3i(target.floor())]={"until":model.game_time+1.0,"cells":nav.completed_component.duplicate()}
		if nav.search_state.is_empty():
			searches.erase(key)
	if cache.size()>256:
		cache.clear()
		searches.clear()
	cache[key]={"allowed":can_follow,"until":model.game_time+(0.1 if not nav.search_state.is_empty() else 1.0)}
	return can_follow
