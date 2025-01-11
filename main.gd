class_name FFTae
extends Control

@export var settings_ui: SettingsUi
@export var load_file_dialog: FileDialog
@export var save_xml_button: Button
@export var save_xml_dialog: FileDialog
@export var save_seq_button: Button
@export var save_seq_dialog: FileDialog

@export var animation_list_container: GridContainer
@export var opcode_list_container: GridContainer

# https://en.wikipedia.org/wiki/CD-ROM#CD-ROM_XA_extension
static var bytes_per_sector: int = 0 # 2352 bytes
static var bytes_per_sector_header: int = 24
static var bytes_per_sector_footer: int = 280
static var data_bytes_per_sector: int = 2048  # 2048 bytes


# (sector location * bytes_per_sector) + bytes_per_sector_header
# https://ffhacktics.com/wiki/BATTLE/
static var start_locations: Dictionary = {
	"arute": 57062, # 57212, 
	"cyoko": 57053, # 57203, 
	"eff1": 57080, # 57230, 
	"eff2": 57081, # 57231, 
	"kanzen": 57064, # 57214, 
	"mon": 57055, # 57205, 
	"other": 57058, # 57208, 
	"ruka": 57060, # 57210, 
	"type1": 57037, # 57187, 
	"type2": 57041, # 57191, 
	"type3": 57045, # 57195, 
	"type4": 57049, # 57199, 
	"wep1": 57072, # 57222, 
	"wep2": 57074, # 57244, 
	}

static var original_sizes: Dictionary = {
	"arute": 2476,
	"cyoko": 3068,
	"eff1": 1244,
	"eff2": 1244,
	"kanzen": 2068,
	"mon": 5882,
	"other": 2414,
	"ruka": 2482,
	"type1": 6754,
	"type2": 6545,
	"type3": 6820,
	"type4": 6634,
	"wep1": 2607,
	"wep2": 2607,
	}

var seq: Seq = Seq.new()

func _ready() -> void:
	bytes_per_sector = data_bytes_per_sector + bytes_per_sector_header + bytes_per_sector_footer
	for key: String in start_locations.keys():
		start_locations[key] = (start_locations[key] * bytes_per_sector) + bytes_per_sector_header
	
	settings_ui.patch_type_options.clear()
	settings_ui.patch_type_options.add_item("custom")
	
	for key: String in start_locations.keys():
		settings_ui.patch_type_options.add_item(key)


func _on_load_seq_pressed() -> void:
	load_file_dialog.visible = true


func _on_save_as_xml_pressed() -> void:
	save_xml_dialog.visible = true


func _on_save_as_seq_pressed() -> void:
	save_seq_dialog.visible = true


func _on_load_file_dialog_file_selected(path: String) -> void:
	seq = Seq.new()
	seq.set_data_from_seq_file(path)
	settings_ui.on_seq_data_loaded(seq)
	save_xml_button.disabled = false
	save_seq_button.disabled = false
	
	populate_animation_list(animation_list_container, seq)
	
	var sequence: Sequence = seq.sequences[settings_ui.animation_name_options.selected]
	populate_opcode_list(opcode_list_container, sequence)


func _on_save_xml_dialog_file_selected(path: String) -> void:
	var xml_header: String = '<?xml version="1.0" encoding="utf-8" ?>\n<Patches>'
	var xml_patch_name: String = '<Patch name="' + settings_ui.patch_name + '">'
	var xml_author: String = '<Author>' + settings_ui.patch_author + '</Author>'
	var xml_description: String = '<Description>' + settings_ui.patch_description + '</Description>'
	
	# TODO make for each sector?
	var xml_location_start: String = '<Location offset="%08x" file="BATTLE_BIN">' % int(settings_ui.patch_start_location.value)
	var bytes: String = "FFFFFFFF"
	var xml_location_end: String = '</Location>'
	var xml_end: String = '</Patch>\n</Patches>'
	
	var xml_parts: PackedStringArray = [
		xml_header,
		xml_patch_name,
		xml_author,
		xml_description,
		xml_location_start,
		bytes,
		xml_location_end,
		xml_end
	]
	
	var xml_complete: String = "\n".join(xml_parts)
	
	# clean up file name
	if path.get_slice(".", -2).to_lower() == path.get_slice(".", -1).to_lower():
		path = path.trim_suffix(path.get_slice(".", -1))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var save_file := FileAccess.open(path, FileAccess.WRITE)
	save_file.store_string(xml_complete)


func _on_save_seq_dialog_file_selected(path: String) -> void:
	seq.write_seq(path)


func clear_grid_container(grid: GridContainer, rows_to_keep: int) -> void:
	var children_to_keep: int = rows_to_keep * grid.columns
	for child_index: int in grid.get_child_count():
		if child_index >= children_to_keep:
			grid.get_child(child_index).queue_free()


func populate_animation_list(animations_grid_parent: GridContainer, seq_local: Seq) -> void:
	clear_grid_container(animations_grid_parent, 1)
	
	for index in seq_local.sequences.size():
		var sequence: Sequence = seq_local.sequences[index]
		var is_hex: String = " (0x%02x)" % index
		var id: String = str(index) + is_hex
		var description: String = sequence.seq_name
		var opcodes: String = sequence.to_string_hex("\n")
		
		var id_label: Label = Label.new()
		id_label.text = id
		id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var description_label: Label = Label.new()
		description_label.text = description
		var opcodes_label: Label = Label.new()
		opcodes_label.text = opcodes
		
		animations_grid_parent.add_child(id_label)
		animations_grid_parent.add_child(description_label)
		animations_grid_parent.add_child(opcodes_label)


func populate_opcode_list(opcode_grid_parent: GridContainer, sequence: Sequence) -> void:
	clear_grid_container(opcode_grid_parent, 1)
	
	for seq_part_index: int in sequence.seq_parts.size():
		var seq_part: SeqPart = sequence.seq_parts[seq_part_index]
	
		var id_label: Label = Label.new()
		id_label.text = str(seq_part_index)
		id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opcode_grid_parent.add_child(id_label)
		
		var opcode_options: OptionButton = OptionButton.new()
		opcode_options.add_item("LoadFrameAndWait")
		for opcode_name in Seq.opcode_parameters_by_name.keys():
			opcode_options.add_item(opcode_name)
		for opcode_options_index: int in opcode_options.item_count:
			if opcode_options.get_item_text(opcode_options_index) == seq_part.opcode_name:
				opcode_options.select(opcode_options_index)
				#_on_patch_type_item_selected(opcode_options.selected)
				break
		opcode_grid_parent.add_child(opcode_options)
		
		for param_index: int in range(3):
			if param_index < seq_part.parameters.size():
				var param_spinbox: SpinBox = SpinBox.new()
				param_spinbox.max_value = 255
				param_spinbox.min_value = -128
				param_spinbox.value = seq_part.parameters[param_index]
				opcode_grid_parent.add_child(param_spinbox)
			else:
				var empty: Label = Label.new()
				opcode_grid_parent.add_child(empty)


func _on_animation_option_button_item_selected(index: int) -> void:
	var sequence: Sequence = seq.sequences[settings_ui.animation_name_options.selected]
	populate_opcode_list(opcode_list_container, sequence)
