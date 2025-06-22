extends EditorContextMenuPlugin

const slot = CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const Utils = preload("uid://bvmvgtxctmgl") #import utils.gd
const GDHelper = preload("uid://es6q2q0qg7pj") #import gdscript_helper.gd

const JSON_PATH = "res://addons/syntax_tags/tags.json"

var tags = []

func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	var current_line_text = se.get_line(se.get_caret_line())
	
	tags.clear()
	var editor_tags = Utils.read_from_json(JSON_PATH)
	var popup:= PopupMenu.new()
	popup.submenu_popup_delay = 0
	popup.id_pressed.connect(_tag_pressed.bind(popup, se))
	for tag in editor_tags.keys():
		var data = editor_tags.get(tag)
		var menu = data.get("menu", "Submenu")
		if menu == "None":
			continue
		var full_tag = "#" + tag
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
		
		var valid := false
		for word:String in keywords:
			if current_line_text.strip_edges().begins_with(word):
				valid = true
				break
		
		if not valid:
			continue
		
		var color:String = data.get("color", "ffffff")
		if not color.begins_with("#"):
			color = "#" + color
		var color_obj = Color(color)
		
		var img = Image.create(16,16,false, Image.FORMAT_RGBA8)
		img.fill(color_obj)
		var texture = ImageTexture.create_from_image(img)
		if menu == "Submenu":
			popup.add_icon_item(texture, tag)
		elif menu == "Main Menu":
			add_context_menu_item(tag, _on_context_pressed.bind(tag), texture)
	
	if popup.item_count == 0:
		popup.queue_free()
		return
	
	add_context_submenu_item("SyntaxTag", popup)


func _on_context_pressed(se, tag):
	_write_tag(se, tag)
func _tag_pressed(id:int, popup:PopupMenu, script_editor:CodeEdit):
	var tag = popup.get_item_text(id)
	_write_tag(script_editor, tag)


func _write_tag(script_editor:CodeEdit, tag):
	var current_line = script_editor.get_caret_line()
	var line_text = script_editor.get_line(current_line)
	var full_tag = "#" + tag
	
	var path = ""
	if tag == "import":
		path = _check_for_path(script_editor)
		if path != "":
			line_text = line_text.replace(path, path_to_uid(path))
			#line_text = line_text.erase()
	
	var full_tag_set = false
	for _tag in tags:
		if _tag == full_tag:
			continue
		if line_text.find(_tag) > -1:
			line_text = line_text.replace(_tag, full_tag)
			full_tag_set = true
			break
	
	if not full_tag_set:
		var com_index = line_text.find("#")
		if com_index > -1:
			line_text = line_text.erase(com_index, line_text.length() - com_index)
		else:
			full_tag = " " + full_tag
		line_text = line_text + full_tag
	
	script_editor.set_line(current_line, line_text)
	
	var follow_up = ""
	if path != "":
		path = uid_to_path(path)
		var file_nm = path.get_file()
		if not line_text.find(file_nm) > -1:
			follow_up = " " + file_nm
	
	line_text = line_text + follow_up
	script_editor.set_line(current_line, line_text)


func _check_for_path(se:CodeEdit):
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

func path_to_uid(path:String):
	if path.begins_with("uid://"):
		return path
	var uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
	if uid == "uid://<invalid>":
		uid = path
	return uid

func uid_to_path(uid:String):
	if not uid.begins_with("uid://"):
		return uid
	return ResourceUID.get_id_path(ResourceUID.text_to_id(uid))
