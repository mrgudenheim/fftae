class_name FFTae
extends Control

static var ae: FFTae
static var rom:PackedByteArray = []
static var global_fft_animation: FftAnimation = FftAnimation.new()

@export var ui_manager: UiManager
@export var load_rom_dialog: FileDialog
@export var load_file_dialog: FileDialog
@export var save_xml_button: Button
@export var save_xml_dialog: FileDialog
@export var save_seq_button: Button
@export var save_seq_dialog: FileDialog

@export var animation_list_container: GridContainer
@export var opcode_list_container: GridContainer
@export var frame_list_container: GridContainer

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
			new_shp.set_data_from_shp_bytes(file_records[file_name].get_file_data(rom), file_name)
			shps[file_name] = new_shp
			return shps[file_name]

var spr: Spr:
	get:
		var file_name: String = ui_manager.sprite_options.get_item_text(ui_manager.sprite_options.selected)
		if sprs.has(file_name):
			return sprs[file_name]
		else:
			var new_spr: Spr = Spr.new()
			new_spr.set_data(file_records[file_name].get_file_data(rom), file_name.get_basename())
			new_spr.set_sp2s(file_records, rom)
			sprs[file_name] = new_spr
			return sprs[file_name]

func _ready() -> void:
	ae = self
	bytes_per_sector = data_bytes_per_sector + bytes_per_sector_header + bytes_per_sector_footer


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
			record.record_location_sector = directory_sector
			record.record_location_offset = byte_index
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
	
	# try to load defaults
	ui_manager.option_button_select_text(ui_manager.seq_options, "TYPE1.SEQ")
	ui_manager.option_button_select_text(ui_manager.shp_options, "TYPE1.SHP")
	ui_manager.option_button_select_text(ui_manager.sprite_options, "RAMUZA.SPR")
	
	ui_manager._on_seq_file_options_item_selected(ui_manager.seq_options.selected)
	_on_shp_file_options_item_selected(ui_manager.shp_options.selected)
	
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
	
	var file: String = seq.file_name.to_upper() + ".SEQ"
	var xml_size_location_start: String = '<Location offset="%08x" ' % (file_records[file].record_location_offset + FileRecord.OFFSET_SIZE - bytes_per_sector_header)
	xml_size_location_start += ('sector="%x">' % file_records[file].record_location_sector)
	var file_size_hex: String = '%08x' % seq.toal_length
	var file_size_hex_bytes: PackedStringArray = [
		file_size_hex.substr(0,2),
		file_size_hex.substr(2,2),
		file_size_hex.substr(4,2),
		file_size_hex.substr(6,2),
		]
	var bytes_size: String = file_size_hex_bytes[3] + file_size_hex_bytes[2] + file_size_hex_bytes[1] + file_size_hex_bytes[0] # little-endian
	bytes_size += file_size_hex_bytes[0] + file_size_hex_bytes[1] + file_size_hex_bytes[2] + file_size_hex_bytes[3] # big-endian
	var xml_size_location_end: String = '</Location>'
	
	var seq_bytes: PackedByteArray = seq.get_seq_bytes()
	var bytes: String = seq_bytes.hex_encode()
	var location_start: int = 0
	var xml_location_start: String = '<Location offset="%08x" ' % location_start
	xml_location_start += 'file="BATTLE_' + seq.file_name.to_upper() + '_SEQ">'
	var xml_location_end: String = '</Location>'
	
	var xml_end: String = '</Patch>\n</Patches>'
	
	var xml_parts: PackedStringArray = [
		xml_header,
		xml_patch_name,
		xml_author,
		xml_description,
		"<!-- file size (both endian) -->",
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


func populate_frame_list(frame_grid_parent: GridContainer, shp_local: Shp) -> void:
	#ui_manager.current_animation_slots = shp_local.frames.size()
	clear_grid_container(frame_grid_parent, 1)
	
	for index in shp.frame_pointers.size():
		var pointer: int = shp.frame_pointers[index]
		var frame: FrameData = shp.frames[index]
		var id_hex: String = " (0x%02x)" % index
		var id: String = str(index) + id_hex
		var y_rotation: String = str(frame.y_rotation)
		var subframe_strings: String = frame.get_subframes_string()
		
		var pointer_id_label: Label = Label.new()
		pointer_id_label.text = id
		pointer_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var rotation_label: Label = Label.new()
		rotation_label.text = str(y_rotation)
		rotation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		var subframes_label: Label = Label.new()
		subframes_label.text = subframe_strings
		subframes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var subframes_label_panel_margin: MarginContainer = MarginContainer.new()
		subframes_label_panel_margin.add_child(subframes_label)
		var subframes_panel: PanelContainer = PanelContainer.new()
		subframes_panel.add_child(subframes_label_panel_margin)
		subframes_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var frame_preview: TextureRect = TextureRect.new()
		var preview_image_size: Vector2i = Vector2i(120, 120)
		var preview_image: Image = shp.create_blank_frame(Color.BLACK, preview_image_size)
		var assembled_frame: Image = shp.get_assembled_frame(index, spr.spritesheet, 0, Vector2i(60, 60), 15)
		assembled_frame.resize(preview_image_size.x, preview_image_size.y, Image.INTERPOLATE_NEAREST)
		preview_image.blend_rect(assembled_frame, Rect2i(Vector2i.ZERO, preview_image_size), Vector2i.ZERO)
		frame_preview.texture = ImageTexture.create_from_image(preview_image)
		frame_preview.rotation_degrees = frame.y_rotation
		
		frame_grid_parent.add_child(pointer_id_label)
		frame_grid_parent.add_child(rotation_label)
		frame_grid_parent.add_child(subframes_panel)
		frame_grid_parent.add_child(frame_preview)


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
	#ui_manager.preview_viewport.sprite_primary.texture = ImageTexture.create_from_image(spr.spritesheet)
	draw_assembled_frame(11)
	frame_list_container.get_parent().get_parent().get_parent().name = shp.file_name + " Frames"
	populate_frame_list(frame_list_container, shp)
	#draw_assembled_frame(6)


func _on_sprite_options_item_selected(_index: int) -> void:
	#ui_manager.preview_viewport.sprite_primary.texture = ImageTexture.create_from_image(spr.spritesheet)
	draw_assembled_frame(11)
	populate_frame_list(frame_list_container, shp)
	#draw_assembled_frame(6)


func start_animation(fft_animation: FftAnimation, draw_target: Sprite2D, is_playing: bool, isLooping: bool, force_loop: bool = false) -> void:
	var num_parts: int = fft_animation.sequence.seq_parts.size()
	
	var only_opcodes: bool = true
	for animation_part in fft_animation.sequence.seq_parts:
		if not animation_part.isOpcode:
			only_opcodes = false
			break
	
	# don't loop when no parts, only 1 part, or all parts are opcodes
	if (num_parts == 0 or only_opcodes): # TODO only_opcodes should play instead of showing a blank image, ie. if only a loop, but need to handle broken MON MFItem animation infinite loop
		# draw a blank image
		var assembled_image: Image = fft_animation.shp.create_blank_frame()
		ui_manager.preview_viewport.sprite_primary.texture = ImageTexture.create_from_image(assembled_image)
		await get_tree().create_timer(.001).timeout # prevent infinite loop from Wait opcodes looping only opcodes
		return
	elif (num_parts == 1 and not force_loop):
		process_seq_part(fft_animation, 0, draw_target)
		return
	
	if (is_playing):
		await play_animation(fft_animation, draw_target, isLooping)
	else:
		process_seq_part(fft_animation, 0, draw_target)


func play_animation(fft_animation: FftAnimation, draw_target: Sprite2D, isLooping: bool):
	for animation_part_id:int in fft_animation.sequence.seq_parts.size():
		var seq_part:SeqPart = fft_animation.sequence.seq_parts[animation_part_id]
		# break loop animation when stopped or on selected animation changed to prevent 2 loops playing at once
		if (isLooping and (!animation_is_playing 
				or fft_animation != global_fft_animation)):
			return
		
		await process_seq_part(fft_animation, animation_part_id, draw_target)
		
		if not seq_part.isOpcode:
			var delay_frames: int = seq_part.parameters[1]  # param 1 is delay
			var delay_sec: float = delay_frames / animation_speed
			await get_tree().create_timer(delay_sec).timeout
		
	if isLooping:
		play_animation(fft_animation, draw_target, isLooping)
	else: # clear image when animation is over
		draw_target.texture = ImageTexture.create_from_image(fft_animation.shp.create_blank_frame())


func process_seq_part(fft_animation: FftAnimation, seq_part_id: int, draw_target:Node2D) -> void:
	# print_debug(str(animation) + " " + str(animation_part_id + 3))
	var seq_part:SeqPart = fft_animation.sequence.seq_parts[seq_part_id]
	
	var frame_id_label:String = ""
	if seq_part.isOpcode:
		frame_id_label = seq_part.to_string()
	else:
		frame_id_label = str(seq_part.parameters[0])
	
	#var new_anim_opcode_part_id: int = 0
	if fft_animation.primary_anim_opcode_part_id == 0:
		#primary_anim_opcode_part_id = fft_animation.sequence.seq_parts.size()
		fft_animation.primary_anim_opcode_part_id = fft_animation.sequence.seq_parts.size()
		#new_anim_opcode_part_id = fft_animation.sequence.seq_parts.size()
	
	# handle LoadFrameWait
	if not seq_part.isOpcode:
		var new_frame_id:int = seq_part.parameters[0]
		var frame_id_offset:int = get_animation_frame_offset(fft_animation.weapon_frame_offset_index, fft_animation.shp)
		new_frame_id = new_frame_id + frame_id_offset + opcode_frame_offset
		frame_id_label = str(new_frame_id)
	
		if new_frame_id >= fft_animation.shp.frames.size(): # high frame offsets (such as shuriken) can only be used with certain animations
			var assembled_image: Image = fft_animation.shp.create_blank_frame()
			draw_target.texture = ImageTexture.create_from_image(assembled_image)
		else:
			var assembled_image: Image = fft_animation.shp.get_assembled_frame(new_frame_id, fft_animation.image, global_animation_id)
			draw_target.texture = ImageTexture.create_from_image(assembled_image)
			var rotation: float = fft_animation.shp.get_frame(new_frame_id, fft_animation.submerged_depth).y_rotation
			if fft_animation.flipped_h:
				rotation = -rotation
			(draw_target.get_parent() as Node2D).rotation_degrees = rotation
	
	# only update ui for primary animation, not animations called through opcodes
	if fft_animation.is_primary_anim:
		animation_frame_slider.value = seq_part_id
		frame_id_text.text = str(frame_id_label)
	
	var position_offset: Vector2 = Vector2.ZERO
	
	# Handle opcodes
	if seq_part.isOpcode:
		#print(anim_part_start)
		if seq_part.opcode_name == "QueueSpriteAnim":
			#print("Performing " + anim_part_start) 
			if seq_part.parameters[0] == 1: # play weapon animation
				var new_animation := FftAnimation.new()
				var wep_file_name: String = Shp.shp_aliases["wep" + str(weapon_type)]
				new_animation.seq = seqs[wep_file_name]
				new_animation.shp = shps[wep_file_name]
				new_animation.sequence = new_animation.seq.sequences[seq_part.parameters[1]]
				new_animation.image = sprs["WEP.SPR"].spritesheet
				new_animation.is_primary_anim = false
				new_animation.flipped_h = fft_animation.flipped_h
				
				start_animation(new_animation, ui_manager.preview_viewport.sprite_weapon, true, false, false)
			elif seq_part.parameters[0] == 2: # play effect animation
				var new_animation := FftAnimation.new()
				var eff_file_name: String = Shp.shp_aliases["eff" + str(effect_type)]
				new_animation.seq = seqs[eff_file_name]
				new_animation.shp = shps[eff_file_name]
				new_animation.sequence = new_animation.seq.sequences[seq_part.parameters[1]]
				new_animation.image = sprs["WEP.SPR"].spritesheet
				new_animation.is_primary_anim = false
				new_animation.flipped_h = fft_animation.flipped_h
				
				start_animation(new_animation, ui_manager.preview_viewport.sprite_effect, true, false, false)
			else:
				print_debug("Error: QueueSpriteAnim: " + seq_part.to_string() + "\n" + fft_animation.sequence.to_string())
				push_warning("Error: QueueSpriteAnim: " + seq_part.to_string() + "\n" + fft_animation.sequence.to_string())
		elif seq_part.opcode_name.begins_with("Move"):
			if seq_part.opcode_name == "MoveUnitFB":
				position_offset = Vector2(-(seq_part.parameters[0]), 0) # assume facing left
			elif seq_part.opcode_name == "MoveUnitDU":
				position_offset = Vector2(0, seq_part.parameters[0])
			elif seq_part.opcode_name == "MoveUnitRL":
				position_offset = Vector2(seq_part.parameters[0], 0)
			elif seq_part.opcode_name == "MoveUnitRLDUFB":
				position_offset = Vector2((seq_part.parameters[0]) - (seq_part.parameters[2]), seq_part.parameters[1]) # assume facing left
			elif seq_part.opcode_name == "MoveUp1":
				position_offset = Vector2(0, -1)
			elif seq_part.opcode_name == "MoveUp2":
				position_offset = Vector2(0, -2)
			elif seq_part.opcode_name == "MoveDown1":
				position_offset = Vector2(0, 1)
			elif seq_part.opcode_name == "MoveDown2":
				position_offset = Vector2(0, 2)
			elif seq_part.opcode_name == "MoveBackward1":
				position_offset = Vector2(1, 0) # assume facing left
			elif seq_part.opcode_name == "MoveBackward2":
				position_offset = Vector2(2, 0) # assume facing left
			elif seq_part.opcode_name == "MoveForward1":
				position_offset = Vector2(-1, 0) # assume facing left
			elif seq_part.opcode_name == "MoveForward2":
				position_offset = Vector2(-2, 0) # assume facing left
			else:
				print_debug("can't inerpret " + seq_part.opcode_name)
				push_warning("can't inerpret " + seq_part.opcode_name)
			
			if fft_animation.flipped_h:
				position_offset = Vector2(-position_offset.x, position_offset.y)
			(draw_target.get_parent().get_parent() as Node2D).position += position_offset
		elif seq_part.opcode_name == "SetLayerPriority":
			# print(layer_priority_table)
			var layer_priority: Array = layer_priority_table[seq_part.parameters[0]]
			for i in range(0, layer_priority.size() - 1):
				var layer_name = layer_priority[i + 1] # skip set_id
				if layer_name == "unit":
					ui_manager.preview_viewport.sprite_primary.z_index = -i
				elif layer_name == "weapon":
					ui_manager.preview_viewport.sprite_weapon.z_index = -i
				elif layer_name == "effect":
					ui_manager.preview_viewport.sprite_effect.z_index = -i
				elif layer_name == "text":
					ui_manager.preview_viewport.sprite_text.z_index = -i
		elif seq_part.opcode_name == "SetFrameOffset":
			opcode_frame_offset = seq_part.parameters[0] # use global var since SetFrameOffset is only used in animations that do not call other animations
		elif seq_part.opcode_name == "FlipHorizontal":
			ui_manager.preview_viewport.sprite_primary.flip_h = !ui_manager.preview_viewport.sprite_primary.flip_h
		elif seq_part.opcode_name == "UnloadMFItem":
			var target_sprite = ui_manager.preview_viewport.sprite_item
			target_sprite.texture = fft_animation.shp.create_blank_frame()
			# reset any rotation or movement
			(target_sprite.get_parent() as Node2D).rotation_degrees = 0
			(target_sprite.get_parent() as Node2D).position = Vector2(0,0)
		elif seq_part.opcode_name == "MFItemPosFBDU":
			var target_sprite_pivot := ui_manager.preview_viewport.sprite_item.get_parent() as Node2D
			target_sprite_pivot.position = Vector2(-(seq_part.parameters[0]), (seq_part.parameters[1]) + 20) # assume facing left, add 20 because it is y position from bottom of unit
		elif seq_part.opcode_name == "LoadMFItem":
			var item_frame_id:int = item_index # assumes loading item
			var item_sheet_type:Shp = shps["item"]
			#var item_cel_image = ExtensionsApi.project.get_cel_at(ExtensionsApi.project.current_project, item_frame, item_layer)
			var item_image = sprs["ITEM"].spritesheet
			
			if item_index >= 180:
				item_sheet_type = shps["other"]
				#item_cel_image = ExtensionsApi.project.get_cel_at(ExtensionsApi.project.current_project, other_frame, other_layer)
				item_image = sprs["OTHER.SPR"].spritesheet
				
				if item_index <= 187: # load crystal
					item_frame_id = item_index - 179
					other_type_selector.select(2) # to update ui
					other_type_index = 2 # to set v_offset is correct
				elif item_index == 188: # load chest 1
					item_frame_id = 15
					other_type_selector.select(0)
					other_type_index = 0
				elif item_index == 189: # load chest 2
					item_frame_id = 16
					other_type_selector.select(0)
					other_type_index = 0
			
			frame_id_label = str(item_index)
			
			var assembled_image: Image = item_sheet_type.get_assembled_frame(item_frame_id, item_image)
			var target_sprite = ui_manager.preview_viewport.sprite_item
			target_sprite.texture = ImageTexture.create_from_image(assembled_image)
			var rotation: float = item_sheet_type.get_frame(item_frame_id, submerged_depth_options.selected).y_rotation
			(target_sprite.get_parent() as Node2D).rotation_degrees = rotation
		elif seq_part.opcode_name == "Wait":
			var loop_length: int = seq_part.parameters[0]
			var num_loops: int = seq_part.parameters[1]
			
			var primary_animation_part_id = seq_part_id + fft_animation.primary_anim_opcode_part_id - fft_animation.sequence.seq_parts.size()
			# print_debug(str(primary_animation_part_id) + "\t" + str(animation_part_id) + "\t" + str(primary_anim_opcode_part_id) + "\t" + str(animation.size() - 3))
			
			var temp_seq: Sequence = get_sub_animation(loop_length, primary_animation_part_id, fft_animation.parent_anim.sequence)
			var temp_fft_animation: FftAnimation = fft_animation.get_duplicate()
			temp_fft_animation.sequence = temp_seq
			temp_fft_animation.parent_anim = fft_animation
			temp_fft_animation.is_primary_anim = false
			temp_fft_animation.primary_anim_opcode_part_id = primary_animation_part_id
			
			for iteration in num_loops:
				await start_animation(temp_fft_animation, draw_target, true, false, true)
			
		elif seq_part.opcode_name == "IncrementLoop":
			pass # handled by animations looping by default
		elif seq_part.opcode_name == "WaitForInput":
			var delay_frames = wait_for_input_delay
			var loop_length: int = seq_part.parameters[0]
			var primary_animation_part_id = seq_part_id + fft_animation.primary_anim_opcode_part_id - fft_animation.sequence.seq_parts.size()
			var temp_seq: Sequence = get_sub_animation(loop_length, primary_animation_part_id, fft_animation.parent_anim.sequence)
			var temp_fft_animation: FftAnimation = fft_animation.get_duplicate()
			temp_fft_animation.sequence = temp_seq
			temp_fft_animation.parent_anim = fft_animation
			temp_fft_animation.is_primary_anim = false
			temp_fft_animation.primary_anim_opcode_part_id = primary_animation_part_id
			
			# print_debug(str(temp_anim))
			var timer: SceneTreeTimer = get_tree().create_timer(delay_frames / animation_speed)
			while timer.time_left > 0:
				# print(str(timer.time_left) + " " + str(temp_anim))
				await start_animation(temp_fft_animation, draw_target, true, false, true)
		elif seq_part.opcode_name.begins_with("WeaponSheatheCheck"):
			var delay_frames = weapon_sheathe_check1_delay
			if seq_part.opcode_name == "WeaponSheatheCheck2":
				delay_frames = weapon_sheathe_check2_delay
			
			var loop_length: int = seq_part.parameters[0]
			var primary_animation_part_id = seq_part_id + fft_animation.primary_anim_opcode_part_id - fft_animation.sequence.seq_parts.size()
			# print_debug(str(primary_animation_part_id) + "\t" + str(animation_part_id) + "\t" + str(primary_anim_opcode_part_id) + "\t" + str(animation.size() - 3))
			
			var temp_seq: Sequence = get_sub_animation(loop_length, primary_animation_part_id, fft_animation.parent_anim.sequence)
			var temp_fft_animation: FftAnimation = fft_animation.get_duplicate()
			temp_fft_animation.sequence = temp_seq
			temp_fft_animation.parent_anim = fft_animation
			temp_fft_animation.is_primary_anim = false
			temp_fft_animation.primary_anim_opcode_part_id = primary_animation_part_id
			
			# print_debug(str(temp_anim))
			var timer: SceneTreeTimer = get_tree().create_timer(delay_frames / animation_speed)
			while timer.time_left > 0:
				await start_animation(temp_fft_animation, draw_target, true, false, true)
		elif seq_part.opcode_name == "WaitForDistort":
			pass
		elif seq_part.opcode_name == "QueueDistortAnim":
			# https://ffhacktics.com/wiki/Animate_Unit_Distorts
			pass


func get_animation_frame_offset(weapon_frame_offset_index:int, shp:Shp) -> int:
	if ((shp.file_name.contains("wep") or shp.file_name.contains("eff"))
		and shp.zero_frames.size() > 0):
		return shp.zero_frames[weapon_frame_offset_index]
	else:
		return 0


func get_sub_animation(length:int, sub_animation_end_part_id:int, parent_animation:Sequence) -> Sequence:
	var sub_anim_length: int = 0
	var sub_anim: Sequence = Sequence.new()
	var previous_anim_part_id = sub_animation_end_part_id - 1
	
	# print_debug(str(animation) + "\n" + str(previous_anim_part_id))
	while sub_anim_length < abs(length):
		# print_debug(str(previous_anim_part_id) + "\t" + str(sub_anim_length) + "\t" + str(parent_animation[previous_anim_part_id + 3]) + "\t" + str(parent_animation[sub_animation_end_part_id + 3][0]))
		var previous_anim_part: SeqPart = parent_animation.seq_parts[previous_anim_part_id]
		sub_anim.seq_parts.insert(0, previous_anim_part)
		sub_anim_length += previous_anim_part.length
	
		previous_anim_part_id -= 1
	
	# add label, id, and num_parts
	sub_anim.seq_name = parent_animation.seq_name + ":" + str(sub_animation_end_part_id - length) + "-" + str(sub_animation_end_part_id)
	
	return sub_anim
