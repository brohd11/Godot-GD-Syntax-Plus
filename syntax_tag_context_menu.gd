extends EditorContextMenuPlugin

const slot = CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const Utils = preload("res://addons/syntax_tags/gdscript/class/utils.gd")
const GDHelper = preload("uid://es6q2q0qg7pj") #import gdscript_helper.gd

const JSON_PATH = "res://addons/syntax_tags/tags.json"

func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var current_line_text = se.get_line(se.get_caret_line())
	
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
		if current_line_text.find(full_tag) > -1:
			popup.queue_free()
			return
		
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

func _write_tag(script_editor, tag):
	var current_line = script_editor.get_caret_line()
	var line_text = script_editor.get_line(current_line)
	
	var path = ""
	if tag == "import":
		path = _check_for_path(script_editor)
		if path != "":
			_path_to_uid(script_editor)
	print(path)
	line_text = script_editor.get_line(current_line)
	var full_tag = " #" + tag
	
	var text_index = line_text.length()
	script_editor.insert_text(full_tag, current_line, text_index)
	var follow_up = " "
	if path != "":
		path = uid_to_path(path)
		follow_up = " " + path.get_file()
	script_editor.insert_text(follow_up, current_line, text_index + full_tag.length())

func _path_to_uid(se, comment=false):
	var is_sel = _ensure_path_selected(se)
	var t = se.get_selected_text()
	var uid = path_to_uid(t)
	
	se.insert_text_at_caret(uid)
	if comment:
		_add_comment(se, uid, t)
	if is_sel:
		_select_text(se, uid)

func _uid_to_path(se):
	var is_sel = _ensure_path_selected(se)
	var t = se.get_selected_text()
	var path = uid_to_path(t)
	
	se.insert_text_at_caret(path)
	if is_sel:
		_select_text(se, path)

func _uid_add_comment(se):
	var is_sel = _ensure_path_selected(se)
	var t = se.get_selected_text()
	var path = uid_to_path(t)
	
	_add_comment(se, t, path)
	if is_sel:
		_select_text(se, t)


func _add_comment(se:CodeEdit, text, path_comment):
	var c_l = se.get_caret_line()
	var line_text = se.get_line(c_l)
	var end_ind = 1
	var ind = -1
	if line_text.find('"),') > -1:
		ind = line_text.find('"),')
		end_ind = 3
	elif line_text.find('")') > -1 or line_text.find('",') > -1:
		ind = line_text.find('")')
		end_ind = 2
	elif line_text.find('",') > -1:
		ind = line_text.find('",')
		end_ind = 2
	else:
		ind = line_text.rfind('"')
		end_ind = 1
	if ind > -1:
		se.select(c_l,  ind + end_ind, c_l, line_text.length())
		se.insert_text_at_caret(" # " + path_comment)

func _select_text(se:CodeEdit, text):
	var c_l = se.get_caret_line()
	var l = se.get_line(c_l)
	var first_ind = l.find(text)
	se.select(c_l, first_ind, c_l, first_ind + text.length())

func _ensure_path_selected(se:CodeEdit):
	var to_replace = _check_for_path(se)
	var t:String = se.get_selected_text()
	if t == to_replace:
		return true
	var c_l = se.get_caret_line()
	var l = se.get_line(c_l)
	
	var start_ind = l.find(to_replace)
	se.select(c_l, start_ind, c_l, start_ind + to_replace.length())
	return false

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
