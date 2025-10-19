class_name EditorTubePeerControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.

const STATE_COLOR_DEFAULT := Color.WHITE
const STATE_TEXT_DEFAULT := "Unknown"


@export var client: TubeClient
@export var peer_item: EditorTubePeerItemControl:
	set(x):
		show()
		
		if peer_item != x:
			latency_label.text = "Unknown..."
			
			if null != peer_item:
				peer_item.updated.disconnect(update)
			
			if null != x:
				x.updated.connect(update)
		
		if null != x:
			if not waiting_for_pong:
				send_ping(x.peer)
		
		if is_instance_valid(messages_container):
			if peer_item != x or not messages_container.is_displaying_from(self):
				messages_container.display_messages(
					x.message_item_controls,
					self
				)
		
		if is_instance_valid(id_label):
			id_label.text = EditorTubePeerItemControl.get_peer_string(x.peer.id)
			id_label.modulate = EditorTubePeerItemControl.get_peer_color(x.peer.id)
		
		if is_instance_valid(channels_containers):
			for child in channels_containers.get_children():
				channels_containers.remove_child(child)
			
			for channel_item_control in x.channel_item_controls:
				channels_containers.add_child(
					channel_item_control
				)
		
		peer_item = x
		update()

@export var messages_container: EditorTubeMessagesContainer


var last_ping_time: float
var waiting_for_pong := false

@onready var ping_timer: Timer = %PingTimer

@onready var id_label: Label = %IdLabel

@onready var connection_state_indicator: Control = %ConnectionStateIndicator
@onready var connection_state_label: Label = %ConnectionStateLabel

@onready var gathering_state_indicator: Control = %GatheringStateIndicator
@onready var gathering_state_label: Label = %GatheringStateLabel

@onready var signaling_state_indicator: Control = %SignalingStateIndicator
@onready var signaling_state_label: Label = %SignalingStateLabel

@onready var channels_containers: Container = %ChannelsContainer

@onready var connection_time_label: Label = %ConnectingTimeLabel
@onready var up_time_label: Label = %UpTimeLabel
@onready var latency_label: Label = %LatencyLabel

@onready var fake_disconnection_timer: Timer = %FakeDisconnectionTimer
@onready var fake_disconnection_button: Button = %FakeDisconnectionButton
@onready var fake_disconnection_spin_box: SpinBox = %FakeDisconnectionSpinBox


func _ready() -> void:
	hide()


func update():
	if is_instance_valid(connection_state_indicator):
		connection_state_indicator.modulate = STATE_COLOR_DEFAULT if not peer_item else peer_item.get_connection_state_color()
	
	if is_instance_valid(connection_state_label):
		connection_state_label.text = STATE_TEXT_DEFAULT if not peer_item else peer_item.get_connection_state_text()
	
	if is_instance_valid(gathering_state_indicator):
		gathering_state_indicator.modulate = STATE_COLOR_DEFAULT if not peer_item else peer_item.get_gathering_state_color()
	
	if is_instance_valid(gathering_state_label):
		gathering_state_label.text = STATE_TEXT_DEFAULT if not peer_item else peer_item.get_gathering_state_text()
	
	if is_instance_valid(signaling_state_indicator):
		signaling_state_indicator.modulate = STATE_COLOR_DEFAULT if not peer_item else peer_item.get_signaling_state_color()
	
	if is_instance_valid(signaling_state_label):
		signaling_state_label.text = STATE_TEXT_DEFAULT if not peer_item else peer_item.get_signaling_state_text()
	
	
	if null == peer_item:
		return
	
	if is_instance_valid(fake_disconnection_button):
		fake_disconnection_button.disabled = not peer_item.peer.is_peer_connected()
	
	if is_instance_valid(messages_container):
		if messages_container.is_displaying_from(self):
			messages_container.display_messages(
				peer_item.message_item_controls,
				self
			)


func add_channel_item_control(channel_item_control: EditorTubeChannelItemControl):
	channels_containers.add_child(channel_item_control)


func send_ping(peer: TubePeer):
	if not peer.is_peer_connected():
		return
	
	
	last_ping_time = Time.get_ticks_msec()
	ping_timer.start(5.0)
	waiting_for_pong = true
	receive_ping.rpc_id(peer.id)


@rpc("any_peer", "call_remote", "reliable")
func receive_ping():
	var sender_id := multiplayer.get_remote_sender_id()
	send_pong(sender_id)


func send_pong(to: int):
	receive_pong.rpc_id(to)


@rpc("any_peer", "call_remote", "reliable")
func receive_pong():
	waiting_for_pong = false
	ping_timer.start(1.0)
	
	var ping := Time.get_ticks_msec() - last_ping_time
	latency_label.text = str(ping).pad_decimals(0)


func _on_ping_timer_timeout() -> void:
	if not is_visible_in_tree():
		return
	
	if not peer_item:
		return
	
	send_ping(peer_item.peer)


func _process(_delta: float) -> void:
	if null == peer_item:
		return
	
	connection_time_label.text = str(
		peer_item.peer.connecting_time
	).pad_decimals(3)
	up_time_label.text = str(
		peer_item.peer.up_time
	).pad_decimals(3)


func _on_fake_disconnection_button_pressed() -> void:
	if not fake_disconnection_timer.is_stopped():
		fake_disconnection_timer.stop()
		fake_disconnection_timer.timeout.emit()
	
	var peer := peer_item.peer
	peer._disconnected()
	
	fake_disconnection_timer.start(
		fake_disconnection_spin_box.value
	)
	await fake_disconnection_timer.timeout
	peer._connected()
