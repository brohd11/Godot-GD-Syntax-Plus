@tool
extends Control

const PLUGIN_EXPORT_FLAT = false

const EditorGDTags = preload("uid://c4om4mori5lad") #>import gdscript_tags.gd

const Utils = preload("uid://bvmvgtxctmgl") #>import utils.gd
const GDHelper = preload("uid://qaydfc8u03fq") #>import gdscript_helper_code.gd
const TagEntry = preload("uid://d3g8fsl5famtx") #>import tag_entry.tscn

signal close_requested

@onready var bg: ColorRect = %BG
@onready var mb_hide_spacer: Control = %MBHideSpacer

@onready var entries_target: VBoxContainer = %EntriesTarget
@onready var new_entry_button: Button = %NewEntryButton

@onready var global_tag_color: ColorPickerButton = %GlobalTagColor
@onready var tag_highlight_option: OptionButton = %TagHighlightOption
@onready var class_color: ColorPickerButton = %ClassColor
@onready var class_check: CheckBox = %ClassCheck
@onready var const_color: ColorPickerButton = %ConstColor
@onready var const_check: CheckBox = %ConstCheck

@onready var save_button: Button = %SaveButton
@onready var button_spacer: Control = %ButtonSpacer
@onready var cancel_button: Button = %CancelButton

var debounce:Timer

var is_mb_panel_flag:= false

func _ready() -> void:
	new_entry_button.pressed.connect(_on_new_entry_button_pressed)
	tag_highlight_option.item_selected.connect(_on_tag_highlight_selected)
	global_tag_color.color_changed.connect(_on_tag_color_changed)
	class_color.color_changed.connect(_on_tag_color_changed)
	class_check.pressed.connect(_start_debounce)
	const_color.color_changed.connect(_on_tag_color_changed)
	const_check.pressed.connect(_start_debounce)
	
	save_button.pressed.connect(_on_save_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	debounce = Timer.new()
	add_child(debounce)
	debounce.wait_time = 0.4
	debounce.one_shot = true
	debounce.timeout.connect(_on_debounce_timeout)
	
	_read_json()

func is_mb_panel(): # for Modular Browser
	cancel_button.hide()
	button_spacer.hide()
	mb_hide_spacer.hide()
	bg.hide()

func _read_json():
	var tag_data = Utils.UFile.read_from_json(Utils.JSON_PATH)
	var config = tag_data.get("config", {})
	
	var tag_color = config.get(Utils.Config.global_tag_color, Utils.DEFAULT_COLOR_STRING)
	global_tag_color.color = Color.html(tag_color)
	var tag_color_option = config.get(Utils.Config.global_tag_mode, "Global")
	tag_highlight_option.select(Utils.get_global_tag_mode(tag_color_option))
	
	var class_tag_color = config.get(Utils.Config.highlight_class_color, Utils.DEFAULT_COLOR_STRING)
	class_color.color = Color.html(class_tag_color)
	class_check.button_pressed = config.get(Utils.Config.highlight_class, false)
	
	var const_tag_color = config.get(Utils.Config.highlight_const_color, Utils.DEFAULT_COLOR_STRING)
	const_color.color = Color.html(const_tag_color)
	const_check.button_pressed = config.get(Utils.Config.highlight_const, false)
	
	GDHelper.config = config
	
	var editor_tags =  tag_data.get("tags", {})
	
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

func _on_tag_highlight_selected(idx):
	_on_debounce_timeout()

func _on_debounce_timeout():
	GDHelper.config = _get_config_data()
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

func _get_config_data() -> Dictionary:
	var config_data = {
		Utils.Config.global_tag_color:global_tag_color.color.to_html(),
		Utils.Config.global_tag_mode: Utils.get_global_tag_mode(tag_highlight_option.selected),
		Utils.Config.highlight_class: class_check.button_pressed,
		Utils.Config.highlight_class_color: class_color.color.to_html(),
		Utils.Config.highlight_const: const_check.button_pressed,
		Utils.Config.highlight_const_color: const_color.color.to_html(),
	}
	return config_data

func _on_save_button_pressed():
	var tag_file_data = {
		"tags": _get_tag_data(),
		"config": _get_config_data()
	}
	
	Utils.UFile.write_to_json_exported(tag_file_data, Utils.JSON_PATH, PLUGIN_EXPORT_FLAT)
	
	GDHelper.config = Utils.get_config()
	EditorGDTags.read_editor_tags()
	
	
	var script_editor = EditorInterface.get_script_editor()
	var current_syntax = script_editor.get_current_editor().get_base_editor().syntax_highlighter
	if current_syntax.has_method("load_global_data"):
		current_syntax.load_global_data()
		current_syntax.read_editor_tags()
		current_syntax.create_highlight_helpers()
		current_syntax.clear_highlighting_cache()
	
	for script:ScriptEditorBase in script_editor.get_open_script_editors():
		var syntax = script.get_base_editor().syntax_highlighter
		if syntax.has_method("load_global_data"):
			syntax.read_editor_tags()
			syntax.create_highlight_helpers()
			syntax.clear_highlighting_cache()
	
	if is_mb_panel_flag:
		var accept = AcceptDialog.new()
		accept.dialog_text = "Saved, you can close the window."
		
		accept.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
		add_child(accept)
		accept.popup_centered()
		await accept.confirmed
	
	self.close_requested.emit()

func _on_cancel_button_pressed():
	GDHelper.config = Utils.get_config()
	self.close_requested.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		GDHelper.config = Utils.get_config()
