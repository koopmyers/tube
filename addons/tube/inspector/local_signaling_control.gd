class_name EditorTubeLocalSignalingControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.


const MESSAGE_ITEM_CONTROL_SCENE := preload("uid://cfsei3airwx4s")


@export var messages_container: EditorTubeMessagesContainer
@export var max_messages_amount: int = 100


var local_signaling_peer: TubeLocalSignalingPeer:
	set(x):
		
		if null != local_signaling_peer:
			local_signaling_peer.warning_raised.disconnect(
				_on_local_signaling_peer_warning_raised
			)
			local_signaling_peer.data_sent.disconnect(
				_on_local_signaling_peer_data_sent
			)
			local_signaling_peer.received_data.disconnect(
				_on_local_signaling_peer_data_received
			)
		
		if null != x:
			x.warning_raised.connect(
				_on_local_signaling_peer_warning_raised
			)
			x.data_sent.connect(
				_on_local_signaling_peer_data_sent
			)
			x.received_data.connect(
				_on_local_signaling_peer_data_received
			)
		
		local_signaling_peer = x
		update()


var message_item_controls: Array[EditorTubeMessagesItemControl] = []
var message_item_button_group := ButtonGroup.new()

@onready var name_label: Label = %NameLabel
#@onready var state_indicator: Control = %StateIndicator


func _ready() -> void:
	message_item_button_group.allow_unpress = true
	update()


func update():
	if is_instance_valid(local_signaling_peer):
	
		if is_instance_valid(name_label):
			name_label.text = str(local_signaling_peer.udp_peer.get_local_port())
		
		if is_instance_valid(messages_container):
			if messages_container.is_displaying_from(self):
				messages_container.display_messages(
					message_item_controls,
					self
				)
	
	else:
		if is_instance_valid(name_label):
			name_label.text = "Unset"


func add_message_item_control(data) -> EditorTubeMessagesItemControl:
	if max_messages_amount <= message_item_controls.size():
		var item := message_item_controls.pop_front()
		item.queue_free()
	
	var message_item_control:= MESSAGE_ITEM_CONTROL_SCENE.instantiate()
	message_item_controls.append(message_item_control)
	message_item_control.data = data
	message_item_control.button_group = message_item_button_group
	return message_item_control


func _on_local_signaling_peer_warning_raised(message: String):
	add_message_item_control(message).warning()
	update()


#func _on_local_signaling_peer_connected():
	#add_message_item_control("Connected").success()
	#update()


#func _on_local_signaling_peer_failed():
	#add_message_item_control(
		#"Connection failed: {error}".format({
			#"error": local_signaling_peer.error_message
		#})
	#).error()
	#update()
#
#
#func _on_local_signaling_peer_disconnected():
	#add_message_item_control("Disconneted")
	#update()
#
#
#func _on_local_signaling_peer_state_changed():
	##if WebSocketPeer.STATE_OPEN == local_signaling_peer.state:
		##add_message_item_control("Connection open")
	#
	#if WebSocketPeer.STATE_CLOSING == local_signaling_peer.state:
		#add_message_item_control("Connection closing")
	#
	##elif WebSocketPeer.STATE_CLOSED == local_signaling_peer.state:
		##add_message_item_control("Connection closed")
	#
	#update()


func _on_local_signaling_peer_data_received(data: Variant, address: String, port: int):
	var control := add_message_item_control(data)
	control.received()
	control.from_address = address
	control.from_id = port
	update()


func _on_local_signaling_peer_data_sent(data: Dictionary, address: String, port: int):
	var control := add_message_item_control(data)
	control.sent()
	control.from_address = address
	control.from_id = port
	update()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	
	if is_instance_valid(messages_container):
		if not messages_container.is_displaying_from(self):
			messages_container.display_messages(
				message_item_controls,
				self
			)
