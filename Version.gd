extends Node
# This is a modified version of noidexe's ((https://github.com/noidexe) Version.gd file. 
# Original file : https://github.com/noidexe/godot-version-manager/blob/0eedc0a13f119430fac2c5ff4233f0a44ddc2fa5/scenes/Version.gd

const api_endpoint = "https://api.github.com/repos/Yasha-jin/EtternaFontGen/releases"

# Update before creating release
const version_tag = "1.2"

# Initialized to the release list page as a fallback in case it fails to 
# get the link to the latest release for some reason
var download_url = "https://github.com/Yasha-jin/EtternaFontGen/releases/"

# Emitted if a new version is found. Use this if you need to update something.
signal update_available

func _ready():
	if !OS.is_debug_build():
		var http = HTTPRequest.new()
		add_child(http)
		http.connect("request_completed", Callable(self, "_on_request_completed"))
		http.request(api_endpoint, ["Accept: application/vnd.github.v3+json"])

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		printerr("Error %s downloaded release list from Github" % response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_ARRAY:
		printerr("Wrong response format in release list")
		return
	if json.is_empty() or typeof(json[0]) != TYPE_DICTIONARY:
		printerr("Invalid data received when requesting release list")
		return

	var last_tag : Dictionary = json[0]
	var last_version_tag : String = last_tag.get("tag_name", version_tag)
	
	if last_version_tag == version_tag:
		print("Version Tag: " + version_tag + " (up to date)")
	else:
		download_url = last_tag.get("html_url", download_url)
		emit_signal("update_available")
