class_name FileRecord

# http://wiki.osdev.org/ISO_9660#Directories
const OFFSET_RECORD_LENGTH: int = 0
const OFFSET_SECTOR_LOCATION: int = 2 # 8 bytes both-endian
const OFFSET_SIZE: int = 10 # 8 bytes both-endian
const OFFSET_FLAGS: int = 25
const OFFSET_NAME_LENGTH: int = 32 # in num characters, includes the ending characters ';1', so actual file name length is 2 shorter
const OFFSET_NAME: int = 33

var record_length: int = 0
var sector_location: int = 0
var size: int = 0
var flags: int = 0
var name_length: int = 0 # in num characters, includes the ending characters ';1', so actual file name length is 2 shorter
var name: String = ""

func _init(record: PackedByteArray) -> void:
	record_length = record.decode_u8(OFFSET_RECORD_LENGTH)
	sector_location = record.decode_u32(OFFSET_SECTOR_LOCATION)
	size = record.decode_u32(OFFSET_SIZE)
	flags = record.decode_u8(OFFSET_FLAGS)
	name_length = record.decode_u8(OFFSET_NAME_LENGTH)
	name = record.slice(OFFSET_NAME, OFFSET_NAME + name_length - 2).get_string_from_ascii()

func _to_string() -> String:
	return name + ": " + str(sector_location) + "," + str(size)
