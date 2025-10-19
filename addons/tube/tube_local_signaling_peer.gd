class_name TubeLocalSignalingPeer extends RefCounted


const BROADCAST_ADDRESS := "255.255.255.255"
const MIN_PORT := 49152
const MAX_PORT := 65535
const PORT_RANGE := MAX_PORT - MIN_PORT


signal received_signaling_data(data: Dictionary, address: String)


signal warning_raised(message: String)
signal data_sent(data: Dictionary, address: String, port:  int)
signal received_data(data: Variant, address: String, port: int)


var udp_peer := PacketPeerUDP.new()
var port: int


static func is_local_signaling_available() -> bool:
	return OS.get_name() != "Web"


func raise_warning(message: String):
	push_warning(message)
	warning_raised.emit(message)


func bind(
	p_app_id: String,
 	p_session_id: String,
	p_peer_id: int
) -> Error:
	
	port = get_port(
		p_app_id,
 		p_session_id,
		p_peer_id
	)
	
	var error := udp_peer.bind(port)
	if error:
		raise_warning(
			"Cannot set bind to port {port}: {error}".format({
				"port": port,
				"error": error_string(error)
		}))
		udp_peer.close()
	
	return error


func is_bound() -> bool:
	return udp_peer.is_bound()


func close():
	udp_peer.close()


func get_port(
	p_app_id: String,
 	p_session_id: String,
	p_peer_id: int
) -> int:
	
	return (p_app_id.hash() + p_session_id.hash() + p_peer_id)%PORT_RANGE + MIN_PORT


## Encodes tracker packet data as JSON string.
func encode_data(data: Dictionary) -> PackedByteArray:
	var json := JSON.stringify(data)
	return json.to_utf8_buffer()


## Decodes tracker packet data from a [PackedByteArray].
func decode_packet(p_packet: PackedByteArray) -> Variant:
	var string := p_packet.get_string_from_utf8()
	var data = JSON.parse_string(string)
	if null == data:
		return string
	
	return data


func broadcast_signaling_data(
	p_app_id: String,
	p_session_id: String,
	p_peer_id: int,
	p_to_peer_id: int,
	description: Dictionary,
	ice_candidates: Array
) -> Error:
	var data := {
		"app_id": p_app_id,
		"session_id": p_session_id,
		"peer_id": p_peer_id,
		"type": description.type,
		"sdp": description.sdp,
		"ice_candidates": ice_candidates,
	}
	
	var destination_port := get_port(
		p_app_id,
		p_session_id,
		1, # Server peer_id
	)
	
	udp_peer.set_broadcast_enabled(true)
	var error := udp_peer.set_dest_address(
		BROADCAST_ADDRESS,
		destination_port
	)
	if error:
		raise_warning(
			"Cannot set destination address to {address}: {error}".format({
				"address": BROADCAST_ADDRESS,
				"error": error_string(error)
		}))
		return error
	
	error = udp_peer.put_packet(encode_data(data))
	if error:
		raise_warning(
			"Cannot send packet to {address}: {error}".format({
				"address": BROADCAST_ADDRESS,
				"error": error_string(error)
		}))
		return error
	
	data_sent.emit(
		data,
		BROADCAST_ADDRESS,
		destination_port
	)
	return error


func send_signaling_data(
	p_address: String,
	p_app_id: String,
	p_session_id: String,
	p_peer_id: int,
	p_to_peer_id: int,
	description: Dictionary,
	ice_candidates: Array
) -> Error:
	var data := {
		"app_id": p_app_id,
		"session_id": p_session_id,
		"peer_id": p_peer_id,
		"type": description.type,
		"sdp": description.sdp,
		"ice_candidates": ice_candidates,
	}
	
	var destination_port := get_port(
		p_app_id,
		p_session_id,
		p_to_peer_id,
	)
	var error := udp_peer.set_dest_address(
		p_address,
		destination_port,
	)
	if error:
		raise_warning(
			"Cannot set destination address to {address}: {error}".format({
				"address": p_address,
				"error": error_string(error)
		}))
		return error
	
	error = udp_peer.put_packet(encode_data(data))
	if error:
		raise_warning(
			"Cannot send packet to {address}: {error}".format({
				"address": p_address,
				"error": error_string(error)
		}))
		return error
	
	data_sent.emit(
		data,
		p_address,
		destination_port
	)
	return error


func _handle_signaling_data(p_data: Variant):
	if not p_data is Dictionary:
		raise_warning("signaling data invalid data type")
		return
	
	if not p_data.has("app_id"):
		raise_warning("signaling data has no app_id")
		return
	
	if not p_data.app_id is String:
		raise_warning("app_id invalid data type")
		return
	
	if not p_data.has("session_id"):
		raise_warning("signaling data has no session_id")
		return
	
	if not p_data.session_id is String:
		raise_warning("session_id invalid data type")
		return
	
	if not p_data.has("peer_id"):
		raise_warning("signaling data has no peer_id")
		return
	
	if not p_data.peer_id is float:
		raise_warning("peer_id invalid data type")
		return
	
	if not p_data.has("sdp"):
		raise_warning("signaling data has no sdp")
		return
	
	if not p_data.sdp is String:
		raise_warning("sdp invalid data type")
		return
	
	if not p_data.has("type"):
		raise_warning("signaling data has no type")
		return
	
	if not p_data.type is String:
		raise_warning("type invalid data type")
		return
	
	if not p_data.has("ice_candidates"):
		raise_warning("signaling data has no ice_candidates")
		return
	
	if not p_data.ice_candidates is Array:
		raise_warning("ice_candidates invalid data type")
		return
	
	received_signaling_data.emit(
		p_data, udp_peer.get_packet_ip()
	)


static func get_app_id_from_signaling_data(p_data: Dictionary) -> String:
	return p_data.app_id


static func get_session_id_from_signaling_data(p_data: Dictionary) -> String:
	return p_data.session_id


static func get_peer_id_from_signaling_data(p_data: Dictionary) -> int:
	return int(p_data.peer_id)


static func get_type_from_signaling_data(p_data: Dictionary) -> String:
	return p_data.type


static func get_sdp_from_signaling_data(p_data: Dictionary) -> String:
	return p_data.sdp


static func get_ice_candidates_from_signaling_data(p_data: Dictionary) -> Array:
	return p_data.ice_candidates


static func is_ice_candidate_data_valid(p_data: Variant) -> bool:
	return TubeTracker.is_ice_candidate_data_valid(p_data)


static func get_media_from_ice_candidate_data(p_data: Dictionary) -> String:
	return TubeTracker.get_media_from_ice_candidate_data(p_data)


static func get_index_from_ice_candidate_data(p_data: Dictionary) -> int:
	return TubeTracker.get_index_from_ice_candidate_data(p_data)


static func get_sdp_from_ice_candidate_data(p_data: Dictionary) -> String:
	return TubeTracker.get_sdp_from_ice_candidate_data(p_data)



func _process(delta):
	while 0 < udp_peer.get_available_packet_count():
		var data = decode_packet(udp_peer.get_packet())
		received_data.emit(
			data,
			udp_peer.get_packet_ip(),
			udp_peer.get_packet_port()
		)
		_handle_signaling_data(data)
