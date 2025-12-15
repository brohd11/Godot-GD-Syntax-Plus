@tool
extends EditorPlugin

const TAG_EDITOR = preload("res://addons/syntax_plus/src/ui/tag_editor.tscn") # tag_editor.tscn

const PLUGIN_NAME = "SyntaxPlus"

var dock_manager:DockManager
var syntax_plus:SyntaxPlus

func _get_plugin_name() -> String:
	return PLUGIN_NAME
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("SyntaxHighlighter", &"EditorIcons")
func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if is_instance_valid(dock_manager):
		dock_manager.on_plugin_make_visible(visible)

func _enter_tree() -> void:
	DockManager.hide_main_screen_button(self)
	syntax_plus = SyntaxPlus.register_node(self)
	EditorNodeRef.call_on_ready(_add_tool_menu)


func _exit_tree() -> void:
	if is_instance_valid(syntax_plus):
		syntax_plus.unregister_node(self)
	
	if is_instance_valid(dock_manager):
		dock_manager.clean_up()
	
	remove_tool_menu_item(PLUGIN_NAME) # won't cause error if it doesn't exist


func _add_tool_menu():
	var menu_bar = EditorNodeRef.get_registered(EditorNodeRef.Nodes.TITLE_MENU_BAR)
	var project_popup = menu_bar.get_node("Project")
	var tool_menu = project_popup.get_child(0) as PopupMenu
	for i in range(tool_menu.item_count):
		if tool_menu.get_item_text(i) == PLUGIN_NAME:
			return
	
	add_tool_menu_item(PLUGIN_NAME, _on_tool_menu_pressed)

func _on_tool_menu_pressed():
	dock_manager = DockManager.new(self, TAG_EDITOR, DockManager.Slot.MAIN_SCREEN, null, false)
	dock_manager.can_be_freed = true
	dock_manager.set_default_window_size(Vector2i(DisplayServer.screen_get_size() * 0.8))
	dock_manager.add_to_tree()
