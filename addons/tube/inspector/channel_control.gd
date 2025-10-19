class_name EditorTubeChannelControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.


@export var channel_item: EditorTubeChannelItemControl:
	set(x):
		channel_item = x
		show()
		
		if is_instance_valid(id_label):
			id_label.text = str(channel_item.channel.get_id())
		
		if is_instance_valid(label_label):
			label_label.text = channel_item.channel.get_label()
		
		update_messages()


@export var messages_container: EditorTubeMessagesContainer


@onready var id_label: Label = %IdLabel
@onready var label_label: Label = %LabelLabel



func _ready() -> void:
	hide()


func update_messages():
	if null == channel_item:
		return
	
	if is_instance_valid(messages_container):
		messages_container.display_messages(channel_item.message_item_controls)
