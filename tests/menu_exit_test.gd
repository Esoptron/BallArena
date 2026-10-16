extends SceneTree
var failed: bool = false
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var launcher: Node = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	create_timer(0.2).timeout.connect(func() -> void:
		failed = true
		push_error("Exit button did not close the game.")
		quit(1))
	launcher.front_menu.buttons["exit"].pressed.emit()
func _finalize() -> void:
	if not failed: print("PASS main menu exit")
