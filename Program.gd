extends Control


const valid_extensions: PackedStringArray = [
	"ttf",
	"ttc",
	"otf",
	"otc",
	"woff",
	"woff2",
	"pfb",
	"pfm",
	"fnt",
	"font"
]


var max_steps: int = 0
var selected_font: String = ""
var dropdown_path: Dictionary = {}


var file_path: String = ""
var font_size: int = 8
var doubleres: bool = true
var custom_file_name: String = ""
var fix_alpha_pixels: bool = true


@onready var font_dropdown: OptionButton = %Fonts
@onready var render: SubViewport = $SubViewport
@onready var generate_button: Button = %GenerateButton
@onready var process: Label = %Process
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var spinbox: SpinBox = %FontSize


func _ready() -> void:
	$Interface/Version.text = "Version " + Version.version_tag
	$Interface/Version.uri = Version.download_url
	Version.connect("update_available", Callable(self, "update_version_label"))
	
	#Formatter.format()
	Sections.initialize_custom_sheets()
	
#	get_viewport().files_dropped.connect(on_files_dropped)
	fill_font_dropdown()
	delete_shader_cache()
	
	# "fix" for the suffix padding
	spinbox.get_child(0, true).text = str(spinbox.value) + "px"
	spinbox.get_child(0, true).connect("focus_exited", Callable(self, "_on_font_size_text_edit_focus_exited"))


func update_version_label() -> void:
	$Interface/Version.text += " (new update available)"
	$Interface/Version.underline = LinkButton.UNDERLINE_MODE_ALWAYS


func fill_font_dropdown() -> void:
	var font_names: PackedStringArray = []
	match OS.get_name():
		"Windows":
			font_names = fill_font_dropdown_windows(font_names)
		"macOS":
			OS.alert("macOS is not supported.")
			OS.kill(OS.get_process_id())
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			OS.alert("Linux is not supported.")
			OS.kill(OS.get_process_id())
	
	font_names.sort()
	
	for font_name in font_names:
		font_dropdown.add_item(font_name)
	selected_font = font_dropdown.get_item_text(0)
	
	# Theme the internal node of the OptionButton
	# PopupMenu
	font_dropdown.get_child(0, true).max_size = Vector2i(32768, 266)
	# VScrollBar
	var vscroll: VScrollBar = font_dropdown.get_child(0, true).get_child(0, true).get_child(0, true).get_child(2, true)
	vscroll.set_deferred("size", Vector2i(18, 266))
	await get_tree().process_frame
	vscroll.set_deferred("position", vscroll.position - Vector2(10, 0))


func fill_font_dropdown_windows(font_names: PackedStringArray) -> PackedStringArray:
	var path: String = "C:/Windows/Fonts"
	var default_font: Font = ThemeDB.get_project_theme().default_font
	for file in DirAccess.get_files_at(path):
		if file.get_extension() in valid_extensions:
			var font = FontFile.new()
			font.load_dynamic_font(path + "/" + file)
			var font_name = font.get_font_name() + " " + font.get_font_style_name()
			
			var font_name_width:int = default_font.get_string_size(font_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			while font_name_width >= 320:
				var left: String = font_name.substr(0, (font_name.length() / 2) - 1)
				var right: String = font_name.substr(font_name.length() / 2, (font_name.length() / 2) + 1)
				font_name = left + right
				font_name_width = default_font.get_string_size(font_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				if font_name_width < 320:
					font_name = left + "..." + right
			
			font_names.append(font_name)
			dropdown_path[font_name] = path + "/" + file
	if OS.has_environment("USERNAME"):
		path = "C:/Users/" + OS.get_environment("USERNAME") + "/AppData/Local/Microsoft/Windows/Fonts"
		for file in DirAccess.get_files_at(path):
			if file.get_extension() in valid_extensions:
				var font = FontFile.new()
				font.load_dynamic_font(path + "/" + file)
				var font_name = font.get_font_name() + " " + font.get_font_style_name()
				
				var font_name_width:int = default_font.get_string_size(font_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				while font_name_width >= 320:
					var left: String = font_name.substr(0, (font_name.length() / 2) - 1)
					var right: String = font_name.substr(font_name.length() / 2, (font_name.length() / 2) + 1)
					font_name = left + right
					font_name_width = default_font.get_string_size(font_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
					if font_name_width < 320:
						font_name = left + "..." + right
				
				font_names.append(font_name)
				dropdown_path[font_name] = path + "/" + file
	
	return font_names


func delete_shader_cache() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://") + "shader_cache"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://") + "shader_cache")


func _on_sub_viewport_error(error: String) -> void:
	process.text = error
	generate_button.disabled = false


func _on_sub_viewport_set_current_step(step: int, step_name: String) -> void:
	process.text = step_name
	progress_bar.value = step
	
	if step == max_steps:
		generate_button.disabled = false
		generate_button.text = "Generate"
		progress_bar.value = 0
		OS.shell_open(ProjectSettings.globalize_path("user://"))


func _on_sub_viewport_set_max_step(max_step: int) -> void:
	max_steps = max_step
	progress_bar.max_value = max_step


func _on_generate_pressed() -> void:
	generate_button.text = "Working..."
	generate_button.disabled = true
	file_path = dropdown_path[selected_font]
	render.start_render(file_path, font_size, doubleres, custom_file_name, fix_alpha_pixels)


func _on_file_path_text_changed(new_text: String) -> void:
	file_path = new_text


func _on_font_name_text_changed(new_text: String) -> void:
	custom_file_name = new_text


func _on_font_size_value_changed(value: float) -> void:
	font_size = int(value)
	await get_tree().process_frame
	spinbox.get_child(0, true).release_focus()
	spinbox.get_child(0, true).text = str(spinbox.value) + "px"


func _on_doubleres_toggled(button_pressed: bool) -> void:
	doubleres = button_pressed


func _on_output_button_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _on_fonts_item_selected(index: int) -> void:
	selected_font = font_dropdown.get_item_text(index)


func _on_font_size_text_edit_focus_exited() -> void:
	spinbox.get_child(0, true).set_deferred("text", str(spinbox.value) + "px")
