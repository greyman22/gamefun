extends RefCounted
const Registry = preload("res://scripts/core/registry.gd")
static func duration(tool: String, kind: String) -> float:
	Registry.initialize()
	return Registry.seconds(tool, kind)
static func gives_item(tool: String, kind: String) -> bool:
	Registry.initialize()
	return Registry.drops(tool, kind)
