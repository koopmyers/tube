class_name TubePeer extends WebRTCPeerConnectionExtension


signal signaling_readied
signal signaling_timeout
signal connected
signal disconnected
signal failed
signal closed

signal warning_raised(message: String)

signal connection_state_changed
#signal session_description_created # local
#signal ice_candidate_created # local
signal remote_description_setted
signal ice_candidate_added(ice_candidate: Dictionary) # remote
signal port_mapped(public_port: int, local_port: int)

signal channel_initiated(channel: WebRTCDataChannel)
signal channel_state_changed(channel: WebRTCDataChannel)



class WebRTCSdp extends RefCounted:
	
	var foundation: String
	var component: String
	var protocol: String
	var priority: int
	var ip: String
	var port: int
	var type: String
	var related_address: String
	var related_port: int
	var tcp_type: String
	
	
	func _init(line: String) -> void:
		var parts: Array
		if line.begins_with("a=candidate:"):
			parts = line.substr(12, line.length()).split(" ")
		else:
			parts = line.substr(10, line.length()).split(" ")

		var related_address: String = ""
		var related_port: int = -1
		var tcp_type: String = ""

		var i := 8
		while i < parts.size():
			match parts[i]:
				"raddr":
					related_address = parts[i + 1]
				"rport":
					related_port = int(parts[i + 1])
				"tcptype":
					tcp_type = parts[i + 1]
				_:
					# Unknown extensions are ignored
					pass
			i += 2
		
		foundation = parts[0]
		component = parts[1]
		protocol = parts[2].to_lower()
		priority = int(parts[3])
		ip = parts[4]
		port = int(parts[5])
		type = parts[7]
		related_address = related_address
		related_port = related_port
		tcp_type = tcp_type


var id: int

var valid := true
var error_message: String

var connection := WebRTCPeerConnection.new()
var connection_state := connection.get_connection_state()
var gathering_state := connection.get_gathering_state()
var signaling_state := connection.get_signaling_state()

var signaling_time: float = -1.0
var signaling_timeout_time: float = 1.0

var signaling_attempts: int = 0
var signaling_max_attempts: int = 3

var connecting_time: float = 0.0
var up_time: float = 0.0

var local_address: String
var local_session_description := {} 
var remote_session_description := {}
var ice_candidates: Array[Dictionary] = []
var has_joined_session := false # set by client

var pending_public_ports: Array[int] = []
var local_ports: Array[int] = []
var mapped_ports: Dictionary[int, int] = {} # public to local

var channel_states: Dictionary[WebRTCDataChannel, WebRTCDataChannel.ChannelState] = {}


func _init(p_peer_id: int) -> void:
	id = p_peer_id
	#client = p_client
	connection_state = connection.get_connection_state()
	gathering_state = connection.get_gathering_state()
	signaling_state = connection.get_signaling_state()
	
	connection.session_description_created.connect(
		set_local_description
	)
	connection.ice_candidate_created.connect(
		_on_ice_candidate_created
	)


func raise_warning(message: String):
	push_warning(message)
	warning_raised.emit(message)


func _initialize(p_config: Dictionary) -> Error:
	var error := connection.initialize(p_config)
	if error:
		valid = false
		error_message = "cannot initialize peer: {error}".format({
			"error": error_string(error)
		})
		failed.emit()
	
	return error


func _get_connection_state() -> WebRTCPeerConnection.ConnectionState:
	var state := connection.get_connection_state()
	if state == WebRTCPeerConnection.STATE_DISCONNECTED:
		# WebRTC Connection can be temporary disconnected and will automaticaly reconnect quickly. But for godot, disconnected is putting a end to the connection. We don't want that so we tell godot that it is still connected. If does not reconnect, state will be FAILED and handle as real disconnection by Tube and Godot.
		# It looks like when using reliable channel, while DISCONNECTED, message will be received on reconnection.
		return WebRTCPeerConnection.STATE_CONNECTED
	
	return state


func _get_gathering_state() -> WebRTCPeerConnection.GatheringState:
	return connection.get_gathering_state()


func _get_signaling_state() -> WebRTCPeerConnection.SignalingState:
	return connection.get_signaling_state()


func _create_data_channel(p_label: String, p_config: Dictionary) -> WebRTCDataChannel:
	var channel := connection.create_data_channel(p_label, p_config)
	channel_states[channel] = channel.get_ready_state()
	channel_initiated.emit(channel)
	return channel


func _create_offer() -> Error:
	var error = connection.create_offer()
	if error:
		valid = false
		error_message = "cannot create offer: {error}".format({
			"error": error_string(error)
		})
		failed.emit()
	
	return error


func _set_local_description(p_type: String, p_sdp: String):
	var error := connection.set_local_description(p_type, p_sdp)
	if error:
		error_message = "cannot set local description: {error}".format({
			"error": error_string(error)
		})
		failed.emit()
		return error
	
	local_session_description = {
		"type": p_type,
		"sdp": p_sdp,
	}
	session_description_created.emit()
	
	if is_signaling_ready() and not is_attempting_connection():
		match_remaining_ports()
		signaling_readied.emit()
	
	return error


func _on_ice_candidate_created(p_media: String, p_index: int, p_sdp: String):
	ice_candidates.append({
		"media": p_media,
		"index": p_index,
		"sdp": p_sdp,
	})
	
	var sdp_parsed := WebRTCSdp.new(p_sdp)
	
	if "udp" == sdp_parsed.protocol:
		if "host" == sdp_parsed.type:
			if not local_ports.has(sdp_parsed.port):
				local_ports.append(sdp_parsed.port)
		
		elif "srflx" == sdp_parsed.type:
			if not mapped_ports.has(sdp_parsed.port):
				if not pending_public_ports.has(sdp_parsed.port):
					pending_public_ports.append(sdp_parsed.port)
		
			if sdp_parsed.related_port != 0:
				mapped_ports[sdp_parsed.port] = sdp_parsed.related_port
				port_mapped.emit(sdp_parsed.port, sdp_parsed.related_port)
				pending_public_ports.erase(sdp_parsed.port)
		
		match_ports()
	
	
	ice_candidate_created.emit()
	
	if is_signaling_ready() and not is_attempting_connection():
		match_remaining_ports()
		signaling_readied.emit()


func _set_remote_description(p_type: String, p_sdp: String) -> Error:
	var error := connection.set_remote_description(p_type, p_sdp)
	if error:
		raise_warning(
			"Cannot set remote description: {error}".format({
			"error": error_string(error) 
		}))
		return error
	
	remote_session_description = {
		"type": p_type,
		"sdp": p_sdp,
	}
	remote_description_setted.emit()
	return error


func _add_ice_candidate(media: String, index: int, name: String) -> Error:
	var error = connection.add_ice_candidate(
		media,
		index,
		name,
	)
	
	if error:
		raise_warning(
			"Cannot add ice candidate: {error}".format({
				"error": error_string(error)
		}))
		return error
	
	ice_candidate_added.emit({
		"media": media,
		"index": index,
		"name": name,
	})
	
	return error


func _poll() -> Error:
	return connection.poll()


func _close() -> void:
	valid = false
	if WebRTCPeerConnection.STATE_CLOSED != connection.get_connection_state():
		connection.close()


func is_signaling_ready() -> bool:
	if WebRTCPeerConnection.STATE_CONNECTING != connection.get_connection_state(): # already connected, do nothing
		return false
	
	#if is_attempting_connection(): # already signaling
		#return false
	
	if local_session_description.is_empty():
		return false
	
	if ice_candidates.is_empty():
		return false
	
	return WebRTCPeerConnection.GATHERING_STATE_COMPLETE == connection.get_gathering_state()


func start_connection_attempt():
	if is_attempting_connection(): # already started
		return
	
	signaling_time = 0.0
	signaling_attempts += 1


func is_attempting_connection():
	return 0.0 <= signaling_time


func _signaling_timeout():
	if signaling_max_attempts <= signaling_attempts:
		stop_connection_attempts()
		error_message = "max connection attempts reached"
		failed.emit()
		return
	
	signaling_time = -1.0
	signaling_timeout.emit()


func stop_connection_attempts():
	signaling_time = -1.0


func is_peer_connected() -> bool: # is_connected is use for signals
	return WebRTCPeerConnection.STATE_CONNECTED == connection_state


func update_connection_state() -> bool: #changed
	var previous := connection_state
	connection_state = connection.get_connection_state()
	return previous != connection_state


func update_gathering_state() -> bool: #changed
	var previous := gathering_state
	gathering_state = connection.get_gathering_state()
	return previous != gathering_state


func update_signaling_state() -> bool: #changed
	var previous := signaling_state
	signaling_state = connection.get_signaling_state()
	return previous != signaling_state


func match_ports():
	for port in pending_public_ports:
		if local_ports.has(port):
			mapped_ports[port] = port
			port_mapped.emit(port, port)
	
	for port in mapped_ports:
		if pending_public_ports.has(port):
			pending_public_ports.erase(port)


func match_remaining_ports():
	match_ports()
	if local_ports.is_empty():
		return
	
	var port := local_ports[0]
	for i_port in pending_public_ports:
		mapped_ports[i_port] = port
		port_mapped.emit(i_port, port)
	
	for i_port in mapped_ports:
		if pending_public_ports.has(port):
			pending_public_ports.erase(port)


func _connected():
	stop_connection_attempts()
	connected.emit()


func _disconnected():
	stop_connection_attempts()
	disconnected.emit()


func _connection_failed():
	stop_connection_attempts()
	error_message = "connection failed"
	failed.emit()


func _connection_closed():
	stop_connection_attempts()
	closed.emit()


func _process(delta: float):
	
	# State
	var connection_changed := update_connection_state()
	var gathering_changed := update_gathering_state()
	var signaling_changed := update_signaling_state()
	if connection_changed or gathering_changed or signaling_changed:
		connection_state_changed.emit()
	
	# Channel
	for channel in channel_states:
		_process_channel(channel)
	
	
	# Connections
	if connection_changed:
		
		if WebRTCPeerConnection.STATE_NEW == connection_state:
			pass
		
		if WebRTCPeerConnection.STATE_CONNECTING == connection_state:
			pass
		
		if WebRTCPeerConnection.STATE_CONNECTED == connection_state:
			_connected()
		
		if WebRTCPeerConnection.STATE_DISCONNECTED == connection_state:
			_disconnected()
		
		if WebRTCPeerConnection.STATE_FAILED == connection_state:
			_connection_failed()
		
		if WebRTCPeerConnection.STATE_CLOSED == connection_state:
			_connection_closed()
		
	
	if gathering_changed or signaling_changed:
		if is_signaling_ready() and not is_attempting_connection():
			match_remaining_ports()
			signaling_readied.emit()
	
	
	# Times
	if is_attempting_connection():
		signaling_time += delta
		if signaling_timeout_time < signaling_time:
			_signaling_timeout()
	
	if WebRTCPeerConnection.STATE_CONNECTING == connection_state:
			connecting_time += delta
	
	if WebRTCPeerConnection.STATE_CONNECTED == connection_state:
			up_time += delta


func _process_channel(p_channel: WebRTCDataChannel) -> WebRTCDataChannel.ChannelState:
		var current_state:= p_channel.get_ready_state()
		var old_state := channel_states[p_channel]
		channel_states[p_channel] = current_state
		if old_state != current_state:
			channel_state_changed.emit(
				p_channel
			)
		
		return current_state
