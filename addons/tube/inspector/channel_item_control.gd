class_name EditorTubeChannelItemControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.

signal pressed


const MESSAGE_ITEM_CONTROL_SCENE := preload("uid://cfsei3airwx4s")


const STATE_COLOR_DEFAULT := Color.WHITE
const STATE_COLOR := {
	WebRTCDataChannel.STATE_CONNECTING: Color.CYAN,
	WebRTCDataChannel.STATE_OPEN: Color.PALE_GREEN,
	WebRTCDataChannel.STATE_CLOSING: Color.GOLDENROD,
	WebRTCDataChannel.STATE_CLOSED: Color.CRIMSON,
}
const STATE_TEXT_DEFAULT := "Unknown"
const STATE_TEXT := {
	WebRTCDataChannel.STATE_CONNECTING: "Connecting",
	WebRTCDataChannel.STATE_OPEN: "Open",
	WebRTCDataChannel.STATE_CLOSING: "Closing",
	WebRTCDataChannel.STATE_CLOSED: "Closed",
}


@export var channel_control: EditorTubeChannelControl


var peer: TubePeer:
	set(x):
		if null != peer:
			peer.channel_state_changed.disconnect(
				_on_peer_channel_state_changed
			)
		
		if null != x:
			x.channel_state_changed.connect(
				_on_peer_channel_state_changed
			)
		
		peer = x
		update()


var channel: WebRTCDataChannel:
	set(x):
		channel = x
		update()


#var message_item_controls: Array[EditorTubeMessagesItemControl] = []

@onready var name_label: Label = %NameLabel
@onready var state_indicator: Control = %StateIndicator


func _ready() -> void:
	update()


func _on_button_pressed() -> void:
	if is_instance_valid(channel_control):
		channel_control.channel_item = self
	
	pressed.emit()


func update():
	if is_instance_valid(name_label):
		name_label.text = channel.get_label()
	
	if is_instance_valid(state_indicator):
		state_indicator.modulate = STATE_COLOR_DEFAULT if not channel else STATE_COLOR[channel.get_ready_state()]
		state_indicator.tooltip_text = STATE_TEXT_DEFAULT if not channel else STATE_TEXT[channel.get_ready_state()]
	
	if is_instance_valid(channel_control):
		if self == channel_control.channel_item:
			channel_control.update_messages()


func _on_peer_channel_state_changed(_channel: WebRTCDataChannel):
	update()
