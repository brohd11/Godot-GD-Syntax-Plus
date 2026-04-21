@tool
extends RefCounted

const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")
const Utils = SPClasses.Utils

var tagged_names: Dictionary = {} # Stores the names of consts marked for special highlighting
var _tagged_name_regex: RegEx # Dynamically built regex for these names
var declaration_regex: RegEx # To find "const NAME = xxx #import"

var tag_colors:Dictionary = {}
var tag_enabled:bool = true

var highlight_color:Color

func _init(tag_data) -> void:
	for key in tag_data.keys():
		var data = tag_data.get(key)
		var color = data.get("color")
		tagged_names[Utils.TAG_CHAR + key] = true
		tag_colors[Utils.TAG_CHAR + key] = color
	
	rebuild_tagged_name_regex() # Initialize with an empty regex

func rebuild_tagged_name_regex() -> void:
	_tagged_name_regex = Utils.build_name_regex(tagged_names.keys(), true)


func check_line(hl_info:Dictionary, current_line_text:String) -> Array:
	if not tag_enabled:
		return [hl_info, false]
	if current_line_text.find(Utils.FULL_TAG_CHAR) == -1:
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
	
	return [hl_info, needs_sort]
