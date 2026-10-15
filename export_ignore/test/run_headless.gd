extends SceneTree
## Clean-compile headless entry for the syntax_plus suites, exiting with a CI code.
##     godot --headless --path . --script res://addons/syntax_plus/export_ignore/test/run_headless.gd
##
## Only the parser-facing helpers are covered here. The highlighter itself is an
## EditorSyntaxHighlighter driven per rendered line by a live script editor, so its colouring is
## checked by hand in the editor.

const SUITES:PackedStringArray = [
	"res://addons/syntax_plus/export_ignore/test/line_data_test.gd",
]

## _initialize(), not _init(): the main loop is null during _init(), so the native backend cannot
## attach and the native-mode check would skip. See addons/_lib/gdscript_parser/_export_ignore/test/run_all_headless.gd.
func _initialize() -> void:
	_run_suites.call_deferred()


func _run_suites() -> void:
	var success = true
	var output:Array[String] = []

	for path in SUITES:
		var res:Dictionary = load(path).run_tests()
		success = success and res.result == 0
		output.append_array(res.output)

	print("\n".join(output))
	quit(0 if success else 1)
