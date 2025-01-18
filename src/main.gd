class_name FFTae
extends Control

static var ae: FFTae
static var rom:PackedByteArray = []

@export var ui_manager: UiManager
@export var load_rom_dialog: FileDialog
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
static var directory_start_sector: int = 56436
static var directory_data_sectors: PackedInt32Array = [56436, 56437, 56438, 56439, 56440, 56441]
const OFFSET_RECORD_DATA_START: int = 0x60
var file_records: Dictionary = {}
var sprs: Dictionary = {}
var shps: Dictionary = {}
var seqs: Dictionary = {}

# location of file size (4 bytes) in full ROM
# the 4 bytes after are also the file size, but in big-endian format
# sector location (aka LBA) of the file is the 8 bytes before this (both-endian format)
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

var seq: Seq:
	get:
		var file_name: String = ui_manager.seq_options.get_item_text(ui_manager.seq_options.selected)
		if seqs.has(file_name):
			return seqs[file_name]
		else:
			var new_seq: Seq = Seq.new()
			new_seq.set_name(file_name)
			new_seq.set_data_from_seq_bytes(file_records[file_name].get_file_data(rom))
			seqs[file_name] = new_seq
			return seqs[file_name]

var shp: Shp:
	get:
		var file_name: String = ui_manager.shp_options.get_item_text(ui_manager.shp_options.selected)
		if shps.has(file_name):
			return shps[file_name]
		else:
			var new_shp: Shp = Shp.new()
			new_shp.set_name(file_name)
			new_shp.set_data_from_shp_bytes(file_records[file_name].get_file_data(rom))
			shps[file_name] = new_shp
			return shps[file_name]

var spr: Spr:
	get:
		var file_name: String = ui_manager.sprite_options.get_item_text(ui_manager.sprite_options.selected)
		if sprs.has(file_name):
			return sprs[file_name]
		else:
			var new_spr: Spr = Spr.new()
			new_spr.set_data(file_records[file_name].get_file_data(rom))
			sprs[file_name] = new_spr
			return sprs[file_name]

func _ready() -> void:
	ae = self
	bytes_per_sector = data_bytes_per_sector + bytes_per_sector_header + bytes_per_sector_footer
	for key: String in seq_metadata_size_offsets.keys():
		var sector: int = seq_metadata_size_offsets[key] / bytes_per_sector
		var sector_delta: int = sector - directory_start_sector
		var sector_split_bytes: int = sector_delta * (bytes_per_sector_header + bytes_per_sector_footer)
		seq_metadata_size_offsets[key] = seq_metadata_size_offsets[key] - (directory_start_sector * bytes_per_sector) - sector_split_bytes - bytes_per_sector_header
	
	for key: String in shp_metadata_size_offsets.keys():
		var sector: int = shp_metadata_size_offsets[key] / bytes_per_sector
		var sector_delta: int = sector - directory_start_sector
		var sector_split_bytes: int = sector_delta * (bytes_per_sector_header + bytes_per_sector_footer)
		shp_metadata_size_offsets[key] = shp_metadata_size_offsets[key] - (directory_start_sector * bytes_per_sector) - sector_split_bytes - bytes_per_sector_header


func _on_load_rom_pressed() -> void:
	load_rom_dialog.visible = true


func _on_load_rom_dialog_file_selected(path: String) -> void:
	rom = FileAccess.get_file_as_bytes(path)
	
	file_records.clear()
	for directory_sector: int in directory_data_sectors:
		var offset_start: int = 0
		if directory_sector == directory_data_sectors[0]:
			offset_start = OFFSET_RECORD_DATA_START
		var directory_start: int = directory_sector * bytes_per_sector
		var directory_data: PackedByteArray = rom.slice(directory_start, directory_start + data_bytes_per_sector + bytes_per_sector_header)
		
		var byte_index: int = offset_start + bytes_per_sector_header
		while byte_index < data_bytes_per_sector + bytes_per_sector_header:
			var record_length: int = directory_data.decode_u8(byte_index)
			var record_data: PackedByteArray = directory_data.slice(byte_index, byte_index + record_length)
			var record: FileRecord = FileRecord.new(record_data)
			file_records[record.name] = record
			
			byte_index += record_length
			if directory_data.decode_u8(byte_index) == 0: # end of data, rest of sector will be padded with zeros
				break
	
	for record: FileRecord in file_records.values():
		#push_warning(record.to_string())
		match record.name.get_extension():
			"SPR":
				ui_manager.sprite_options.add_item(record.name)
			"SHP":
				ui_manager.shp_options.add_item(record.name)
			"SEQ":
				ui_manager.seq_options.add_item(record.name)
			_:
				push_warning(record.name + ": File extension not recognized")
	
	save_xml_button.disabled = false
	save_seq_button.disabled = false
	
	#ui_manager._on_seq_file_options_item_selected(ui_manager.seq_options.selected)
	
	# try to load defaults
	ui_manager.option_button_select_text(ui_manager.seq_options, "TYPE1.SEQ")
	ui_manager.option_button_select_text(ui_manager.shp_options, "TYPE1.SHP")
	ui_manager.option_button_select_text(ui_manager.sprite_options, "RAMUZA.SPR")
	
	ui_manager._on_seq_file_options_item_selected(ui_manager.seq_options.selected)
	draw_assembled_frame(11)
	#ui_manager.preview_viewport.sprite_primary.texture = ImageTexture.create_from_image(spr.spritesheet)
	
	var background_image: Image = shp.create_blank_frame(Color.BLACK)
	ui_manager.preview_viewport.sprite_background.texture = ImageTexture.create_from_image(background_image)
	
	ui_manager.preview_viewport.camera_control._update_viewport_transform()


func _on_load_seq_pressed() -> void:
	load_file_dialog.visible = true


func _on_save_as_xml_pressed() -> void:
	save_xml_dialog.visible = true


func _on_save_as_seq_pressed() -> void:
	save_seq_dialog.visible = true


func _on_load_file_dialog_file_selected(path: String) -> void:
	seq = Seq.new()
	seq.set_data_from_seq_file(path)
	ui_manager.on_seq_data_loaded(seq)
	save_xml_button.disabled = false
	save_seq_button.disabled = false
	
	populate_animation_list(animation_list_container, seq)
	populate_opcode_list(opcode_list_container, ui_manager.animation_name_options.selected)


func _on_save_xml_dialog_file_selected(path: String) -> void:
	var xml_header: String = '<?xml version="1.0" encoding="utf-8" ?>\n<Patches>'
	var xml_patch_name: String = '<Patch name="' + ui_manager.patch_name + '">'
	var xml_author: String = '<Author>' + ui_manager.patch_author + '</Author>'
	var xml_description: String = '<Description>' + ui_manager.patch_description + '</Description>'
	
	var seq_file: String = ui_manager.patch_type_options.get_item_text(ui_manager.patch_type_options.selected)
	var xml_size_location_start: String = '<Location offset="%08x" ' % seq_metadata_size_offsets[seq_file]
	xml_size_location_start += ('sector="%x">' % directory_start_sector)
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
	ui_manager.current_animation_slots = seq_local.sequence_pointers.size()
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
		
		#var anim_id_label: Label = Label.new()
		#anim_id_label.text = str(pointer)
		#anim_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var anim_id_spinbox: SpinBox = SpinBox.new()
		anim_id_spinbox.max_value = seq_local.sequences.size() - 1
		anim_id_spinbox.value = pointer
		anim_id_spinbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var description_label: Label = Label.new()
		description_label.text = description
		
		var opcodes_label: Label = Label.new()
		opcodes_label.text = opcodes
		var opcodes_panel_margin: MarginContainer = MarginContainer.new()
		opcodes_panel_margin.add_child(opcodes_label)
		var opcodes_panel: PanelContainer = PanelContainer.new()
		opcodes_panel.add_child(opcodes_panel_margin)
		
		animations_grid_parent.add_child(pointer_id_label)
		animations_grid_parent.add_child(anim_id_spinbox)
		animations_grid_parent.add_child(description_label)
		animations_grid_parent.add_child(opcodes_panel)
		
		# update text for new animation pointed at
		anim_id_spinbox.value_changed.connect(
			func(new_value: int) -> void: 
				seq_local.sequence_pointers[index] = new_value
				var new_sequence: Sequence = seq_local.sequences[new_value]
				description_label.text = new_sequence.seq_name
				opcodes_label.text = new_sequence.to_string_hex("\n")
				)


func populate_opcode_list(opcode_grid_parent: GridContainer, seq_id: int) -> void:
	clear_grid_container(opcode_grid_parent, 1) # keep header row
	
	for seq_part_index: int in FFTae.ae.seq.sequences[seq_id].seq_parts.size():
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
		opcode_options.seq_part = FFTae.ae.seq.sequences[seq_id].seq_parts[seq_part_index]
		opcode_grid_parent.add_child(opcode_options)
		for opcode_options_index: int in opcode_options.item_count:
			if opcode_options.get_item_text(opcode_options_index) == FFTae.ae.seq.sequences[seq_id].seq_parts[seq_part_index].opcode_name:
				opcode_options.select(opcode_options_index)
				opcode_options.item_selected.emit(opcode_options_index)
				break
		
		for param_index: int in FFTae.ae.seq.sequences[seq_id].seq_parts[seq_part_index].parameters.size():
			opcode_options.param_spinboxes[param_index].value = FFTae.ae.seq.sequences[seq_id].seq_parts[seq_part_index].parameters[param_index]


func draw_assembled_frame(frame_index: int) -> void:
	var animation_id: int = 0 # TODO how is this used?
	var submerged_depth: int = 0 # TODO make ui setting
	var assembled_image: Image = shp.get_assembled_frame(frame_index, spr.spritesheet, animation_id)
	ui_manager.preview_viewport.sprite_primary.texture = ImageTexture.create_from_image(assembled_image)
	var image_rotation: float = shp.get_frame(frame_index, submerged_depth).y_rotation
	(ui_manager.preview_viewport.sprite_primary.get_parent() as Node2D).rotation_degrees = image_rotation


func _on_animation_option_button_item_selected(index: int) -> void:
	var sequence: Sequence = seq.sequences[index]
	ui_manager.row_spinbox.max_value = sequence.seq_parts.size() - 1
	populate_opcode_list(opcode_list_container, index)


func _on_insert_opcode_pressed() -> void:
	var seq_part_id: int = ui_manager.row_spinbox.value
	var seq_id: int = ui_manager.animation_name_options.selected
	
	#var previous_length: int = seq.sequences[seq_id].length
	# set up seq_part
	var new_seq_part: SeqPart = SeqPart.new()
	new_seq_part.parameters.resize(2)
	new_seq_part.parameters.fill(0)
	
	seq.sequences[ui_manager.animation_name_options.selected].seq_parts.insert(seq_part_id, new_seq_part)
	ui_manager.current_bytes = seq.toal_length
	_on_animation_option_button_item_selected(seq_id)


func _on_delete_opcode_pressed() -> void:
	var seq_part_id: int = ui_manager.row_spinbox.value
	var seq_id: int = ui_manager.animation_name_options.selected
	#var previous_length: int = seq.sequences[seq_id].length
	
	seq.sequences[ui_manager.animation_name_options.selected].seq_parts.remove_at(seq_part_id)
	ui_manager.current_bytes = seq.toal_length
	_on_animation_option_button_item_selected(seq_id)


func _on_new_animation_pressed() -> void:
	# create new sequence with initial opcode LoadFrameAndWait(0,0)
	var new_seq: Sequence = Sequence.new()
	new_seq.seq_name = "New Animation"
	var initial_seq_part: SeqPart = SeqPart.new()
	initial_seq_part.parameters.append(0)
	initial_seq_part.parameters.append(0)
	new_seq.seq_parts.append(initial_seq_part)
	seq.sequences.append(new_seq)
	
	seq.sequence_pointers.append(seq.sequences.size() - 1) # add pointer to the new sequence
	populate_animation_list(animation_list_container, seq)
	
	ui_manager.animation_id_spinbox.max_value = seq.sequences.size() - 1
	ui_manager.animation_id_spinbox.value = seq.sequences.size() - 1


func _on_delete_animation_pressed() -> void:
	seq.sequences.remove_at(ui_manager.animation_id_spinbox.value)
	ui_manager.animation_id_spinbox.max_value = seq.sequences.size() - 1
	for pointer_index: int in seq.sequence_pointers.size():
		if seq.sequence_pointers[pointer_index] >= ui_manager.animation_id_spinbox.max_value:
			seq.sequence_pointers[pointer_index] = 0
	populate_animation_list(animation_list_container, seq)
	ui_manager.update_animation_description_options(seq)
	populate_opcode_list(opcode_list_container, ui_manager.animation_id_spinbox.value)


func _on_add_pointer_pressed() -> void:
	seq.sequence_pointers.append(0)
	ui_manager.pointer_index_spinbox.max_value = seq.sequence_pointers.size() - 1
	populate_animation_list(animation_list_container, seq)


func _on_delete_pointer_pressed() -> void:
	seq.sequence_pointers.remove_at(ui_manager.pointer_index_spinbox.value)
	ui_manager.pointer_index_spinbox.max_value = seq.sequence_pointers.size() - 1
	populate_animation_list(animation_list_container, seq)


func _on_shp_file_options_item_selected(_index: int) -> void:
	draw_assembled_frame(6)


func _on_sprite_options_item_selected(_index: int) -> void:
	draw_assembled_frame(6)
