extends Node
class_name Formatter
## Utility class for the purpose of formatting already existing .ini file for
## font, for the sake of copy pasting into the generator faster.


static func format(filepath: String) -> void:
	var doFileExists = FileAccess.file_exists(filepath)
	
	if !doFileExists:
		return
	
	var file := FileAccess.open(filepath, FileAccess.READ)
	
	var content: PackedStringArray = []
	
	while not file.eof_reached():
		var line: String = file.get_line()
		
		if "=" in line:
			var values: PackedStringArray = line.split("=")
			content.append('"' + values[0] + '" = "' + values[1] + '",\n')
		else:
			content.append(line + "\n")
	
	var formatted_file := FileAccess.open("user://formatted.ini", FileAccess.WRITE)
	for line: String in content:
		formatted_file.store_string(line)
