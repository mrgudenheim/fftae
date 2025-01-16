class_name FFTae
extends Control

static var ae: FFTae

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
static var metadata_start_sector: int = 56436

# location in full ROM
var seq_metadata_size_offsets: Dictionary = {
	"arute": 0x07e96dd0, 
	"cyoko": 0x07e97100, 
	"eff1": 0x07e976c0, 
	"eff2": 0x07e97734, 
	"kanzen": 0x07e9819e, 
	"mon": 0x07e98748, 
	"other": 0x07e98a80, 
	"ruka": 0x07e98d06, 
	"type1": 0x07e9937c, 
	"type2": 0x07e993f0, 
	"type3": 0x07e99464, 
	"type4": 0x07e9949e, 
	"wep1": 0x07e997d2,  
	"wep2": 0x07e99846,  
	}

var shp_metadata_size_offsets: Dictionary = {
	"arute": 0x07e96e0a, 
	"cyoko": 0x07e9713a, 
	"eff1": 0x07e976fa, 
	"eff2": 0x07e9776e, 
	"kanzen": 0x07e981da, 
	"mon": 0x07e98780, 
	"other": 0x07e98aba, 
	"type1": 0x07e993b6, 
	"type2": 0x07e9942a, 
	"wep1": 0x07e9980c, 
	"wep2": 0x07e99880, 
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

static var seq: Seq = Seq.new()

func _ready() -> void:
	ae = self
	bytes_per_sector = data_bytes_per_sector + bytes_per_sector_header + bytes_per_sector_footer
	for key: String in seq_metadata_size_offsets.keys():
		var sector: int = seq_metadata_size_offsets[key] / bytes_per_sector
		var sector_delta: int = sector - metadata_start_sector
		var sector_split_bytes: int = sector_delta * (bytes_per_sector_header + bytes_per_sector_footer)
		seq_metadata_size_offsets[key] = seq_metadata_size_offsets[key] - (metadata_start_sector * bytes_per_sector) - sector_split_bytes - bytes_per_sector_header
	
	for key: String in shp_metadata_size_offsets.keys():
		var sector: int = shp_metadata_size_offsets[key] / bytes_per_sector
		var sector_delta: int = sector - metadata_start_sector
		var sector_split_bytes: int = sector_delta * (bytes_per_sector_header + bytes_per_sector_footer)
		shp_metadata_size_offsets[key] = shp_metadata_size_offsets[key] - (metadata_start_sector * bytes_per_sector) - sector_split_bytes - bytes_per_sector_header
	
	settings_ui.patch_type_options.clear()
	settings_ui.patch_type_options.add_item("custom")
	
	for key: String in seq_metadata_size_offsets.keys():
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
	populate_opcode_list(opcode_list_container, settings_ui.animation_name_options.selected)


func _on_save_xml_dialog_file_selected(path: String) -> void:
	var xml_header: String = '<?xml version="1.0" encoding="utf-8" ?>\n<Patches>'
	var xml_patch_name: String = '<Patch name="' + settings_ui.patch_name + '">'
	var xml_author: String = '<Author>' + settings_ui.patch_author + '</Author>'
	var xml_description: String = '<Description>' + settings_ui.patch_description + '</Description>'
	
	var seq_file: String = settings_ui.patch_type_options.get_item_text(settings_ui.patch_type_options.selected)
	var xml_size_location_start: String = '<Location offset="%08x" ' % seq_metadata_size_offsets[seq_file]
	xml_size_location_start += ('sector="%x">' % metadata_start_sector)
	var bytes_size: String = '%04x' % seq.toal_length
	bytes_size = bytes_size.right(2) + bytes_size.left(2)
	var xml_size_location_end: String = '</Location>'
	
	var seq_bytes: PackedByteArray = seq.get_seq_bytes()
	var bytes: String = seq_bytes.hex_encode()
	var location_start: int = 0
	var xml_location_start: String = '<Location offset="%08x" ' % location_start
	xml_location_start += 'file="BATTLE_' + seq_file.to_upper() + '_SEQ">'
	var xml_location_end: String = '</Location>'
	
	var xml_end: String = '</Patch>\n</Patches>'
	
	var xml_parts: PackedStringArray = [
		xml_header,
		xml_patch_name,
		xml_author,
		xml_description,
		"<!-- file size -->",
		xml_size_location_start,
		bytes_size,
		xml_size_location_end,
		"<!-- seq data -->",
		xml_location_start,
		bytes,
		xml_location_end,
		xml_end,
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
	var initial_children: int = grid.get_child_count()
	for child_index: int in initial_children:
		var reverse_child_index: int = initial_children - 1 - child_index
		if reverse_child_index >= children_to_keep:
			var child: Node = grid.get_child(reverse_child_index)
			grid.remove_child(child)
			child.queue_free()
		else:
			break


func populate_animation_list(animations_grid_parent: GridContainer, seq_local: Seq) -> void:
	clear_grid_container(animations_grid_parent, 1)
	
	for index in seq_local.sequence_pointers.size():
		var pointer: int = seq_local.sequence_pointers[index]
		var sequence: Sequence = seq_local.sequences[pointer]
		var is_hex: String = " (0x%02x)" % index
		var id: String = str(index) + is_hex
		var description: String = sequence.seq_name
		var opcodes: String = sequence.to_string_hex("\n")
		
		var pointer_id_label: Label = Label.new()
		pointer_id_label.text = id
		pointer_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var anim_id_label: Label = Label.new()
		anim_id_label.text = str(pointer)
		anim_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var description_label: Label = Label.new()
		description_label.text = description
		
		var opcodes_label: Label = Label.new()
		opcodes_label.text = opcodes
		var opcodes_panel_margin: MarginContainer = MarginContainer.new()
		opcodes_panel_margin.add_child(opcodes_label)
		var opcodes_panel: PanelContainer = PanelContainer.new()
		opcodes_panel.add_child(opcodes_panel_margin)
		
		
		animations_grid_parent.add_child(pointer_id_label)
		animations_grid_parent.add_child(anim_id_label)
		animations_grid_parent.add_child(description_label)
		animations_grid_parent.add_child(opcodes_panel)


func populate_opcode_list(opcode_grid_parent: GridContainer, seq_id: int) -> void:
	clear_grid_container(opcode_grid_parent, 1) # keep header row
	
	var seq_temp: Seq = FFTae.seq
	for seq_part_index: int in FFTae.seq.sequences[seq_id].seq_parts.size():
		var id_label: Label = Label.new()
		id_label.text = str(seq_part_index)
		id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opcode_grid_parent.add_child(id_label)
		
		var opcode_options: OpcodeOptionButton = OpcodeOptionButton.new()
		opcode_options.add_item("LoadFrameAndWait")
		for opcode_name: String in Seq.opcode_parameters_by_name.keys():
			opcode_options.add_item(opcode_name)
		
		opcode_options.seq_id = seq_id
		opcode_options.seq_part_id = seq_part_index
		opcode_options.seq_part = FFTae.seq.sequences[seq_id].seq_parts[seq_part_index]
		opcode_grid_parent.add_child(opcode_options)
		for opcode_options_index: int in opcode_options.item_count:
			if opcode_options.get_item_text(opcode_options_index) == FFTae.seq.sequences[seq_id].seq_parts[seq_part_index].opcode_name:
				opcode_options.select(opcode_options_index)
				opcode_options.item_selected.emit(opcode_options_index)
				break
		
		var seq_temp2: Seq = FFTae.seq
		for param_index: int in FFTae.seq.sequences[seq_id].seq_parts[seq_part_index].parameters.size():
			opcode_options.param_spinboxes[param_index].value = FFTae.seq.sequences[seq_id].seq_parts[seq_part_index].parameters[param_index]


func _on_animation_option_button_item_selected(index: int) -> void:
	var sequence: Sequence = seq.sequences[index]
	settings_ui.row_spinbox.max_value = sequence.seq_parts.size() - 1
	populate_opcode_list(opcode_list_container, index)


func _on_insert_opcode_pressed() -> void:
	var seq_part_id: int = settings_ui.row_spinbox.value
	var seq_id: int = settings_ui.animation_name_options.selected
	
	var previous_length: int = seq.sequences[seq_id].length
	# set up seq_part
	var new_seq_part: SeqPart = SeqPart.new()
	new_seq_part.parameters.resize(2)
	new_seq_part.parameters.fill(0)
	
	seq.sequences[settings_ui.animation_name_options.selected].seq_parts.insert(seq_part_id, new_seq_part)
	settings_ui.current_bytes = seq.toal_length
	_on_animation_option_button_item_selected(seq_id)


func _on_delete_opcode_pressed() -> void:
	var seq_part_id: int = settings_ui.row_spinbox.value
	var seq_id: int = settings_ui.animation_name_options.selected
	var previous_length: int = seq.sequences[seq_id].length
	
	seq.sequences[settings_ui.animation_name_options.selected].seq_parts.remove_at(seq_part_id)
	settings_ui.current_bytes = seq.toal_length
	_on_animation_option_button_item_selected(seq_id)


func _on_new_animation_pressed() -> void:
	# create new sequence with initial opcode LoadFrameAndWait(0,0)
	var new_seq: Sequence = Sequence.new()
	var initial_seq_part: SeqPart = SeqPart.new()
	initial_seq_part.parameters.append(0)
	initial_seq_part.parameters.append(0)
	new_seq.seq_parts.append(initial_seq_part)
	seq.sequences.append(new_seq)
	
	seq.sequence_pointers.append(seq.sequences.size() - 1) # add pointer to the new sequence
	
	settings_ui.animation_id_spinbox.max_value = seq.sequences.size() - 1
	settings_ui.animation_id_spinbox.value = seq.sequences.size() - 1


func _on_delete_animation_pressed() -> void:
	seq.sequences.remove_at(settings_ui.animation_id_spinbox.value)
	settings_ui.animation_id_spinbox.max_value = seq.sequences.size() - 1
	for pointer: int in seq.sequence_pointers:
		if pointer >= settings_ui.animation_id_spinbox.max_value:
			pointer = 0
	populate_opcode_list(opcode_list_container, settings_ui.animation_id_spinbox.value)
