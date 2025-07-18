extends EditorContextMenuPlugin

const Slot = CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const SyntaxTagContextLogic = preload("uid://pb5xaqxl2qsx") #>import syntax_tag_context_logic.gd

func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var popup_items = SyntaxTagContextLogic.get_popup_data(se)
	SyntaxTagContextLogic.add_context_popups(self, se, popup_items, _on_context_pressed)

func _on_context_pressed(se, tag):
	if tag == "Clear Cache":
		SyntaxTagContextLogic.clear_cache()
		return
	SyntaxTagContextLogic.write_tag(se, tag)
