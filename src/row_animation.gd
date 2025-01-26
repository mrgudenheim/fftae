extends MarginContainer

@export var pointer_label: Label
@export var anim_id_spinbox: SpinBox
@export var description_label: Label
@export var opcodes_label: Label


@export var pointer_id: int:
	set(value):
		pointer_label.text = "%s (0x%02x)" % [value, value]

@export var anim_id: int:
	get:
		return anim_id_spinbox.value
	set(value):
		anim_id_spinbox.value = value
		anim_id_spinbox.value_changed.emit(value)

@export var description: String:
	get:
		return description_label.text
	set(text):
		description_label.text = text

@export var opcodes_text: String:
	#get:
		#return opcodes_text
	set(text):
		opcodes_label.text = text
