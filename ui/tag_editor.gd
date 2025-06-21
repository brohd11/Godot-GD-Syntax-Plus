@tool
extends Control

const EditorGDTags = preload("uid://c4om4mori5lad") #import gdscript_tags.gd

const Utils = preload("uid://bvmvgtxctmgl") #import utils.gd
const GDHelper = preload("uid://es6q2q0qg7pj") #import gdscript_helper.gd
const TagEntry = preload("uid://d3g8fsl5famtx") #import tag_entry.tscn

signal close_requested

@onready var entries_target: VBoxContainer = %EntriesTarget

@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
	save_button.pressed.connect(_on_save_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	_read_json()



func _read_json():
	var editor_tags = Utils.read_from_json(Utils.JSON_PATH)
	
	for tag in editor_tags:
		var data = editor_tags.get(tag)
		
		var new_entry = TagEntry.instantiate()
		entries_target.add_child(new_entry)
		new_entry.set_data(tag, data)


func _on_save_button_pressed():
	var main_data = {}
	for entry in entries_target.get_children():
		var data = entry.get_data()
		var tag = data.keys()[0]
		main_data[tag] = data.get(tag)
	
	Utils.write_to_json(main_data, Utils.JSON_PATH)
	EditorGDTags.read_editor_tags()
	
	cancel_button.disabled = true
	save_button.disabled = true
	
	var accept = AcceptDialog.new()
	accept.dialog_text = "Settings saved.\nIf you changed tags or keywords, restart the editor to apply.\n\
	Colors will be change once the script text is changed."
	accept.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	add_child(accept)
	accept.popup()
	
	var handled = await accept.confirmed
	
	var syntax = EditorInterface.get_script_editor().get_current_editor().get_base_editor().syntax_highlighter
	if syntax.has_method("set_colors"):
		syntax.set_colors()
		syntax.clear_highlighting_cache()
	self.close_requested.emit()

func _on_cancel_button_pressed():
	self.close_requested.emit()
