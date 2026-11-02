extends Node
# Keep only this shortcut listener running while the scene tree is frozen.
var active: bool=false
var previous_pause: bool=false
var previous_mouse_mode: int=Input.MOUSE_MODE_CAPTURED
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not event.alt_pressed and (event.physical_keycode==KEY_F4 or event.keycode==KEY_F4):
		toggle()
		get_viewport().set_input_as_handled()
func toggle() -> void:
	if active:
		get_tree().paused=previous_pause
		Input.mouse_mode=previous_mouse_mode
		active=false
	else:
		previous_pause=get_tree().paused
		previous_mouse_mode=Input.mouse_mode
		active=true
		get_tree().paused=true
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _exit_tree() -> void:
	if active:
		get_tree().paused=previous_pause
