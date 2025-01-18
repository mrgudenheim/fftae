class_name FrameData

var num_subframes:int = 0
var y_rotation:float = 0
var transparency_type:int = 0
var transparency_flag:bool = false
var byte2_3:int = 0
var byte2_4:int = 0
var subframes: Array[SubFrameData] = []

var length:int = 0:
	get:
		return 2 + (4 * subframes.size()) # bytes

func get_subframes_string() -> String:
	var subframe_strings: PackedStringArray = []
	for subframe: SubFrameData in subframes:
		subframe_strings.append(subframe.to_string())
	
	return "\n".join(subframe_strings)
