@tool
extends EditorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	add_custom_type(
		"TubeContext",
		"Resource",
		preload("tube_context.gd"),
		null
	)
	
	add_custom_type(
		"TubeClient",
		"Node",
		preload("tube_client.gd"),
		null
	)


func _exit_tree() -> void:
	remove_custom_type("TubeContext")
	remove_custom_type("TubeClient")
