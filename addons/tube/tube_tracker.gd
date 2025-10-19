class_name TubeTracker extends RefCounted


const MAX_INTERVAL := 120.0 #sec


signal failed
signal connected
signal disconnected
signal received_answer(data: Dictionary)
signal interval_timeout


signal warning_raised(message: String)
signal state_changed

signal data_sent(data: Dictionary)
signal received_data(data: Dictionary)


const CLOSE_CODE_CLIENT: int = 3001
const CLOSE_CODE_FAILED: int = 3002
# https://developer.mozilla.org/en-US/docs/Web/API/WebSocket/close, custom code 3000-4999
# https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4.1


var error_message: String
var socket := WebSocketPeer.new()
var state := socket.get_ready_state()

var connecting_time: float = 0.0 #sec
var up_time: float = 0.0 #sec
var interval_time: float = 0.0 #sec
var interval_time_left: float = -1.0


func _to_string() -> String:
	var string := socket.get_requested_url()
	
	if "Web" != OS.get_name():
		if WebSocketPeer.STATE_OPEN == socket.get_ready_state():
			string += "({protocol}://{address}:{port})".format({
				"protocol": socket.get_selected_protocol(),
				"address": socket.get_connected_host(),
				"port": socket.get_connected_port(),
			})
	
	return string


func raise_warning(message: String):
	push_warning(message)
	warning_raised.emit(message)


func connect_to_url(p_url: String) -> Error:
	var error := socket.connect_to_url(p_url)
	if error:
		error_message = "connection failed: {error}".format({
			"error": error_string(error) 
		})
		failed.emit()
	
	return error


func is_open() -> bool:
	return WebSocketPeer.STATE_OPEN == socket.get_ready_state()


func is_close() -> bool:
	return WebSocketPeer.STATE_CLOSED == socket.get_ready_state()


func close(p_info_hash: String, p_peer_id_hash: String):
	if is_open():
		send_stop(
			p_info_hash,
			p_peer_id_hash
		)
	
	if not is_close():
		socket.close(
			CLOSE_CODE_CLIENT,
			"Close by client",
		)


func _socket_connection_opened():
	connected.emit()


func _socket_connection_closed(p_code: int, p_reason: String):
	#if -1 == p_code: # error
	
	if WebSocketPeer.State.STATE_CONNECTING == state:
		error_message = "connection impossible"
	
	p_reason = p_reason if p_reason else "Closed unexpectedly, code: {code}".format({
		"code": p_code,
	})
	
	if WebSocketPeer.State.STATE_OPEN == state:
		error_message = "connection failed: {reason}".format({
			"reason": p_reason,
		})
	
	disconnected.emit()


## Encodes tracker packet data as JSON string.
func encode_data(data: Dictionary) -> String:
	var json := JSON.stringify(data)
	return json


## Decodes tracker packet data from a [PackedByteArray].
func decode_packet(p_packet: PackedByteArray) -> Variant:
	var string := p_packet.get_string_from_utf8()
	var data = JSON.parse_string(string)
	return data


func send_data(p_data: Dictionary) -> Error:
	var text := encode_data(p_data)
	var error := socket.send_text(
		text
	)
	
	if error:
		raise_warning(
			"Cannot send text: {error}".format({
			"error": error_string(error)
		}))
	
	else:
		data_sent.emit(p_data)
	
	return error


func send_announce(p_info_hash: String, p_peer_id_hash: String) -> Error:
	return send_data({
		"action": "announce",
		"info_hash": p_info_hash,
		"peer_id": p_peer_id_hash,
		
		"uploaded": 0,
		"downloaded": 0,
	})


func send_answer(
	p_info_hash: String,
	p_peer_id_hash: String,
	p_to_peer_id_hash: String,
	description: Dictionary,
	ice_candidates: Array
) -> Error:
	return send_data({
		"action": "announce",
		"info_hash": p_info_hash,
		"peer_id": p_peer_id_hash,
		
		"to_peer_id": p_to_peer_id_hash,
		"answer": {
			"type": description.type,
			"sdp": description.sdp,
			"ice_candidates": ice_candidates,
		},
		"offer_id": "0",
	})


func send_stop(p_info_hash: String, p_peer_id_hash: String) -> Error:
	return send_data({
	  "action": "announce",
	  "info_hash": p_info_hash,
	  "peer_id": p_peer_id_hash,
	  "event": "stopped"
	})


func _received_packet(p_packet: PackedByteArray):
	var data = decode_packet(p_packet)
	if not data is Dictionary:
		raise_warning("Received invalid packet: {packet}".format({
			"packet": str(p_packet)
		}))
		return
	
	received_data.emit(data)
	if data.has("answer"):
		_handle_answer(data)
		return
	
	_handle_announce(data)


func _handle_announce(p_data: Dictionary):
	if not p_data.has("interval"):
		raise_warning("announce data has no interval")
		return
	
	if not p_data.interval is float:
		raise_warning("interval invalid data type")
		return
	
	interval_time = min(p_data.interval, MAX_INTERVAL)
	interval_time_left = interval_time


func _handle_answer(p_data: Dictionary):
	if not p_data is Dictionary:
		raise_warning("answer data invalid data type")
		return
	
	if not p_data.has("peer_id"):
		raise_warning("answer data has no peer_id")
		return
	
	if not p_data.peer_id is String:
		raise_warning("peer_id invalid data type")
		return
	
	if not p_data.has("answer"):
		raise_warning("answer data has no answer")
		return
	
	if not p_data.answer is Dictionary:
		raise_warning("answer invalid data type")
		return
	
	var answer: Dictionary = p_data.answer
	if not answer.has("sdp"):
		raise_warning("answer data has no sdp")
	
	if not answer.sdp is String:
		raise_warning("sdp invalid data type")
		return
	
	if not answer.has("type"):
		raise_warning("answer data has no type")
		return
	
	if not answer.type is String:
		raise_warning("type invalid data type")
		return
	
	if not answer.has("ice_candidates"):
		raise_warning("answer data has no ice_candidates")
		return
	
	if not answer.ice_candidates is Array:
		raise_warning("ice_candidates invalid data type")
		return
	
	received_answer.emit(p_data)


static func get_peer_id_hash_from_answer_data(p_data: Dictionary) -> String:
	return p_data.peer_id


static func get_type_from_answer_data(p_data: Dictionary) -> String:
	return p_data.answer.type


static func get_sdp_from_answer_data(p_data: Dictionary) -> String:
	return p_data.answer.sdp


static func get_ice_candidates_from_answer_data(p_data: Dictionary) -> Array:
	return p_data.answer.ice_candidates


static func is_ice_candidate_data_valid(p_data: Variant) -> bool:
	if not p_data is Dictionary:
		push_error("Ice candidate data invalid data type")
		return false
	
	if not p_data.has("media"):
		push_error("Ice candidate data has no media")
		return false
	
	if not p_data.media is String:
		push_error("media invalid data type")
		return false
	
	if not p_data.has("index"):
		push_error("Ice candidate has no index")
		return false
	
	if not (typeof(p_data.index) in [TYPE_INT, TYPE_FLOAT]):
		push_error("index invalid data type")
		return false
	
	if not p_data.has("sdp"):
		push_error("Ice candidate has no sdp")
		return false
	
	if not p_data.sdp is String:
		push_error("Ice candidate sdp invalid data type")
		return false
	
	return true


static func get_media_from_ice_candidate_data(p_data: Dictionary) -> String:
	return p_data.media


static func get_index_from_ice_candidate_data(p_data: Dictionary) -> int:
	return int(p_data.index)


static func get_sdp_from_ice_candidate_data(p_data: Dictionary) -> String:
	return p_data.sdp


func _process(delta: float):
	socket.poll() # push error when 502 bad gateway, doesn't block anything
	
	var old_state := state
	state = socket.get_ready_state()
	if state != old_state:
		state_changed.emit()
	
	
	if WebSocketPeer.STATE_CONNECTING == state:
		connecting_time += delta
	
	if WebSocketPeer.STATE_OPEN == state:
		if WebSocketPeer.STATE_OPEN != old_state:
			_socket_connection_opened()
		
		while socket.get_available_packet_count():
			var packet := socket.get_packet()
			_received_packet(packet)
		
		up_time += delta
		
		if 0.0 < interval_time:
			interval_time_left -= delta
			if interval_time_left < 0.0:
				interval_time_left = interval_time
				interval_timeout.emit()
	
	
	elif WebSocketPeer.STATE_CLOSING == state:
		# Keep polling to achieve proper close.
		pass
	
	elif WebSocketPeer.STATE_CLOSED == state:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		_socket_connection_closed(code, reason)
	
	#
	#if WebRTCPeerConnection.STATE_CONNECTED == connection_state:
			#
