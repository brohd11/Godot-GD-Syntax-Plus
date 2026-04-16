extends EditorContextMenuPlugin

const SLOT = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE


const UtilsRemote = preload("res://addons/syntax_plus/src/utils/utils_remote.gd")
const PopupWrapper = UtilsRemote.PopupWrapper
const Params = PopupWrapper.ItemParams
const EditorConfig = preload("uid://vpqa5bp1krif") #! resolve SyntaxPlusSingleton.EditorConfig
const EditorHL = preload("uid://bnredxxo1jopk") #! resolve SyntaxPlusSingleton.EditorHL

const Utils = preload("res://addons/syntax_plus/src/utils/utils.gd")

static var tags = []

func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var popup_items = get_valid_items(se)
	PopupWrapper.create_context_plugin_items(self, se, popup_items, _on_context_pressed)

func _on_context_pressed(se, popup_path):
	if popup_path == "Syntax Plus/Clear Cache":
		clear_cache()
		return
	elif popup_path == "Syntax Plus/Reset All":
		SyntaxPlusSingleton.reset_script_highlighters()
		return
	
	write_tag(se, popup_path.get_file())


static func get_valid_items(script_editor) -> Dictionary:
	var syntax = script_editor.syntax_highlighter
	if not syntax is EditorHL:
		print("NOPE")
		return {}
	var current_line_text = script_editor.get_line(script_editor.get_caret_line())
	var popup_custom_items = {}
	var main_menu_tags = {}
	var submenu_tags = {}
	tags = []
	tags.clear()
	var editor_tags = EditorConfig.get_tags_data()
	for tag in editor_tags.keys():
		var data = editor_tags.get(tag)
		var menu = data.get("menu", "Submenu")
		if menu.to_lower() == "none":
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
		
		var color = data.get("color", "ffffff")
		var color_obj = Color.html(color) if color is String else color
		
		var img = Image.create(16,16,false, Image.FORMAT_RGBA8)
		img.fill(color_obj)
		var texture = ImageTexture.create_from_image(img)
		if menu == "Submenu":
			var tag_path = "Syntax Plus".path_join(tag)
			submenu_tags[tag_path] = {Params.ICON:[texture]}
		elif menu == "Main Menu":
			main_menu_tags[tag] = {Params.ICON:[texture]}
	
	for key in main_menu_tags.keys():
		popup_custom_items[key] = main_menu_tags.get(key)
	for key in submenu_tags.keys():
		popup_custom_items[key] = submenu_tags.get(key)
	
	#if syntax is EditorHL: # this was gated here?
	var tag_path = "Syntax Plus/Clear Cache"
	popup_custom_items[tag_path] = {}
	var reset_path = "Syntax Plus/Reset All"
	popup_custom_items[reset_path] = {}
	
	return popup_custom_items


static func clear_cache():
	var syntax = ScriptEditorRef.get_current_code_edit().syntax_highlighter
	if syntax is EditorHL:
		syntax.update_highlighter()


static func write_tag(script_editor:CodeEdit, tag:String) -> void:
	var current_line = script_editor.get_caret_line()
	var line_text = script_editor.get_line(current_line)
	var full_tag = Utils.TAG_CHAR + tag
	
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
	
	script_editor.set_line(current_line, line_text)
