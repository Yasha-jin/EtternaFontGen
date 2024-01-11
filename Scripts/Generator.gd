extends Node


signal set_current_step(step: int, step_name: String)
signal set_max_step(max_step: int)
signal error(error: String)


const errors: Dictionary = {
	"InvalidName": "The custom font name is invalid.",
	"FontNotFound": "The font file couldn't be found.",
	"InvalidFile": "The font format is not valid. Only .ttf and .otf are supported."
}


const valid_extensions: PackedStringArray = [
	"ttf",
	"ttc",
	"otf"
]


# 10 is probably overkill, however that should be enough to cover all the font.
# Except wingdings. Fuck wingdings.
# Maybe in the future I should reorganize the font section to be only 1 line,
# so that it should never have character inside each other. Tho that mean some
# character may be cut off, but honestly ? I blame the font maker zzzzz.
const border_fix: int = 12


var current_step: int = 0
var folder_name: String = ""
@onready var world: Control = $World


func start_render(
	font_path: String,
	font_size: int,
	doubleres: bool,
	font_name: String = "",
	fix_alpha_pixels: bool = true
	) -> void:
	if not FileAccess.file_exists(font_path):
		emit_signal("error", errors.FontNotFound)
		return
	
#	if not font_path.get_extension() in valid_extensions:
#		emit_signal("error", errors.InvalidFile)
#		return
	
	var font: FontFile = FontFile.new()
	font.load_dynamic_font(font_path)
	
	if font_name == "":
		font_name = font.get_font_name() + " " + font.get_font_style_name() + " " + str(font_size) + "px"
	else:
		font_name += " " + str(font_size) + "px"
	
	if not font_name.is_valid_filename():
		emit_signal("error", errors.InvalidName)
		return
	
	folder_name = font_name
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://") + folder_name):
		create_folder()
	
	var start_time: int = Time.get_ticks_msec()
	
	current_step = 0
	emit_signal("set_max_step", Sections.data.size() + 2)
	
	var ini_contents: PackedStringArray = []
	
	var height_finder = Label.new()
	height_finder.add_theme_font_override("font", font)
	if doubleres:
		font_size *= 2
	height_finder.add_theme_font_size_override("font_size", font_size)
	if doubleres:
		font_size /= 2
	self.add_child(height_finder)
	var true_height: int = height_finder.size.y + border_fix
	height_finder.queue_free()
	
	var top: int = true_height - (font_size + (border_fix / 2))
	var border_offset: int = border_fix / 2
	
	if doubleres:
		border_offset /= 2
		top = (true_height / 2) - font_size - border_offset
	
	ini_contents.append("[common]\n")
	ini_contents.append("Baseline=" + str(font_size + border_offset) + "\n")
	ini_contents.append("Top=" + str(top) + "\n")
	ini_contents.append("LineSpacing=" + str(font_size + border_offset) + "\n")
	ini_contents.append("DrawExtraPixelsLeft=0\n")
	ini_contents.append("DrawExtraPixelsRight=0\n")
	ini_contents.append("AdvanceExtraPixels=0\n\n")
	
	for section in Sections.data:
		current_step += 1
		emit_signal("set_current_step", current_step, 'Generating "' + section + '".')
		# use this to test a single section
		#if section != "basic-latin":
			#continue
		
		if doubleres:
			font_size *= 2
		
		var ini_section: String = "[" + section + "]\n"
		var ini_value: String = ""
		var y: int = 0
		var max_x: int = 0
		var char_num:int = 0
		
		for line in Sections.data[section]:
			ini_section += line + "="
			var x: int = 0
			for character in Sections.data[section][line]:
				ini_section += character
				
				var label = Label.new()
				label.add_theme_font_override("font", font)
				label.add_theme_font_size_override("font_size", font_size)
				label.add_theme_color_override("font_color", Color.WHITE)
				label.add_theme_color_override("font_outline_color", Color.WHITE)
				label.add_theme_constant_override("outline_size", 0)
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				world.add_child(label)
				
				label.text = character
				
				# If the value is 0, it mean the font doesn't support the character,
				# so replace it.
				if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x == 0:
					label.text = "�"
				
				# Resetting the size is necessary otherwise the character will not
				# be properly centered.
				label.reset_size()
				
				# add extra border, in case of a character touching the border,
				# otherwise etterna will do some funny rendering.
				# Some fonts however do have characters that goes over their size,
				# and will end up bugged either way. (ex: Wingdings)
				label.size.x += border_fix
				label.size.y += border_fix
				
				if label.size.x > label.size.y:
					label.size.y = label.size.x
				else:
					label.size.x = label.size.y
				
				label.scale.y = true_height / label.size.y
				label.scale.x = label.scale.y
				
				label.position = Vector2i(true_height * x, true_height * y)
				
				if doubleres:
					font_size /= 2
				ini_value += str(char_num) + "=" + str(
					floor(
						font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x * label.scale.x
						)
					) + "\n"
				if doubleres:
					font_size *= 2
					
				char_num += 1
				x += 1
			
			y += 1
			if max_x < x:
				max_x = x
			
			ini_section += "\n"
		
		ini_contents.append(ini_section + "\n")
		ini_contents.append(ini_value + "\n")
		self.size = Vector2i(max_x * true_height, y * true_height)
		
		# Wait 2 frames for the viewport to properly update
		await get_tree().process_frame
		await get_tree().process_frame
		
		if doubleres:
			font_size /= 2
		
		var filename: String = font_name + " [" + section + "] " + str(max_x) + "x" + str(y)
		
		if doubleres:
			filename += " (doubleres)"
		save_image(filename, fix_alpha_pixels)
		
		for label in world.get_children():
			label.queue_free()
	
	current_step += 1
	emit_signal("set_current_step", current_step, 'Generating .ini file.')
	
	save_file(ini_contents, font_name)
	
	current_step += 1
	emit_signal("set_current_step", current_step, "Done!")
	
	print("Generation took " + str(Time.get_ticks_msec() - start_time) + "ms.")


func create_folder() -> void:
	var dir = DirAccess.open("user://")
	dir.make_dir(folder_name)


func save_file(contents: PackedStringArray, filename: String) -> void:
	var file = FileAccess.open("user://" + folder_name + "/" + filename + ".ini", FileAccess.WRITE)
	for content in contents:
		file.store_string(content)
	file.close()


func save_image(filename: String, fix_alpha_pixels: bool) -> void:
	var img: Image = self.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	
	# Set all pixels to white, as the background being transparent make
	# alpha pixel have a black background.
	# check only against symbol due to sex icon being colored sometimes.
	if fix_alpha_pixels:
		if "symbol2" in filename:
			for y in img.get_height():
				for x in img.get_width():
					var px: Color = img.get_pixel(x, y)
					if px.r == px.g and px.r == px.b:
						img.set_pixel(x, y, Color(1,1,1,img.get_pixel(x, y).a))
		else:
			for y in img.get_height():
				for x in img.get_width():
					img.set_pixel(x, y, Color(1,1,1,img.get_pixel(x, y).a))
	
	img.save_png("user://" + folder_name + "/" + filename + ".png")
