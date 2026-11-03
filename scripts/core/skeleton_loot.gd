extends RefCounted
const Registry=preload("res://scripts/core/registry.gd")
const Combat=preload("res://scripts/core/combat.gd")
static func roll(bow_roll: float=-1) -> Array[Dictionary]:
	var stats: Dictionary=Combat.stats("skeleton")
	var result: Array[Dictionary]=[]
	var bones: int=randi_range(int(stats.bone_min),int(stats.bone_max))
	var arrows: int=randi_range(int(stats.arrow_min),int(stats.arrow_max))
	if bones>0:
		result.append(Registry.stack("bone",bones))
	if arrows>0:
		result.append(Registry.stack("arrow",arrows))
	if (randf() if bow_roll<0 else bow_roll)<float(stats.bow_chance):
		var condition: int=randi_range(int(stats.bow_condition_min),int(stats.bow_condition_max))
		var maximum: int=Registry.durability_max("bow")
		result.append(Registry.stack("bow",1,{"durability":maxi(1,roundi(maximum*condition/100.0)),"max_durability":maximum}))
	return result
