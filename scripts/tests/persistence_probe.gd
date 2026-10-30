extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Save = preload("res://scripts/core/save_store.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Crafting = preload("res://scripts/crafting.gd")
const ROOT: String = "user://architecture_restart_test"

func _initialize() -> void:
	Registry.initialize()
	if "--write" in OS.get_cmdline_user_args():
		var model := Data.new(817263)
		model.world_id = "restart_probe"
		model.set_block(Vector3i(5, -1, 5), "air")
		model.set_block(Vector3i(-17, 3, 2), "workbench")
		model.entities.test_actor = {"type": "monster", "position": Vector3(3, 4, 5), "state": {"health": 19}}
		var bag := Inventory.new()
		bag.add_items("wood", 11)
		var snapshot: Dictionary = {"world": model.export_state(), "player": {"position": Vector3(7, 2, 8)}, "inventory": bag.slots.duplicate(true), "crafting": {"width": 2, "slots": Crafting.new().slots.duplicate(true)}, "selected": 3}
		var result: Error = Save.save(snapshot, ROOT)
		print("Restart checkpoint written: ", error_string(result))
		quit(0 if result == OK else 1)
	else:
		var saved := Save.load_world("restart_probe", ROOT)
		var model := Data.new()
		var valid: bool = not saved.is_empty() and model.import_state(saved.world)
		valid = valid and model.kind_at(Vector3i(5, -1, 5)) == "air" and model.kind_at(Vector3i(-17, 3, 2)) == "workbench"
		valid = valid and saved.inventory[24].count == 11 and saved.selected == 3 and saved.player.position == Vector3(7, 2, 8)
		valid = valid and model.entities.test_actor.state.health == 19
		print("Restart checkpoint restored by separate process: ", valid)
		quit(0 if valid else 1)
