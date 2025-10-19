class_name EditorTubeChatControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.


const MESSAGE_ITEM_CONTROL_SCENE := preload("uid://cfsei3airwx4s")


@export var messages_container: EditorTubeMessagesContainer
@export var max_messages_amount: int = 100

var message_item_controls: Array[EditorTubeMessagesItemControl] = []
var message_item_button_group := ButtonGroup.new()

@onready var line_edit: LineEdit = %LineEdit


func _ready() -> void:
	message_item_button_group.allow_unpress = true


func add_message_item_control(data) -> EditorTubeMessagesItemControl:
	if max_messages_amount <= message_item_controls.size():
		var item := message_item_controls.pop_front()
		item.queue_free()
	
	var message_item_control := MESSAGE_ITEM_CONTROL_SCENE.instantiate()
	message_item_controls.append(message_item_control)
	message_item_control.data = data
	message_item_control.button_group = message_item_button_group
	return message_item_control


func update():
	if is_instance_valid(messages_container):
		if messages_container.is_displaying_from(self):
			messages_container.display_messages(
				message_item_controls,
				self
			)


func send_chat_message(p_message: String):
	add_message_item_control(p_message).sent()
	update()
	receive_chat_message.rpc(p_message)
	line_edit.text = ""


@rpc("any_peer", "call_remote", "reliable")
func receive_chat_message(p_message: String):
	var peer_id := multiplayer.get_remote_sender_id()
	var item := add_message_item_control(p_message)
	item.received(peer_id)
	
	update()



func _on_send_button_pressed() -> void:
	send_chat_message(line_edit.text)


func _on_line_edit_text_submitted(new_text: String) -> void:
	send_chat_message(new_text)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	
	if is_instance_valid(messages_container):
		if not messages_container.is_displaying_from(self):
			messages_container.display_messages(
				message_item_controls,
				self
			)
