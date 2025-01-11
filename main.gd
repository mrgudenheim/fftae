extends Control

@export var info: InfoUi
@export var load_file_dialog: FileDialog
@export var save_file_dialog: FileDialog
@export var patch_type_options: OptionButton

# https://en.wikipedia.org/wiki/CD-ROM#CD-ROM_XA_extension
static var bytes_per_sector: int = data_bytes_per_sector + bytes_per_sector_header + bytes_per_sector_footer # 2352 bytes
static var bytes_per_sector_header: int = 24
static var bytes_per_sector_footer: int = 280
static var data_bytes_per_sector: int = 2048  # 2048 bytes

# (sector location * bytes_per_sector) + bytes_per_sector_header
# https://ffhacktics.com/wiki/BATTLE/
static var start_locations: Dictionary = {
	"arute": (57062 * bytes_per_sector) + bytes_per_sector_header, # 57212, 
	"cyoko": (57053 * bytes_per_sector) + bytes_per_sector_header, # 57203, 
	"eff1": (57080 * bytes_per_sector) + bytes_per_sector_header, # 57230, 
	"eff2": (57081 * bytes_per_sector) + bytes_per_sector_header, # 57231, 
	"kanzen": (57064 * bytes_per_sector) + bytes_per_sector_header, # 57214, 
	"mon": (57055 * bytes_per_sector) + bytes_per_sector_header, # 57205, 
	"other": (57058 * bytes_per_sector) + bytes_per_sector_header, # 57208, 
	"ruka": (57060 * bytes_per_sector) + bytes_per_sector_header, # 57210, 
	"type1": (57037 * bytes_per_sector) + bytes_per_sector_header, # 57187, 
	"type2": (57041 * bytes_per_sector) + bytes_per_sector_header, # 57191, 
	"type3": (57045 * bytes_per_sector) + bytes_per_sector_header, # 57195, 
	"type4": (57049 * bytes_per_sector) + bytes_per_sector_header, # 57199, 
	"wep1": (57072 * bytes_per_sector) + bytes_per_sector_header, # 57222, 
	"wep2": (57074 * bytes_per_sector) + bytes_per_sector_header, # 57244, 
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
var patch_name: String = "default animation patch name"
var patch_description: String = "default patch description"
var patch_author: String = "default author name (Created with FFTAnimationEditor)"

func _ready() -> void:
	patch_type_options.clear()
	
	for key: String in start_locations.keys():
		patch_type_options.add_item(key)
	
	patch_type_options.add_item("custom")


func _on_load_seq_pressed() -> void:
	load_file_dialog.visible = true


func _on_save_as_xml_pressed() -> void:
	save_file_dialog.visible = true


func _on_load_file_dialog_file_selected(path: String) -> void:
	seq = Seq.new()
	seq.set_data_from_seq_file(path)


func _on_save_file_dialog_dir_selected(dir: String) -> void:
	var xml_header: String = '<?xml version="1.0" encoding="utf-8" ?>\n\t<Patches>\n\t\t'
	var xml_name: String = '<Patch name="' + patch_name + '">'
	var xml_author: String = '<Author>' + patch_description + '</Author>'
	var xml_description: String = '<Description>' + patch_description + '</Description>'
	
	# TODO make for each sector?
	var xml_location_start: String = '<Location offset="%x" file="BATTLE_BIN">' % int(info.patch_start_input.value)
	var asm: String = "FFFFFFFF"
	var xml_location_end: String = '</Location>'
	var xml_end: String = '</Patch>\n</Patches>'


func _on_patch_type_item_selected(index: int) -> void:
	var type: String = patch_type_options.get_item_text(index)
	
	if start_locations.has(type):
		info.patch_start_input.editable = false
		info.patch_start_input.value = start_locations[type]
	else:
		info.patch_start_input.editable = true
