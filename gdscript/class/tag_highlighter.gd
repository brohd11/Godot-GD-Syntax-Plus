@tool
extends RefCounted

const Utils = preload("uid://bvmvgtxctmgl") #>import utils.gd

var tagged_names: Array = [] # Stores the names of consts marked for special highlighting
var _tagged_name_regex: RegEx # Dynamically built regex for these names
var declaration_regex: RegEx # To find "const NAME = xxx #import"

var tag_colors = {}
var tag_color_mode = Utils.TagColorMode.GLOBAL

var highlight_color:Color

func _init(tags, tag_data, config:Dictionary) -> void:
	tagged_names = tags
	
	for key in tag_data.keys():
		var data = tag_data.get(key)
		var color = data.get("color")
		tag_colors[">"+key] = Color.html(color)
	
	var global_color = config.get(Utils.Config.global_tag_color)
	if global_color:
		highlight_color = Color.html(global_color)
	else:
		highlight_color = Color.CADET_BLUE
	
	var color_mode = config.get(Utils.Config.global_tag_mode, "Global")
	tag_color_mode = Utils.get_global_tag_mode(color_mode)
	
	rebuild_tagged_name_regex() # Initialize with an empty regex


func check_line(hl_info, current_line_text):
	if tag_color_mode == Utils.TagColorMode.NONE:
		return [hl_info, false]
	var needs_sort = false
	if not tagged_names.is_empty() and is_instance_valid(_tagged_name_regex):
		var _matches = _tagged_name_regex.search_all(current_line_text)
		for _match in _matches:
			var start_idx = _match.get_start(1)
			if not start_idx in hl_info:
				var end_idx = _match.get_end(1)
				if end_idx != current_line_text.length():
					var idx = start_idx + 1
					while idx >= 0:
						var index_data = hl_info.get(idx)
						if index_data:
							var existing_color = index_data.get("color")
							hl_info[end_idx] = {"color": existing_color}
							break
						
						idx -= 1
			
			needs_sort = true
			var tag_color = highlight_color
			if tag_color_mode == Utils.TagColorMode.TAG:
				tag_color = tag_colors.get(_match.get_string(1), Utils.DEFAULT_COLOR)
			hl_info[start_idx] = {"color": tag_color}
	
	return [hl_info, needs_sort]

func rebuild_tagged_name_regex():
	if tagged_names.is_empty():
		if is_instance_valid(_tagged_name_regex): # Check if already created
			_tagged_name_regex.compile("(?!)") # Non-matching regex
		else:
			_tagged_name_regex = RegEx.new()
			_tagged_name_regex.compile("(?!)")
		return
	
	var pattern_parts = []
	for name in tagged_names:
		pattern_parts.append(Utils.URegex.escape_regex_meta_characters(str(">" + name))) # Escape the name
	
	if not is_instance_valid(_tagged_name_regex):
		_tagged_name_regex = RegEx.new()
	
	var err = _tagged_name_regex.compile("(?:#)?(" + "|".join(pattern_parts) + ")\\b") # >
	#var err = _tagged_name_regex.compile("(" + "|".join(pattern_parts) + ")\\b")      # #>
	if err != OK:
		printerr("CustomHighlighter: Regex compilation error for imported consts: ", err)
		_tagged_name_regex.compile("(?!)")
