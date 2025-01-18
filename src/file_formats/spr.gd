class_name Spr extends Bmp
var spritesheet: Image

func _init() -> void:
	file_name = "spr_file"
	if file_name == "OTHER":
		num_colors = 512
	bits_per_pixel = 4
	palette_data_start = 0
	pixel_data_start = num_colors * 2 # after 256 color palette, 2 bytes per color - 1 bit for alpha, followed by 5 bits per channel (B,G,R)
	width = 256 # pixels
	height = 256 # need to set based on file?
	num_pixels = width * height


func set_data(spr_file: PackedByteArray) -> void:
	set_palette_data(spr_file)
	set_color_indices(spr_file)
	set_pixel_colors()
	spritesheet = get_rgba8_image()


func set_palette_data(spr_file: PackedByteArray) -> void:
	color_palette.resize(num_colors)
	for i: int in num_colors:
		var color: Color = Color.BLACK
		var color_bits: int = spr_file.decode_u16(palette_data_start + (i*2))
		color.a8 = 1 - ((color_bits & 0b1000_0000_0000_0000) >> 15) # first bit is alpha (if bit is zero, color is opaque)
		color.b8 = (color_bits & 0b0111_1100_0000_0000) >> 10 # then 5 bits each: blue, green, red
		color.g8 = (color_bits & 0b0000_0011_1110_0000) >> 5
		color.r8 = color_bits & 0b0000_0000_0001_1111
		
		# convert 5 bit channels to 8 bit
		color.a8 = 255 * color.a8 # first bit is alpha (if bit is zero, color is opaque)
		color.b8 = roundi(255 * (color.b8 / float(31))) # then 5 bits each: blue, green, red
		color.g8 = roundi(255 * (color.g8 / float(31)))
		color.r8 = roundi(255 * (color.r8 / float(31)))
		
		# if first color in 16 color palette is black, treat it as transparent
		if (i % 8 == 0
			and color == Color.BLACK):
				color.a8 = 0
		color_palette[i] = color


func set_color_indices(spr_file: PackedByteArray) -> void:
	color_indices.resize(num_pixels)
	for i: int in num_pixels:
		var pixel_offset: int = (i * bits_per_pixel)/8
		var byte: int = spr_file.decode_u8(pixel_data_start + pixel_offset)
		
		if i % 2 == 1: # get 4 leftmost bits
			color_indices[i] = byte >> 4
		else:
			color_indices[i] = byte & 0b0000_1111 # get 4 rightmost bits


func set_pixel_colors(palette_id: int = 0) -> void:
	pixel_colors.resize(num_pixels)
	for i: int in color_indices.size():
		pixel_colors[i] = color_palette[color_indices[i] + (16 * palette_id)]


func get_rgba8_image() -> Image:
	var image:Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	
	for x in width:
		for y in height:
			var color:Color = pixel_colors[x + (y * width)]
			var color8:Color = Color8(color.r8, color.g8, color.b8, color.a8) # use Color8 function to prevent issues with format conversion changing color by 1/255
			image.set_pixel(x,y, color8) # spr stores pixel data left to right, top to bottm
	
	return image
