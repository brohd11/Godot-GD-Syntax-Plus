extends EditorContextMenuPlugin

const Slot = CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const PopupHelper = preload("res://addons/syntax_tags/src/remote/popup_helper.gd")
const Param = PopupHelper.ParamKeys
const SyntaxTagContextLogic = preload("uid://pb5xaqxl2qsx") #>import syntax_tag_context_logic.gd

func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var popup_items = SyntaxTagContextLogic.get_popup_data(se)
	var submenu = PopupMenu.new()
	for item:String in popup_items.keys():
		var main_menu = true
		var item_text = item
		if item.begins_with("Syntax Tags"):
			main_menu = false
			item_text = item.get_slice("/", 1)
		var data = popup_items.get(item)
		var icon = data.get(Param.ICON_KEY,[])
		if main_menu:
			if icon.is_empty():
				add_context_menu_item(item_text, _on_context_pressed)
			else:
				add_context_menu_item(item_text, _on_context_pressed, icon[0])
		else:
			if icon.is_empty():
				submenu.add_item(item_text)
			else:
				submenu.add_icon_item(icon[0], item_text)
	
	if submenu.item_count == 0:
		submenu.queue_free()
	else:
		submenu.id_pressed.connect(_tag_pressed.bind(submenu, se))
		add_context_submenu_item("Syntax Tags", submenu)


func _on_context_pressed(se, tag):
	SyntaxTagContextLogic.write_tag(se, tag)
func _tag_pressed(id:int, popup:PopupMenu, script_editor:CodeEdit):
	var tag = popup.get_item_text(id)
	if tag == "Clear Cache":
		SyntaxTagContextLogic.clear_cache()
		return
	SyntaxTagContextLogic.write_tag(script_editor, tag)
