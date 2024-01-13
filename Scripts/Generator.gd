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


var current_step: int = 0
var folder_name: String = ""
@onready var world: Control = $World


func start_render(
	font_path: String,
	font_size: int,
	padding_size: int,
	doubleres: bool,
	stroke: bool,
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
	var true_height: int = height_finder.size.y + padding_size
	height_finder.queue_free()
	
	if doubleres:
		font_size *= 2
	var alignments: GenAlignments = await get_alignments(font, font_size, padding_size, true_height, doubleres)
	if doubleres:
		font_size /= 2
	
	ini_contents.append("[common]\n")
	ini_contents.append("Baseline=" + str(alignments.baseline) + "\n")
	ini_contents.append("Top=" + str(alignments.top) + "\n")
	ini_contents.append("LineSpacing=" + str(alignments.baseline) + "\n")
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
				# otherwise some character will be inside other character.
				label.size.x += padding_size
				label.size.y += padding_size
				
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
		
		if stroke:
			for label: Label in world.get_children():
				label.add_theme_constant_override("outline_size", 10)
			
			# Wait 2 frames for the viewport to properly update
			await get_tree().process_frame
			await get_tree().process_frame
			
			filename = font_name + " [" + section + "-stroke] " + str(max_x) + "x" + str(y)
			
			if doubleres:
				filename += " (doubleres)"
			save_image(filename, fix_alpha_pixels)
		
		for label: Label in world.get_children():
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
	
	# Set all pixels to white, as the background being transparent make
	# alpha pixel have a black background.
	# only do it manually for symbol2 due to sex symbols.
	if fix_alpha_pixels:
		if "symbol2" in filename:
			for y in img.get_height():
				for x in img.get_width():
					var px: Color = img.get_pixel(x, y)
					if px.r == px.g and px.r == px.b:
						img.set_pixel(x, y, Color(1,1,1,img.get_pixel(x, y).a))
		else:
			img.adjust_bcs(100,1,1)
	
	img.save_png("user://" + folder_name + "/" + filename + ".png")


func get_alignments(font: FontFile, font_size: int, padding_size: int, true_height: int, doubleres: bool) -> GenAlignments:
	var alignements = GenAlignments.new()
	
	var label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world.add_child(label)
	
	label.text = "Z"
	
	label.reset_size()
	
	label.size.x += padding_size
	label.size.y += padding_size
	
	if label.size.x > label.size.y:
		label.size.y = label.size.x
	else:
		label.size.x = label.size.y
	
	label.scale.y = true_height / label.size.y
	label.scale.x = label.scale.y
	
	label.position = Vector2i(0, 0)
	
	self.size = Vector2i(true_height, true_height)
		
	# Wait 2 frames for the viewport to properly update
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img: Image = self.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a != 0:
				if y <= alignements.top:
					alignements.top = y - 1
				if alignements.baseline <= y:
					alignements.baseline = y + 1
	
	if doubleres:
		alignements.top = floor(float(alignements.top) / 2)
		alignements.baseline = ceil(float(alignements.baseline) / 2)
	
	for c in world.get_children():
		c.queue_free()
	
	return alignements


class GenAlignments:
	var top: int = 9999
	var baseline: int = 0
