class_name EditorTubePeerItemControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.

signal pressed
signal updated

const MESSAGE_ITEM_CONTROL_SCENE := preload("uid://cfsei3airwx4s")
const CHANNEL_ITEM_CONTROL_SCENE := preload("uid://dc3ssinymllca")

const STATE_COLOR_DEFAULT := Color.WHITE
const STATE_TEXT_DEFAULT := "Unknown"

const CONNECTION_STATE_COLOR := {
	WebRTCPeerConnection.STATE_NEW: Color.BEIGE,
	WebRTCPeerConnection.STATE_CONNECTING: Color.CYAN,
	WebRTCPeerConnection.STATE_CONNECTED: Color.PALE_GREEN,
	WebRTCPeerConnection.STATE_DISCONNECTED: Color.CYAN,
	WebRTCPeerConnection.STATE_FAILED: Color.GOLDENROD,
	WebRTCPeerConnection.STATE_CLOSED: Color.CRIMSON,
}
const CONNECTION_STATE_TEXT := {
	WebRTCPeerConnection.STATE_NEW: "New",
	WebRTCPeerConnection.STATE_CONNECTING: "Connecting",
	WebRTCPeerConnection.STATE_CONNECTED: "Connected",
	WebRTCPeerConnection.STATE_DISCONNECTED: 'Disconnected',
	WebRTCPeerConnection.STATE_FAILED: "Failed",
	WebRTCPeerConnection.STATE_CLOSED: "Closed",
}


const GATHERING_STATE_COLOR := {
	WebRTCPeerConnection.GATHERING_STATE_NEW: Color.BEIGE,
	WebRTCPeerConnection.GATHERING_STATE_GATHERING: Color.CYAN,
	WebRTCPeerConnection.GATHERING_STATE_COMPLETE: Color.PALE_GREEN,
}
const GATHERING_STATE_TEXT := {
	WebRTCPeerConnection.GATHERING_STATE_NEW: "New",
	WebRTCPeerConnection.GATHERING_STATE_GATHERING: "Gathering",
	WebRTCPeerConnection.GATHERING_STATE_COMPLETE: "Complete",
}


const SIGNALING_STATE_COLOR := {
	WebRTCPeerConnection.SIGNALING_STATE_STABLE: Color.PALE_GREEN,
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_LOCAL_OFFER: Color.CYAN, 
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_REMOTE_OFFER: Color.CYAN,
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_LOCAL_PRANSWER: Color.CYAN,
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_REMOTE_PRANSWER: Color.CYAN,
	WebRTCPeerConnection.SIGNALING_STATE_CLOSED: Color.CRIMSON,
}
const SIGNALING_STATE_TEXT := {
	WebRTCPeerConnection.SIGNALING_STATE_STABLE: "Stable",
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_LOCAL_OFFER: "Have local offer", 
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_REMOTE_OFFER: "Have remote offer",
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_LOCAL_PRANSWER: "Have local answer",
	WebRTCPeerConnection.SIGNALING_STATE_HAVE_REMOTE_PRANSWER: "Have remote answer",
	WebRTCPeerConnection.SIGNALING_STATE_CLOSED: "Closed",
}


@export var peer_control: EditorTubePeerControl
@export var channel_control: EditorTubeChannelControl

@export var client: TubeClient # to call kick
@export var max_messages_amount: int = 100

var peer: TubePeer:
	set(x):
		
		if null != peer:
			peer.warning_raised.disconnect(
				_on_peer_warning_raised
			)
			peer.failed.disconnect(
				_on_peer_failed
			)
			peer.connected.disconnect(
				_on_peer_connected
			)
			peer.disconnected.disconnect(
				_on_peer_disconnected
			)
			
			peer.signaling_readied.disconnect(
				_on_peer_signaling_readied
			)
			peer.signaling_timeout.disconnect(
				_on_peer_signaling_timeout
			)
			
			peer.connection_state_changed.disconnect(
				_on_peer_connection_state_changed
			)
			peer.port_mapped.disconnect(
				_on_peer_port_mapped
			)
			peer.channel_initiated.disconnect(
				_on_peer_channel_initiated
			)
			
			peer.session_description_created.disconnect(
				_on_peer_session_description_created
			)
			peer.ice_candidate_created.disconnect(
				_on_peer_ice_candidate_created
			)
			peer.remote_description_setted.disconnect(
				_on_peer_remote_description_setted
			)
			peer.ice_candidate_added.disconnect(
				_on_peer_ice_candidate_added
			)
		
		if null != x:
			x.warning_raised.connect(
				_on_peer_warning_raised
			)
			x.failed.connect(
				_on_peer_failed
			)
			x.connected.connect(
				_on_peer_connected
			)
			x.disconnected.connect(
				_on_peer_disconnected
			)
			
			x.signaling_readied.connect(
				_on_peer_signaling_readied
			)
			x.signaling_timeout.connect(
				_on_peer_signaling_timeout
			)
			
			x.connection_state_changed.connect(
				_on_peer_connection_state_changed
			)
			x.port_mapped.connect(
				_on_peer_port_mapped
			)
			x.channel_initiated.connect(
				_on_peer_channel_initiated
			)
			
			x.session_description_created.connect(
				_on_peer_session_description_created
			)
			x.ice_candidate_created.connect(
				_on_peer_ice_candidate_created
			)
			x.remote_description_setted.connect(
				_on_peer_remote_description_setted
			)
			x.ice_candidate_added.connect(
				_on_peer_ice_candidate_added
			)
		
		peer = x
		update()


var message_item_controls: Array[EditorTubeMessagesItemControl] = []
var message_item_button_group := ButtonGroup.new()

var channel_item_controls: Array[EditorTubeChannelItemControl] = []

@onready var name_label: Label = %NameLabel
@onready var state_indicator: Control = %StateIndicator
@onready var kick_button: Button = %KickButton


func _ready() -> void:
	message_item_button_group.allow_unpress = true
	update()


static var peers_color: Dictionary[int, Color] = {}
static func get_peer_color(p_peer_id: int) -> Color:
	if 0 == p_peer_id:
		return Color.BLACK
	
	if 1 == p_peer_id:
		return Color.WHITE
	
	if peers_color.has(p_peer_id):
		return peers_color[p_peer_id]
	
	var rng := RandomNumberGenerator.new()
	rng.seed = p_peer_id
	var color := Color.from_hsv(
		rng.randf_range(0.4, 0.9), 
		rng.randf_range(0.4, 0.8), 
		rng.randf_range(0.9, 1.0), 
		1.0
	)
	
	peers_color[p_peer_id] = color
	
	return color


static func get_peer_string(p_peer_id: int) -> String:
	if 0 == p_peer_id:
		return ""
	
	if 1 == p_peer_id:
		return "1 (Server)"
	
	return str(p_peer_id)


func get_connection_state_color() -> Color:
	return STATE_COLOR_DEFAULT if not peer else CONNECTION_STATE_COLOR[peer.connection_state]

func get_connection_state_text() -> String:
	return STATE_TEXT_DEFAULT if not peer else CONNECTION_STATE_TEXT[peer.connection_state]


func get_gathering_state_color() -> Color:
	return STATE_COLOR_DEFAULT if not peer else GATHERING_STATE_COLOR[peer.gathering_state]

func get_gathering_state_text() -> String:
	return STATE_TEXT_DEFAULT if not peer else GATHERING_STATE_TEXT[peer.gathering_state]
	

func get_signaling_state_color() -> Color:
	return STATE_COLOR_DEFAULT if not peer else SIGNALING_STATE_COLOR[peer.signaling_state]


func get_signaling_state_text() -> String:
	return STATE_TEXT_DEFAULT if not peer else SIGNALING_STATE_TEXT[peer.signaling_state]


func _on_button_pressed() -> void:
	if is_instance_valid(peer_control):
		peer_control.peer_item = self
	
	pressed.emit()


func _on_kick_button_pressed() -> void:
	client.kick_peer(peer.id)


func update():
	if null == peer:
		return
	
	if is_instance_valid(name_label):
		name_label.text = get_peer_string(peer.id)
		name_label.modulate = get_peer_color(peer.id)
	
	if is_instance_valid(state_indicator):
		state_indicator.modulate = get_connection_state_color()
		state_indicator.tooltip_text = get_connection_state_text()
	
	if is_instance_valid(peer_control):
		if self == peer_control.peer_item:
			peer_control.update()
	
	if is_instance_valid(kick_button):
		if client:
			kick_button.visible = client.is_server
	
	updated.emit()


func add_message_item_control(data) -> EditorTubeMessagesItemControl:
	if max_messages_amount <= message_item_controls.size():
		var item := message_item_controls.pop_front()
		item.queue_free()
	
	var message_item_control := MESSAGE_ITEM_CONTROL_SCENE.instantiate()
	message_item_controls.append(message_item_control)
	message_item_control.data = data
	message_item_control.button_group = message_item_button_group
	return message_item_control


func add_channel_item_control(channel: WebRTCDataChannel):
	var channel_item_control := CHANNEL_ITEM_CONTROL_SCENE.instantiate()
	channel_item_controls.append(channel_item_control)
	
	channel_item_control.peer = peer
	channel_item_control.channel = channel
	channel_item_control.channel_control = channel_control
	
	if is_instance_valid(peer_control):
		if peer_control.peer_item == self:
			peer_control.add_channel_item_control(
				channel_item_control
			)


func _on_peer_warning_raised(message: String):
	add_message_item_control(message).warning()
	update()


func _on_peer_connected():
	add_message_item_control("Connected").success()
	update()


func _on_peer_failed():
	add_message_item_control("Connection failed: {error}".format({
		"error": peer.error_message
	})).error()
	update()


func _on_peer_disconnected():
	add_message_item_control("Disconnected")
	update()


func _on_peer_signaling_readied():
	add_message_item_control("Signaling ready")
	update()


func _on_peer_signaling_timeout():
	add_message_item_control("Signaling timeout").warning()
	update()


func _on_peer_connection_state_changed():
	add_message_item_control("State changed to {connection}/{gathering}/{signaling}".format({
		"connection": get_connection_state_text(),
		"gathering": get_gathering_state_text(),
		"signaling": get_signaling_state_text(),
	}))
	
	update()


func _on_peer_channel_initiated(p_channel: WebRTCDataChannel):
	add_channel_item_control(p_channel)
	add_message_item_control(
		"Channel {label} initiated".format({
			"label": p_channel.get_label(),
		})
	)
	update()


func _on_peer_port_mapped(public_port: int, local_port: int):
	add_message_item_control(
		"Port {port} mapped to internal port {internal_port}".format({
			"port": public_port,
			"internal_port": local_port
		})
	)
	update()


func _on_peer_session_description_created(): # local
	add_message_item_control(
		"Session description created: {description}".format({
			"description": peer.local_session_description
		})
	)
	update()


func _on_peer_ice_candidate_created(): # local
	add_message_item_control(
		"Ice candidate created: {candidate}".format({
			"candidate": peer.ice_candidates[-1]
		})
	)
	update()


func _on_peer_remote_description_setted():
	add_message_item_control(
		"Remote session description setted: {description}".format({
			"description": peer.remote_session_description
		})
	)
	update()


func _on_peer_ice_candidate_added(ice_candidate: Dictionary): # remote
	add_message_item_control(
		"Ice candidate added: {candidate}".format({
			"candidate": ice_candidate
		})
	)
	update()
