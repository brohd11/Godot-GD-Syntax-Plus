extends "res://addons/addon_lib/brohd/popup_wrapper/pw_context_logic_base.gd"

const Slot = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE
const PopupPriority = 1

const Utils = preload("uid://bvmvgtxctmgl") #>import utils.gd
const GDHelper = preload("uid://es6q2q0qg7pj") #>import gdscript_helper.gd

static var tags = []

static func get_callable() -> Callable:
	return custom_item_pressed

static func get_popup_data(script_editor) -> Dictionary:
	var syntax = script_editor.syntax_highlighter
	if not syntax.has_method("update_tagged_name_list"):
		return {}
	var current_line_text = script_editor.get_line(script_editor.get_caret_line())
	var popup_custom_items = {}
	var main_menu_tags = {}
	var submenu_tags = {}
	tags = []
	tags.clear()
	var editor_tags = Utils.get_tags_data()
	for tag in editor_tags.keys():
		var data = editor_tags.get(tag)
		var menu = data.get("menu", "Submenu")
		if menu == "None":
			continue
		var full_tag = Utils.TAG_CHAR + tag
		tags.append(full_tag)
		if current_line_text.find(full_tag) > -1:
			continue
		
		var keyword:String = data.get("keyword", "")
		if keyword == "any":
			keyword = Utils.ANY_STRING
		
		var keywords:= []
		if keyword.find("|") > -1:
			keywords = keyword.split("|", false)
		else:
			keywords = [keyword]
		if "func" in keywords:
			keywords.append("static func")
		if "var" in keywords:
			keywords.append("static var")
		var valid := false
		for word:String in keywords:
			var stripped = current_line_text.strip_edges()
			if stripped.begins_with(word) or stripped.begins_with("# "+word):
				valid = true
				break
		if not valid:
			continue
		
		var color:String = data.get("color", "ffffff")
		var color_obj = Color.html(color)
		
		var img = Image.create(16,16,false, Image.FORMAT_RGBA8)
		img.fill(color_obj)
		var texture = ImageTexture.create_from_image(img)
		if menu == "Submenu":
			var tag_path = "Syntax Tags".path_join(tag)
			submenu_tags[tag_path] = {Params.ICON_KEY:[texture]}
		elif menu == "Main Menu":
			main_menu_tags[tag] = {Params.ICON_KEY:[texture]}
	
	for key in main_menu_tags.keys():
		popup_custom_items[key] = main_menu_tags.get(key)
	for key in submenu_tags.keys():
		popup_custom_items[key] = submenu_tags.get(key)
	if syntax.has_method("update_tagged_name_list"):
		var tag_path = "Syntax Tags/Clear Cache"
		popup_custom_items[tag_path] = {}
	
	return popup_custom_items


static func custom_item_pressed(id, popup, script_editor):
	if id < 5000:
		return
	var id_text = PopupHelper.parse_id_text(id, popup)
	if id_text == "Clear Cache":
		clear_cache()
		return
	write_tag(script_editor, id_text)


static func clear_cache():
	var syntax = EditorInterface.get_script_editor().get_current_editor().get_base_editor().syntax_highlighter
	if syntax.has_method("update_tagged_name_list"):
		syntax.update_tagged_name_list(true)
		syntax.clear_highlighting_cache()


static func write_tag(script_editor:CodeEdit, tag):
	var current_line = script_editor.get_caret_line()
	var line_text = script_editor.get_line(current_line)
	var full_tag = Utils.TAG_CHAR + tag
	
	var path = ""
	if tag == "import":
		path = _check_for_path(script_editor)
		if path != "":
			line_text = line_text.replace(path, path_to_uid(path))
	
	var full_tag_set = false
	for _tag in tags:
		if _tag == full_tag:
			continue
		var tag_with_space = _tag + " "
		if line_text.find(tag_with_space) > -1:
			line_text = line_text.replace(_tag, full_tag)
			full_tag_set = true
			break
	
	if not full_tag_set:
		line_text = line_text.strip_edges(false)
		var delim_index = line_text.find(Utils.TAG_CHAR)
		if delim_index > -1:
			line_text = line_text.erase(delim_index, line_text.length() - delim_index)
		else:
			full_tag = " " + full_tag
		line_text = line_text + full_tag
	
	var follow_up = ""
	if path != "":
		path = uid_to_path(path)
		var file_nm = path.get_file()
		if not line_text.find(file_nm) > -1:
			follow_up = " " + file_nm
	
	line_text = line_text + follow_up
	script_editor.set_line(current_line, line_text)


static func _check_for_path(se:CodeEdit):
	var path = ""
	var t:String = se.get_selected_text()
	if FileAccess.file_exists(t):
		path = t
	if path == "":
		var l = se.get_line(se.get_caret_line())
		var start_ind = l.find('"')
		if start_ind > -1:
			var end_ind = l.find('"', start_ind + 1)
			if end_ind > -1:
				var length = end_ind - start_ind
				var substr = l.substr(start_ind + 1, length - 1)
				if FileAccess.file_exists(substr):
					path = substr
	return path

static func path_to_uid(path:String):
	if path.begins_with("uid://"):
		return path
	var uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
	if uid == "uid://<invalid>":
		uid = path
	return uid

static func uid_to_path(uid:String):
	if not uid.begins_with("uid://"):
		return uid
	return ResourceUID.get_id_path(ResourceUID.text_to_id(uid))
