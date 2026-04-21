const CallableLocation = SyntaxPlusSingleton.CallableLocation

const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")
const UtilsRemote = SPClasses.UtilsRemote
const UClassDetail = UtilsRemote.UClassDetail

const _BAD_SYM_COLOR:Color = Color.FIREBRICK

static func get_color_dict(color):
	return {"color": color}

static func add_color(dict:Dictionary, color:Color, idx:int, end_idx:int=-1, end_color=null, idx_safe:=true):
	if idx_safe and dict.has(idx):
		return
	if end_idx == -1:
		dict[idx] = {"color": color}
		return
	if end_color == null:
		end_color = SyntaxPlusSingleton.get_instance().comment_color
	if idx_safe:
		for i in range(idx, end_idx + 1):
			if dict.has(i):
				return
	
	dict[idx] = {"color": color}
	dict[end_idx] = {"color": end_color}


static func contains_idx(dict:Dictionary, start_idx:int, end_idx:int=-1):
	if end_idx == -1:
		return dict.has(start_idx)
	for i in range(start_idx, end_idx + 1):
		if dict.has(i):
			return true
	return false

static func highlight_all_occurences(text:String, what:String, color:Color, end_color=null):
	var hl_info = {}
	if end_color == null:
		end_color = SyntaxPlusSingleton.get_instance().default_text_color
	var regex = RegEx.new()
	regex.compile("\\b%s\\b" % what)
	var matches = regex.search_all(text)
	for m in matches:
		var start = m.get_start()
		var end = m.get_end()
		if not contains_idx(hl_info, start, end):
			hl_info[start] = {"color": color}
			hl_info[end] = {"color": end_color}
	
	return hl_info


static func strip_prefix(prefix:String, text:String):
	return text.trim_prefix(prefix + " ") # this may be changed, currently the prefix highlighting is hard coded for pre + space

static func get_tag_end_index(prefix:String, tag:String, text:String):
	if not text.begins_with(prefix):
		return -1
	var stripped = strip_prefix(prefix, text)
	if not stripped.strip_edges().begins_with(tag):
		return -1
	return text.find(tag) + tag.length()

static func highlight_prefix(prefix:String, stripped_text:String, color=null):
	var sp_ins = SyntaxPlusSingleton.get_instance()
	if color == null:
		color = sp_ins.annotation_color
	var idx = stripped_text.find(prefix)
	if idx == -1:
		return {}
	var hl_info = {}
	hl_info[idx] = SyntaxPlusSingleton.get_hl_info_dict(sp_ins.comment_color)
	hl_info[idx + 1] = SyntaxPlusSingleton.get_hl_info_dict(sp_ins.annotation_color)
	hl_info[idx + prefix.length()] = SyntaxPlusSingleton.get_hl_info_dict(sp_ins.comment_color)
	return hl_info

static func highlight_tag(tag:String, stripped_text:String, color=null):
	if color == null:
		color = SyntaxPlusSingleton.DEFAULT_TAG_COLOR
	var hl_info = {}
	var tag_idx = stripped_text.find(tag)
	add_color(hl_info, color, tag_idx, tag_idx + tag.length())
	return hl_info


static func check_const_path(class_chain:String, current_script:GDScript, start_idx:=0):
	var sp_ins = SyntaxPlusSingleton.get_instance()
	var hl_info = {}
	
	var current_idx = 0
	var type_array = [class_chain]
	if class_chain.contains("."):
		type_array = class_chain.split(".", false)
	
	var script = current_script
	for i in range(type_array.size()): # iterate parts in chain to make sure they are a valid chain
		var part = type_array[i]
		if i > 0:
			current_idx = class_chain.find(part, current_idx + 1)
		
		var adj_idx = start_idx + current_idx
		var part_color = sp_ins.base_type_color
		if UClassDetail.get_global_class_path(part) != "":
			if i == 0:
				part_color = sp_ins.user_type_color
			else:
				part_color = _BAD_SYM_COLOR
		
		var member_info = UClassDetail.get_member_info_by_path(script, part)
		#print("ARG::PART::", part, script, member_info)
		if member_info == null:
			if i < type_array.size() - 1: # if not at the end, fail color so we know chain is broken
				add_color(hl_info, _BAD_SYM_COLOR, adj_idx, adj_idx + part.length(), _BAD_SYM_COLOR)
			break
		
		var end_color = sp_ins.symbol_color
		if i == type_array.size() - 1:
			end_color = sp_ins.comment_color
		add_color(hl_info, part_color, adj_idx, adj_idx + part.length(), end_color)
		
		if member_info is GDScript:
			script = member_info
		else:
			break
	
	return hl_info

static func get_comment_tag_info(script_editor:CodeEdit, current_line_text:String, line:int, prefix:String, comment_tag_idx:int, existing_hl_info=null):
	var sp_instance = SyntaxPlusSingleton.get_instance()
	var tag = current_line_text.get_slice(prefix, 1).strip_edges().get_slice(" ", 0).strip_edges()
	var callable_data = SyntaxPlusSingleton.get_highlight_callables()
	if callable_data == null:
		return
	var highlight_callables = callable_data.get(prefix, {})
	var has_tag = highlight_callables.has(tag)
	var has_empty = false
	if highlight_callables.has(""):
		if not has_tag:
			tag = ""
		has_empty = true
	var prefix_color = SyntaxPlusSingleton.get_prefix_color(prefix)
	if prefix_color == null:
		prefix_color = sp_instance.annotation_color
	
	var callable = _get_comment_tag_hl_info # both branches use these defaults
	var custom_callable = false
	var hl_info:Dictionary = {}
	
	if existing_hl_info == null:
		if has_tag or has_empty:
			var data = highlight_callables.get(tag)
			var callable_location:CallableLocation = data.get("callable_location")
			if callable_location != CallableLocation.END:
				custom_callable = true
				callable = data.get("callable")
		
		if callable.get_object() == null:
			return {}
		
		
		if custom_callable:
			hl_info = callable.call(script_editor, current_line_text, line, comment_tag_idx)
		else:
			hl_info = callable.call(current_line_text, prefix, prefix_color)
		
		hl_info = sort_comment_tag_info(hl_info, prefix_color, comment_tag_idx)
		return hl_info
	
	
	if has_tag or has_empty:
		var data = highlight_callables.get(tag)
		var callable_location:CallableLocation = data.get("callable_location")
		if callable_location != CallableLocation.START:
			custom_callable = true
			callable = data.get("callable")
	
	if callable.get_object() == null:
		return existing_hl_info
	
	var new_hl_info:Dictionary
	if custom_callable:
		new_hl_info = callable.call(script_editor, current_line_text, line, comment_tag_idx)
	else:
		new_hl_info = callable.call(current_line_text, prefix, prefix_color)
	
	new_hl_info = sort_comment_tag_info(new_hl_info, prefix_color, comment_tag_idx)
	existing_hl_info.merge(new_hl_info)
	
	var existing_keys = existing_hl_info.keys()
	existing_keys.sort()
	for key in existing_keys:
		hl_info[key] = existing_hl_info[key]
	
	return hl_info


static func _get_comment_tag_hl_info(current_line_text:String, prefix:String, prefix_color:Color):
	var sp_ins = SyntaxPlusSingleton.get_instance()
	var all_comment_tags = SyntaxPlusSingleton.get_comment_tags()
	var comment_tags = all_comment_tags.get(prefix, [])
	var all_comment_tag_data = SyntaxPlusSingleton.get_comment_tag_data()
	var comment_tag_data = all_comment_tag_data.get(prefix)
	
	var comment_tag_idx = current_line_text.find(prefix)
	var stripped = current_line_text.substr(comment_tag_idx)
	
	var temp_hl_info:Dictionary = highlight_prefix(prefix, stripped, prefix_color)
	var comment_tag_text = stripped.replace(".", " ").strip_edges()
	
	var words = comment_tag_text.split(" ")
	for word in words:
		if word in comment_tags:
			var start_idx = comment_tag_text.find(word)
			var end_idx = start_idx + word.length()
			temp_hl_info[start_idx] = comment_tag_data.get(word)
			temp_hl_info[end_idx] = {"color":sp_ins.comment_color}
			for i in range(start_idx + 1, end_idx):
				temp_hl_info.erase(i)
	
	return temp_hl_info


static func sort_comment_tag_info(hl_info:Dictionary, _prefix_color:Color, offset=0):
	var key_adjusted_data = {}
	var hl_keys = hl_info.keys()
	hl_keys.sort()
	for key in hl_keys:
		var new_key = key + offset
		key_adjusted_data[new_key] = hl_info[key]
	
	return key_adjusted_data


static func sort_keys(hl_info:Dictionary):
	var sorted_keys = hl_info.keys()
	sorted_keys.sort()
	var temp_dict = {}
	for key in sorted_keys:
		temp_dict[key] = hl_info.get(key)
	return temp_dict
