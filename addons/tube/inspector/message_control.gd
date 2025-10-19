class_name EditorTubeMessageControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.

var message_item_control: EditorTubeMessagesItemControl:
	set(x):
		message_item_control = x
		
		if null == message_item_control:
			hide()
			return
		
		show()
		
		if is_instance_valid(type_texture_rect):
			type_texture_rect.texture = message_item_control.icons.get(message_item_control.type)
			type_texture_rect.modulate = message_item_control.colors.get(message_item_control.type)
		
		if is_instance_valid(time_label):
			time_label.text = message_item_control.time
		
		if is_instance_valid(from_label):
			from_label.visible = bool(message_item_control.from_id)
			from_label.text = EditorTubePeerItemControl.get_peer_string(
				message_item_control.from_id
			)
			from_label.modulate = EditorTubePeerItemControl.get_peer_color(
				message_item_control.from_id
			)
		
		if is_instance_valid(message_code_edit):
			if message_item_control.data is String:
				message_code_edit.text = message_item_control.data
			
			if not message_item_control.data is String:
				message_code_edit.text = JSON.stringify(message_item_control.data, "    ")


@onready var type_texture_rect: TextureRect = %TypeTextureRect
@onready var time_label: Label = %TimeLabel
@onready var from_label: Label = %FromLabel
@onready var message_code_edit: CodeEdit = %MessageCodeEdit


func _ready() -> void:
	hide()


func _on_clipboard_button_pressed() -> void:
	DisplayServer.clipboard_set(str(message_item_control.data))
