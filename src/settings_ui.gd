class_name SettingsUi
extends Node

@export var patch_type_options: OptionButton
@export var patch_start_location: SpinBox
@export var animations_slots_text: Label
@export var bytes_text: Label
@export var patch_name_edit: LineEdit
@export var author_name_edit: LineEdit
@export var patch_description_edit: TextEdit

# animation editor elements
@export var animation_id_spinbox: SpinBox
@export var animation_name_options: OptionButton
@export var row_spinbox: SpinBox

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
		update_info_text(current_animation_slots, max_animation_slots, animations_slots_text)
var max_animation_slots: int = 0:
	get:
		return max_animation_slots
	set(value):
		max_animation_slots = value
		update_info_text(current_animation_slots, max_animation_slots, animations_slots_text)

var current_bytes: int = 0:
	get:
		return current_bytes
	set(value):
		current_bytes = value
		update_info_text(current_bytes, max_bytes, bytes_text)
var max_bytes: int = 0:
	get:
		return max_bytes
	set(value):
		max_bytes = value
		update_info_text(current_bytes, max_bytes, bytes_text)


func _ready() -> void:
	animation_id_spinbox.value_changed.connect(animation_name_options.select)
	animation_id_spinbox.value_changed.connect(animation_name_options.item_selected.emit)
	animation_name_options.item_selected.connect(animation_id_spinbox.set_value_no_signal)


func update_info_text(current: int, max_value: int, ui: Label) -> void:
	var percent_of_max:String = " (%.f%%)" % [100 * current/float(max_value)]
	ui.text = str(current) + "/" + str(max_value) + percent_of_max
	
	var type: String = patch_type_options.get_item_text(patch_type_options.selected)
	if current > max_value:
		ui.label_settings.font_color = Color.DARK_RED
	elif FFTae.original_sizes.has(type):
		if current == FFTae.original_sizes[type]:
			ui.label_settings.font_color = Color.WEB_GREEN
		else:
			ui.label_settings.font_color = Color.WHITE
	else:
		ui.label_settings.font_color = Color.WHITE


func on_seq_data_loaded(seq: Seq) -> void:
	for index in patch_type_options.item_count:
		if patch_type_options.get_item_text(index) == seq.file_name:
			patch_type_options.select(index)
			_on_patch_type_item_selected(patch_type_options.selected)
			break
	
	current_animation_slots = seq.sequence_pointers.size()
	max_animation_slots = seq.section2_length / 4
	current_bytes = seq.toal_length
	
	if FFTae.original_sizes.has(seq.file_name):
		max_bytes = ceil(FFTae.original_sizes[seq.file_name] / float(FFTae.data_bytes_per_sector)) * FFTae.data_bytes_per_sector as int
	
	var type: String = patch_type_options.get_item_text(patch_type_options.selected)
	patch_description_edit.placeholder_text = type + ".seq edited with FFT Animation Editor"
	patch_name_edit.placeholder_text = type + "_animation_edit"
	
	animation_id_spinbox.max_value = seq.sequences.size() - 1
	animation_id_spinbox.editable = true
	
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


func _on_patch_type_item_selected(index: int) -> void:
	var type: String = patch_type_options.get_item_text(index)
	
	if FFTae.ae.seq_metadata_size_offsets.has(type):
		patch_start_location.editable = false
		patch_start_location.value = FFTae.ae.seq_metadata_size_offsets[type]
	else:
		patch_start_location.editable = true
	
	if FFTae.original_sizes.has(type):
		max_bytes = ceil(FFTae.original_sizes[type] / float(FFTae.data_bytes_per_sector)) * FFTae.data_bytes_per_sector as int
	
	patch_description_edit.placeholder_text = type + ".seq edited with FFT Animation Editor"
	patch_name_edit.placeholder_text = type + "_animation_edit"
