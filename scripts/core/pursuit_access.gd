extends RefCounted
const Navigation = preload("res://scripts/core/zombie_navigation.gd")
var model: RefCounted
var cache: Dictionary = {}
func configure(data: RefCounted) -> void:
	model = data
	cache.clear()
	model.block_changed.connect(invalidate)
func invalidate(_cell: Vector3i) -> void:
	cache.clear()
func allowed(from: Vector3, target: Vector3) -> bool:
	var start := Vector3i(target.floor())
	var finish := Vector3i(from.floor())
	var key := "%s:%s"%[start,finish]
	if cache.has(key) and float(cache[key].until)>model.game_time:
		return cache[key].allowed
	var nav := Navigation.new()
	nav.model = model
	# A jumping/falling player is not declared sheltered just for being airborne.
	var grounded: bool = false
	for down in range(4):
		if nav.clear_at(start+Vector3i.DOWN*down):
			start += Vector3i.DOWN*down
			grounded = true
			break
	var can_follow: bool = true
	if grounded:
		nav.path(Vector3(start)+Vector3(0.5,0,0.5),Vector3(finish)+Vector3(0.5,0,0.5))
		# Only a fully explored sealed component proves protection. Fences deliberately
		# preserve attraction, and a search-budget limit never grants false immunity.
		can_follow = nav.reached or nav.fence_seen or nav.incomplete
	if cache.size()>256:
		cache.clear()
	cache[key]={"allowed":can_follow,"until":model.game_time+0.6}
	return can_follow
