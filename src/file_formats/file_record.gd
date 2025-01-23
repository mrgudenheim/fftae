class_name FileRecord

# http://wiki.osdev.org/ISO_9660#Directories
const OFFSET_RECORD_LENGTH: int = 0
const OFFSET_SECTOR_LOCATION: int = 2 # 8 bytes both-endian
const OFFSET_SIZE: int = 10 # 8 bytes both-endian
const OFFSET_FLAGS: int = 25
const OFFSET_NAME_LENGTH: int = 32 # in num characters, includes the ending characters ';1', so actual file name length is 2 shorter
const OFFSET_NAME: int = 33

var record_location_sector: int = 0
var record_location_offset: int = 0
var record_length: int = 0
var sector_location: int = 0
var size: int = 0
var flags: int = 0
var name_length: int = 0 # in num characters, includes the ending characters ';1', so actual file name length is 2 shorter
var name: String = ""


func _init(record: PackedByteArray = []) -> void:
	if record.size() == 0:
		return
	
	record_length = record.decode_u8(OFFSET_RECORD_LENGTH)
	sector_location = record.decode_u32(OFFSET_SECTOR_LOCATION)
	size = record.decode_u32(OFFSET_SIZE)
	flags = record.decode_u8(OFFSET_FLAGS)
	name_length = record.decode_u8(OFFSET_NAME_LENGTH)
	name = record.slice(OFFSET_NAME, OFFSET_NAME + name_length - 2).get_string_from_ascii()


func _to_string() -> String:
	return name + ": " + str(sector_location) + "," + str(size)


func get_file_data(rom: PackedByteArray) -> PackedByteArray:
	var file_data: PackedByteArray = []
	var file_data_start: int = (sector_location * FFTae.bytes_per_sector) + FFTae.bytes_per_sector_header
	var num_sectors_full: int = floor(size / float(FFTae.data_bytes_per_sector))
	#var extra_size_sector_bytes: int =  num_sectors_full * (FFTae.bytes_per_sector_footer + FFTae.bytes_per_sector_header)
	#var file_data_end: int = file_data_start + size + extra_size_sector_bytes
	
	for sector_index: int in num_sectors_full:
		var sector_data_start: int = file_data_start + (sector_index * FFTae.bytes_per_sector)
		var sector_data_end: int = sector_data_start + FFTae.data_bytes_per_sector
		var sector_data: PackedByteArray = rom.slice(sector_data_start, sector_data_end)
		file_data.append_array(sector_data)
	
	# add data from last sector
	var last_sector_data_start: int = file_data_start + (num_sectors_full * FFTae.bytes_per_sector)
	var last_sector_data_end: int = last_sector_data_start + (size % FFTae.data_bytes_per_sector)
	var last_sector_data: PackedByteArray = rom.slice(last_sector_data_start, last_sector_data_end)
	file_data.append_array(last_sector_data)
	
	return file_data
