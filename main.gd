class_name FFTae
extends Control

@export var settings_ui: SettingsUi
@export var load_file_dialog: FileDialog
@export var save_xml_button: Button
@export var save_xml_dialog: FileDialog
@export var save_seq_button: Button
@export var save_seq_dialog: FileDialog

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

static var start_sizes: Dictionary = {
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
	


func _on_save_xml_dialog_file_selected(path: String) -> void:
	var xml_header: String = '<?xml version="1.0" encoding="utf-8" ?>\n\t<Patches>\n\t\t'
	var xml_name: String = '<Patch name="' + settings_ui.patch_name + '">'
	var xml_author: String = '<Author>' + settings_ui.patch_description + '</Author>'
	var xml_description: String = '<Description>' + settings_ui.patch_description + '</Description>'
	
	# TODO make for each sector?
	var xml_location_start: String = '<Location offset="%8x" file="BATTLE_BIN">' % int(settings_ui.patch_start_location.value)
	var asm: String = "FFFFFFFF"
	var xml_location_end: String = '</Location>'
	var xml_end: String = '</Patch>\n</Patches>'
	
	var xml_complete: String = ""
	
	# clean up file name
	if path.get_slice(".", -2).to_lower() == path.get_slice(".", -1).to_lower():
		path = path.trim_suffix(path.get_slice(".", -1))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var save_file := FileAccess.open(path, FileAccess.WRITE)
	save_file.store_string(xml_complete)


func _on_save_seq_dialog_file_selected(path: String) -> void:
	seq.write_seq(path)
