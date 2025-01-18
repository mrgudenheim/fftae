class_name UiManager
extends Node

@export var seq_options: OptionButton
@export var animations_pointers_text: Label
@export var animations_bytes_text: Label
@export var shp_options: OptionButton
@export var sprite_options: OptionButton

@export var patch_name_edit: LineEdit
@export var author_name_edit: LineEdit
@export var patch_description_edit: TextEdit

# animation editor elements
@export var animation_id_spinbox: SpinBox
@export var animation_name_options: OptionButton
@export var row_spinbox: SpinBox
@export var pointer_index_spinbox: SpinBox

@export var preview_viewport: PreviewSubViewportContainer

var patch_name: String = "default patch name":
	get:
		if not patch_name_edit.text.is_empty():
			return patch_name_edit.text
		else:
			return patch_name_edit.placeholder_text
	set(value):
		patch_name_edit.text = value
var patch_description: String = "default patch description":
	get:
		if not patch_description_edit.text.is_empty():
			return patch_description_edit.text
		else:
			return patch_description_edit.placeholder_text
	set(value):
		patch_description_edit.text = value
var patch_author: String = "default author name":
	get:
		if not author_name_edit.text.is_empty():
			return author_name_edit.text
		else:
			return author_name_edit.placeholder_text
	set(value):
		author_name_edit.text = value

var current_animation_slots: int = 0:
	get:
		return current_animation_slots
	set(value):
		current_animation_slots = value
		update_info_text(current_animation_slots, max_animation_slots, animations_pointers_text)
var max_animation_slots: int = 0:
	get:
		return max_animation_slots
	set(value):
		max_animation_slots = value
		update_info_text(current_animation_slots, max_animation_slots, animations_pointers_text)

var current_bytes: int = 0:
	get:
		return current_bytes
	set(value):
		current_bytes = value
		update_info_text(current_bytes, max_bytes, animations_bytes_text)
var max_bytes: int = 0:
	get:
		return max_bytes
	set(value):
		max_bytes = value
		update_info_text(current_bytes, max_bytes, animations_bytes_text)


func _ready() -> void:
	animation_id_spinbox.value_changed.connect(animation_name_options.select)
	animation_id_spinbox.value_changed.connect(animation_name_options.item_selected.emit)
	animation_name_options.item_selected.connect(animation_id_spinbox.set_value_no_signal)


func update_info_text(current: int, max_value: int, ui: Label) -> void:
	var percent_of_max:String = " (%.f%%)" % [100 * current/float(max_value)]
	ui.text = str(current) + "/" + str(max_value) + percent_of_max
	
	var type: String = seq_options.get_item_text(seq_options.selected)
	if current > max_value:
		ui.label_settings.font_color = Color.DARK_RED
	elif FFTae.ae.file_records.has(type):
		if current == FFTae.ae.file_records[type].size:
			ui.label_settings.font_color = Color.WEB_GREEN
		else:
			ui.label_settings.font_color = Color.WHITE
	else:
		ui.label_settings.font_color = Color.WHITE


func update_animation_description_options(seq: Seq) -> void:
	animation_name_options.clear()
	if seq.sequences.size() == 0:
		animation_name_options.select(-1)
		animation_name_options.disabled = true
	else:
		for index in seq.sequences.size():
			var sequence: Sequence = seq.sequences[index]
			animation_name_options.add_item(str(index) + " " + sequence.seq_name)
		animation_name_options.select(animation_id_spinbox.value)
		animation_name_options.disabled = false


func _on_seq_file_options_item_selected(index: int) -> void:
	var type: String = seq_options.get_item_text(index)
	#FFTae.ae.seq = FFTae.ae.seqs[type]
	
	if FFTae.ae.file_records.has(type):
		max_bytes = ceil(FFTae.ae.file_records[type].size / float(FFTae.data_bytes_per_sector)) * FFTae.data_bytes_per_sector as int
	
	patch_description_edit.placeholder_text = type + ".seq edited with FFT Animation Editor"
	patch_name_edit.placeholder_text = type + "_animation_edit"
	
	current_animation_slots = FFTae.ae.seq.sequence_pointers.size()
	max_animation_slots = FFTae.ae.seq.section2_length / 4
	current_bytes = FFTae.ae.seq.toal_length
	
	animation_id_spinbox.max_value = FFTae.ae.seq.sequences.size() - 1
	animation_id_spinbox.editable = true
	
	pointer_index_spinbox.max_value = FFTae.ae.seq.sequence_pointers.size() - 1
	
	update_animation_description_options(FFTae.ae.seq)
	
	FFTae.ae.populate_animation_list(FFTae.ae.animation_list_container, FFTae.ae.seq)
	FFTae.ae.populate_opcode_list(FFTae.ae.opcode_list_container, animation_name_options.selected)


func get_options_button_selected_text(option_button: OptionButton) -> String:
	return option_button.get_item_text(option_button.selected)

func option_button_select_text(option_button: OptionButton, text: String) -> void:
	var found_text: bool = false
	for index: int in option_button.item_count:
		if option_button.get_item_text(index) == text:
			found_text = true
			option_button.select(index)
			break
	
	if not found_text:
		push_warning(option_button.name + "does not have item with text: " + text) 
