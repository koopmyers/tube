class_name EditorTubeMessagesContainer extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.

@export var message_control: EditorTubeMessageControl
@export var max_messages_amount := 100:
	set(x):
		max_messages_amount = x
		if is_instance_valid(messages_amount_label):
			messages_amount_label.text = "(last {value})".format({
				"value": max_messages_amount
			})


var _display_from: Object


@onready var messages_amount_label: Label = %MessagesAmountLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var list_container: Container = %ListContainer


func is_displaying_from(p_from) -> bool:
	return _display_from == p_from


func display_messages(p_controls: Array[EditorTubeMessagesItemControl], p_from: Object = null):
	
	_display_from = p_from
	
	for child in list_container.get_children():
		list_container.remove_child(child)
	
	var last_control
	var pressed_control
	for control in p_controls:
		if not is_instance_valid(control):
			continue
		
		if control.is_queued_for_deletion():
			continue
		
		control.message_control = message_control
		list_container.add_child(control)
		last_control = control
		
		if control.is_pressed():
			pressed_control = control
	
	
	if pressed_control:
		last_control = pressed_control
		message_control.message_item_control = last_control
	else:
		message_control.message_item_control = null
	
	if not last_control:
		return
	
	await get_tree().process_frame
	if not is_instance_valid(last_control) or last_control.is_queued_for_deletion():
		return
	scroll_container.ensure_control_visible(last_control)



func _on_clipboard_button_pressed() -> void:
	var clipboard := ""
	for child in list_container.get_children():
		clipboard += str(child) + "\n"
	
	DisplayServer.clipboard_set(clipboard)
