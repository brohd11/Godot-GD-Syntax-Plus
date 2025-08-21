extends EditorContextMenuPlugin

const SLOT = CONTEXT_SLOT_SCRIPT_EDITOR_CODE
const UtilsRemote = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_remote.gd")
const PopupWrapper = UtilsRemote.PopupWrapper
const Param = PopupWrapper.ItemParams

func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	var valid_items = get_valid_items(se)
	
	PopupWrapper.create_context_plugin_items(self, se, valid_items, _context_callback)

static func get_valid_items(script_editor) -> Dictionary:
	var valid_items = {}
	var path = _check_for_path(script_editor)
	if path == "":
		return valid_items
	if path.begins_with("uid://"):
		valid_items["UID to Path"] = {Param.METADATA_KEY:{Param.PRIORITY:0}}
		valid_items["Add #Path"] = {Param.METADATA_KEY:{Param.PRIORITY:0}}
	elif path.begins_with("res://"):
		valid_items["Path to UID"] = {Param.METADATA_KEY:{Param.PRIORITY:0}}
		valid_items["Path to UID+#"] = {Param.METADATA_KEY:{Param.PRIORITY:0}}
	
	return valid_items

func _context_callback(script_editor, popup_path):
	if popup_path == "UID to Path":
		_uid_to_path(script_editor)
	elif popup_path == "Add #Path":
		_uid_add_comment(script_editor)
	elif popup_path == "Path to UID":
		_path_to_uid(script_editor)
	elif popup_path == "Path to UID+#":
		_path_to_uid(script_editor, true)


static func _path_to_uid(se, comment=false):
	var is_sel = _ensure_path_selected(se)
	var t = se.get_selected_text()
	var uid = path_to_uid(t)
	
	se.insert_text_at_caret(uid)
	if comment:
		_add_comment(se, uid, t)
	if is_sel:
		_select_text(se, uid)

static func _uid_to_path(se):
	var is_sel = _ensure_path_selected(se)
	var t = se.get_selected_text()
	var path = uid_to_path(t)
	
	se.insert_text_at_caret(path)
	if is_sel:
		_select_text(se, path)

static func _uid_add_comment(se):
	var is_sel = _ensure_path_selected(se)
	var t = se.get_selected_text()
	var path = uid_to_path(t)
	
	_add_comment(se, t, path)
	if is_sel:
		_select_text(se, t)

static func _add_comment(se:CodeEdit, text, path_comment):
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
		se.insert_text_at_caret(" # " + path_comment.get_file())

static func _select_text(se:CodeEdit, text):
	var c_l = se.get_caret_line()
	var l = se.get_line(c_l)
	var first_ind = l.find(text)
	se.select(c_l, first_ind, c_l, first_ind + text.length())

static func _ensure_path_selected(se:CodeEdit):
	var to_replace = _check_for_path(se)
	var t:String = se.get_selected_text()
	if t == to_replace:
		return true
	var c_l = se.get_caret_line()
	var l = se.get_line(c_l)
	
	var start_ind = l.find(to_replace)
	se.select(c_l, start_ind, c_l, start_ind + to_replace.length())
	return false

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
	return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))

static func uid_to_path(uid:String):
	if not uid.begins_with("uid://"):
		return uid
	return ResourceUID.get_id_path(ResourceUID.text_to_id(uid))
