extends EditorContextMenuPlugin

const Slot = CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const PathUIDLogic = preload("res://addons/syntax_plus/src/editor_plugins/path_uid_context_logic.gd") # path_uid_context_logic.gd

func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	var valid_items = PathUIDLogic.get_popup_data(se)
	for item in valid_items:
		add_context_menu_item(item, item_pressed.bind(item))

func item_pressed(script_editor, id_text):
	PathUIDLogic.replace_text(id_text, script_editor)
