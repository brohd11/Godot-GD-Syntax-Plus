@tool
extends VBoxContainer

const GDSynTags = preload("res://addons/syntax_plus/src/gdscript/code_edit/gdscript_syntax_plus_code.gd") #>import gdscript_tags_code.gd
const GDHelper = preload("res://addons/syntax_plus/src/gdscript/code_edit/gdscript_helper_code.gd") #>import gdscript_helper_code.gd
const Utils = GDSynTags.Utils #>import


@onready var code_edit: CodeEdit = %CodeEdit

@onready var tag_line: LineEdit = %TagLine
@onready var key_line: LineEdit = %KeyLine
@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var reload_button: Button = %ReloadButton
@onready var delete_button: Button = %DeleteButton
@onready var overwrite_button: Button = %OverwriteButton
@onready var menu_option: OptionButton = %MenuOption

var debounce:Timer

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	delete_button.icon = EditorInterface.get_base_control().get_theme_icon("Close", &"EditorIcons")
	
	color_picker_button.color_changed.connect(_on_color_picked)
	reload_button.pressed.connect(_on_reload_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	tag_line.text_changed.connect(_on_tag_changed)
	key_line.text_changed.connect(_on_key_changed)
	overwrite_button.pressed.connect(_on_overwrite_pressed)
	
	debounce = Timer.new()
	add_child(debounce)
	debounce.wait_time = 0.4
	debounce.one_shot = true
	debounce.timeout.connect(_on_debounce_timeout)

func set_data(tag, data):
	tag_line.text = tag
	var keywords = data.get("keyword", "")
	key_line.text = keywords
	overwrite_button.button_pressed = data.get("overwrite", false)
	var color = data.get("color", "ffffff")
	var color_obj = Color.html(color)
	color_picker_button.color = color_obj
	
	var _menu_option = data.get("menu", "submenu")
	if _menu_option == "Main Menu":
		menu_option.select(1)
	elif _menu_option == "None":
		menu_option.select(2)
	
	set_highlighter()
	_set_tags(tag)

func _set_tags(new_tag):
	for line in range(code_edit.get_line_count()):
		var text = code_edit.get_line(line)
		if text.strip_edges() == "":
			continue
		var delim_index = text.find(Utils.TAG_CHAR)
		if delim_index == -1:
			continue
		var text_length = text.length()
		var tag_char_len = Utils.TAG_CHAR.length()
		text = text.erase(delim_index + tag_char_len, text_length - tag_char_len + 1)
		text = text + new_tag
		code_edit.set_line(line, text)
	#code_edit.syntax_highlighter.clear_highlighting_cache()

func get_data():
	var tag = tag_line.text
	var key = key_line.text
	if key == "":
		key = "NONEZZZ"
	var data = {
		tag:{
			"keyword":key, 
			"color": color_picker_button.color.to_html(false),
			"overwrite": overwrite_button.button_pressed,
			"menu" :menu_option.get_item_text(menu_option.selected)
			}
	}
	return data


func set_highlighter():
	var data = get_data()
	var t = code_edit.text
	var new_hl = GDSynTags.new(data)
	code_edit.syntax_highlighter = new_hl
	_adjust_text()

func update_highlighter():
	pass

func _on_key_changed(new_text:String):
	debounce.start()

func _on_tag_changed(new_text:String):
	new_text = _line_strip_edges(tag_line, new_text)
	_set_tags(new_text)
	debounce.start()

func _on_color_picked(color:Color) -> void:
	debounce.start()

func _on_debounce_timeout():
	set_highlighter()

func _on_overwrite_pressed():
	#set_highlighter()
	debounce.start()

func _on_reload_pressed():
	#set_highlighter()
	debounce.start()

func _on_delete_pressed():
	queue_free()

func _line_strip_edges(line_edit:LineEdit, new_text:String):
	var current_caret_idx = line_edit.caret_column
	var white_space_front = false
	if new_text.begins_with(" "):
		white_space_front = true
	if white_space_front or new_text.ends_with(" "):
		new_text = new_text.strip_edges()
		line_edit.text = new_text
		if white_space_front and current_caret_idx == 1:
			line_edit.caret_column = 0
		elif current_caret_idx < new_text.length():
			line_edit.caret_column = current_caret_idx
		else:
			line_edit.caret_column = line_edit.text.length()
	return new_text

func _adjust_text():
	code_edit.set_line(0, code_edit.get_line(0) + " ")
	await get_tree().process_frame
	code_edit.set_line(0, code_edit.get_line(0).strip_edges())
	
	#for i in range(code_edit.get_line_count()):
		#code_edit.set_line(i, code_edit.get_line(i) + " ")
	
	pass
