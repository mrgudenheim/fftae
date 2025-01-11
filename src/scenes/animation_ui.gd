class_name AnimationUi
extends GridContainer

@export var id: LineEdit
@export var description: LineEdit
@export var opcodes_container: GridContainer

func set_id_description(new_id: int, new_description: String) -> void:
	id.text = str(new_id)
	description.text = new_description
