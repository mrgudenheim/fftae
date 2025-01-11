class_name InfoUi
extends VBoxContainer

@export var animations_slots_text: Label
@export var bytes_animations_slots_text: Label
@export var patch_start_input: SpinBox

var current_animation_slots: int = 0:
	get:
		return current_animation_slots
	set(value):
		current_animation_slots = value
		update_info_text(current_animation_slots, max_animation_slots, animations_slots_text)
var max_animation_slots: int = 0:
	get:
		return max_animation_slots
	set(value):
		max_animation_slots = value
		update_info_text(current_animation_slots, max_animation_slots, animations_slots_text)

var current_bytes: int = 0:
	get:
		return max_bytes
	set(value):
		max_bytes = value
		update_info_text(current_bytes, max_bytes, bytes_animations_slots_text)
var max_bytes: int = 0:
	get:
		return max_bytes
	set(value):
		max_bytes = value
		update_info_text(current_bytes, max_bytes, bytes_animations_slots_text)


func update_info_text(current: int, max: int, ui: Label) -> void:
	ui.text = str(current) + "/" + str(max) + "(%.f%)" % [100 * current/float(max)]
	
	if current > max:
		ui.label_settings.font_color = Color.DARK_RED
