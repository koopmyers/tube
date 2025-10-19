class_name EditorTubeTrackerItemControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.

signal pressed


const MESSAGE_ITEM_CONTROL_SCENE := preload("uid://cfsei3airwx4s")


const STATE_COLOR_DEFAULT := Color.WHITE
const STATE_COLOR := {
	WebSocketPeer.STATE_CONNECTING: Color.CYAN,
	WebSocketPeer.STATE_OPEN: Color.PALE_GREEN,
	WebSocketPeer.STATE_CLOSING: Color.GOLDENROD,
	WebSocketPeer.STATE_CLOSED: Color.CRIMSON,
}
const STATE_TEXT_DEFAULT := "Unknown"
const STATE_TEXT := {
	WebSocketPeer.STATE_CONNECTING: "Connecting",
	WebSocketPeer.STATE_OPEN: "Open",
	WebSocketPeer.STATE_CLOSING: "Closing",
	WebSocketPeer.STATE_CLOSED: "Closed",
}


@export var tracker_control: EditorTubeTrackerControl
@export var max_messages_amount: int = 100


var tracker: TubeTracker:
	set(x):
		
		if null != tracker:
			tracker.warning_raised.disconnect(
				_on_tracker_warning_raised
			)
			tracker.connected.disconnect(
				_on_tracker_connected
			)
			tracker.failed.disconnect(
				_on_tracker_failed
			)
			tracker.disconnected.disconnect(
				_on_tracker_disconnected
			)
			
			tracker.state_changed.disconnect(
				_on_tracker_state_changed
			)
			tracker.data_sent.disconnect(
				_on_tracker_data_sent
			)
			tracker.received_data.disconnect(
				_on_tracker_data_received
			)
		
		if null != x:
			x.warning_raised.connect(
				_on_tracker_warning_raised
			)
			x.connected.connect(
				_on_tracker_connected
			)
			x.failed.connect(
				_on_tracker_failed
			)
			x.disconnected.connect(
				_on_tracker_disconnected
			)
			
			
			x.state_changed.connect(
				_on_tracker_state_changed
			)
			x.data_sent.connect(
				_on_tracker_data_sent
			)
			x.received_data.connect(
				_on_tracker_data_received
			)
		
		tracker = x
		update()


var message_item_controls: Array[EditorTubeMessagesItemControl] = []
var message_item_button_group := ButtonGroup.new()

@onready var name_label: Label = %NameLabel
@onready var state_indicator: Control = %StateIndicator


func _ready() -> void:
	message_item_button_group.allow_unpress = true
	update()


func _on_button_pressed() -> void:
	if is_instance_valid(tracker_control):
		tracker_control.tracker_item = self
	
	pressed.emit()


func update():
	if is_instance_valid(tracker):
	
		if is_instance_valid(name_label):
			name_label.text = tracker.socket.get_requested_url()
		
		if is_instance_valid(state_indicator):
			state_indicator.modulate = STATE_COLOR[tracker.state]
			state_indicator.tooltip_text = STATE_TEXT[tracker.state]
		
		if is_instance_valid(tracker_control):
			if self == tracker_control.tracker_item:
				tracker_control.update_messages()
	
	else:
		if is_instance_valid(name_label):
			name_label.text = "Unset"
		
		if is_instance_valid(state_indicator):
			state_indicator.modulate = STATE_COLOR_DEFAULT
			state_indicator.tooltip_text = STATE_TEXT_DEFAULT
			
	


func add_message_item_control(data) -> EditorTubeMessagesItemControl:
	if max_messages_amount <= message_item_controls.size():
		var item := message_item_controls.pop_front()
		item.queue_free()
	
	var message_item_control := MESSAGE_ITEM_CONTROL_SCENE.instantiate()
	message_item_controls.append(message_item_control)
	message_item_control.data = data
	message_item_control.button_group = message_item_button_group
	return message_item_control


func _on_tracker_warning_raised(message: String):
	add_message_item_control(message).warning()
	update()


func _on_tracker_connected():
	add_message_item_control("Connected").success()
	update()


func _on_tracker_failed():
	add_message_item_control(
		"Connection failed: {error}".format({
			"error": tracker.error_message
		})
	).error()
	update()


func _on_tracker_disconnected():
	add_message_item_control("Disconneted")
	update()


func _on_tracker_state_changed():
	#if WebSocketPeer.STATE_OPEN == tracker.state:
		#add_message_item_control("Connection open")
	
	if WebSocketPeer.STATE_CLOSING == tracker.state:
		add_message_item_control("Connection closing")
	
	#elif WebSocketPeer.STATE_CLOSED == tracker.state:
		#add_message_item_control("Connection closed")
	
	update()


func _on_tracker_data_received(data: Dictionary):
	add_message_item_control(data).received()
	update()


func _on_tracker_data_sent(data: Dictionary):
	add_message_item_control(data).sent()
	update()
