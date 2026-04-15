@tool
extends Control

const PLUGIN_EXPORT_FLAT = false

const EditorGDTags = preload("res://addons/syntax_plus/src/gdscript/editor/gdscript_syntax_plus.gd") #>import gdscript_tags.gd

const EditorConfig = SyntaxPlusSingleton.EditorConfig

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd") #>import utils.gd
const GDHelperCode = preload("res://addons/syntax_plus/src/gdscript/code_edit/gdscript_helper_code.gd") #>import gdscript_helper_code.gd
const TagEntry = preload("res://addons/syntax_plus/src/ui/tag_entry.tscn") #>import tag_entry.tscn

signal close_requested

@onready var dock_button: Button = %DockButton

@onready var bg: ColorRect = %BG
@onready var mb_hide_spacer: Control = %MBHideSpacer

@onready var entries_target: VBoxContainer = %EntriesTarget
@onready var new_entry_button: Button = %NewEntryButton

@onready var set_all_scripts_check: CheckBox = %SetAllScripts

@onready var global_tag_color: ColorPickerButton = %GlobalTagColor
@onready var tag_check: CheckBox = %TagCheck
@onready var class_color: ColorPickerButton = %ClassColor
@onready var class_check: CheckBox = %ClassCheck
@onready var const_color: ColorPickerButton = %ConstColor
@onready var const_check: CheckBox = %ConstCheck
@onready var onready_color: ColorPickerButton = %OnreadyColor
@onready var onready_check: CheckBox = %OnreadyCheck
@onready var member_color: ColorPickerButton = %MemberColor
@onready var member_check: CheckBox = %MemberCheck
@onready var member_access_color: ColorPickerButton = %MemberAccessColor
@onready var member_access_check: CheckBox = %MemberAccessCheck


@onready var save_button: Button = %SaveButton
@onready var button_spacer: Control = %ButtonSpacer
@onready var cancel_button: Button = %CancelButton

var debounce:Timer

var is_mb_panel_flag:= false

func _ready() -> void:
	var color_pickers = [global_tag_color, class_color, onready_color, const_color, member_color, member_access_color]
	for pick in color_pickers:
		pick.color_changed.connect(_on_tag_color_changed)
	
	var checks = [class_check, const_check, onready_check, member_check, member_access_check, tag_check]
	for check in checks:
		check.pressed.connect(_start_debounce)
	 
	new_entry_button.pressed.connect(_on_new_entry_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	debounce = Timer.new()
	add_child(debounce)
	debounce.wait_time = 0.4
	debounce.one_shot = true
	debounce.timeout.connect(_on_debounce_timeout)
	
	_read_json()
	
	is_mb_panel() # with Docking Manager this is ok, maybe just remove


func is_mb_panel(): # for Modular Browser 
	cancel_button.hide()
	button_spacer.hide()
	mb_hide_spacer.hide()
	bg.hide()


func _read_json():
	set_all_scripts_check.button_pressed = EditorConfig.get_setting(EditorConfig.Settings.SET_AS_DEFAULT_HIGHLIGHTER)
	class_color.color = EditorConfig.get_setting(EditorConfig.Settings.PASCAL_COLOR)
	class_check.button_pressed = EditorConfig.get_setting(EditorConfig.Settings.PASCAL_ENABLE)
	const_color.color = EditorConfig.get_setting(EditorConfig.Settings.CONST_COLOR)
	const_check.button_pressed = EditorConfig.get_setting(EditorConfig.Settings.CONST_ENABLE)
	onready_color.color = EditorConfig.get_setting(EditorConfig.Settings.ONREADY_COLOR)
	onready_check.button_pressed = EditorConfig.get_setting(EditorConfig.Settings.ONREADY_ENABLE)
	member_color.color = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_COLOR)
	member_check.button_pressed = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_ENABLE)
	member_access_color.color = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_ACCESS_COLOR)
	member_access_check.button_pressed = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_ACCESS_ENABLE)
	global_tag_color.color = EditorConfig.get_setting(EditorConfig.Settings.TAG_COLOR)
	tag_check.button_pressed = EditorConfig.get_setting(EditorConfig.Settings.TAG_COLOR_ENABLE)
	
	GDHelperCode.config = EditorConfig.data
	
	var editor_tags = EditorConfig.get_tags_data()
	for tag in editor_tags:
		var data = editor_tags.get(tag)
		var new_entry = TagEntry.instantiate()
		entries_target.add_child(new_entry)
		new_entry.set_data(tag, data)


func _on_new_entry_button_pressed():
	var new_entry = TagEntry.instantiate()
	entries_target.add_child(new_entry)
	new_entry.set_data("new_tag", {"keyword":"var"})

func _start_debounce():
	debounce.start()

func _on_tag_color_changed(color:Color) -> void:
	debounce.start()


func _on_debounce_timeout():
	GDHelperCode.config = get_config()
	await get_tree().process_frame
	for entry in entries_target.get_children():
		entry.set_highlighter()

func _get_tag_data() -> Dictionary:
	var tags_data = {}
	for entry in entries_target.get_children():
		var data = entry.get_data()
		var tag = data.keys()[0]
		tags_data[tag] = data.get(tag)
	return tags_data

func get_config():
	return {
	Utils.Settings.SET_AS_DEFAULT_HIGHLIGHTER: set_all_scripts_check.button_pressed,
	Utils.Settings.CONST_COLOR: const_color.color,
	Utils.Settings.CONST_ENABLE: const_check.button_pressed,
	Utils.Settings.PASCAL_COLOR: class_color.color,
	Utils.Settings.PASCAL_ENABLE: class_check.button_pressed,
	Utils.Settings.MEMBER_COLOR: member_color.color,
	Utils.Settings.MEMBER_ENABLE: member_check.button_pressed,
	Utils.Settings.MEMBER_ACCESS_COLOR: member_access_color.color,
	Utils.Settings.MEMBER_ACCESS_ENABLE: member_access_check.button_pressed,
	Utils.Settings.ONREADY_COLOR: onready_color.color,
	Utils.Settings.ONREADY_ENABLE: onready_check.button_pressed,
	Utils.Settings.TAG_COLOR: global_tag_color.color,
	Utils.Settings.TAG_COLOR_ENABLE: tag_check.button_pressed,
	}

func _on_save_button_pressed(): 
	var new_cfg = get_config()
	for key in new_cfg:
		EditorInterface.get_editor_settings().set_setting(key, new_cfg.get(key))
	
	EditorInterface.get_editor_settings().set_setting(Utils.Settings.DEFINED_TAGS, _get_tag_data())
	
	GDHelperCode.config = EditorConfig.data
	EditorGDTags.editor_tags = EditorConfig.get_tags_data()
	SyntaxPlusSingleton.reset_script_highlighters()
	
	
	var accept = AcceptDialog.new()
	accept.dialog_text = "Saved, you can close the tag editor."
	accept.title = "Saved Tags"
	
	accept.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	add_child(accept)
	accept.popup_centered()
	await accept.confirmed
	
	self.close_requested.emit()

func _on_cancel_button_pressed():
	GDHelperCode.config = EditorConfig.data
	self.close_requested.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		GDHelperCode.config = EditorConfig.data
