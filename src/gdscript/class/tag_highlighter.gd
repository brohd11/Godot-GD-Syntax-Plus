@tool
extends RefCounted

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd") #>import utils.gd

var tagged_names: Dictionary = {} # Stores the names of consts marked for special highlighting
var _tagged_name_regex: RegEx # Dynamically built regex for these names
var declaration_regex: RegEx # To find "const NAME = xxx #import"

var tag_colors = {}
var tag_enabled = true

var highlight_color:Color

func _init(tags, tag_data, config) -> void:
	for tag in tags:
		tagged_names[">"+tag] = true
	
	for key in tag_data.keys():
		var data = tag_data.get(key)
		var color = data.get("color")
		tag_colors[">"+key] = Color.html(color)
	
	var tc = Utils.Config.tag_color
	highlight_color = config.get(tc, Utils.Config.default_settings.get(tc))
	var te = Utils.Config.tag_color_enable
	tag_enabled = config.get(te, Utils.Config.default_settings.get(te))
	
	rebuild_tagged_name_regex() # Initialize with an empty regex

func rebuild_tagged_name_regex():
	_tagged_name_regex = Utils.build_name_regex(tagged_names.keys(), true)

func check_line(hl_info, current_line_text):
	if not tag_enabled:
		return [hl_info, false]
	if current_line_text.find("#>") == -1:
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
			hl_info[start_idx] = {"color": highlight_color}
	##
	return [hl_info, needs_sort]
