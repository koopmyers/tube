class_name TubeNetworkDiagnosisPeer extends RefCounted


signal warning_raised(message: String)
signal nat_hole_punching_compliance_updated(compliance: Compliance)


const WAITING_TIME := 10.0 #sec

const STUN_BINDING_REQUEST := 0x0001
const STUN_MAGIC_COOKIE := 0x2112A442

# STUN attribute types
const ATTR_XOR_MAPPED_ADDRESS := 0x0020
const ATTR_MAPPED_ADDRESS := 0x0001
#const ATTR_USERNAME := 0x0006
#const ATTR_MESSAGE_INTEGRITY := 0x0008
#const ATTR_ERROR_CODE := 0x0009
#const ATTR_UNKNOWN_ATTRIBUTES := 0x000A
#const ATTR_PRIORITY := 0x0024
#const ATTR_USE_CANDIDATE := 0x0025
#const ATTR_ICE_CONTROLLED := 0x8029
#const ATTR_ICE_CONTROLLING := 0x802A


enum Compliance {UNKNOWN, YES, NO}


var peer := PacketPeerUDP.new()
var _binding_port: int
var _binding_time: float = 0.0


var public_ports: Dictionary[String, int] = {} # destionnation address:port, public port


func _u16_to_bytes(v) -> PackedByteArray:
	return PackedByteArray([v>>8 & 0xFF, v & 0xFF])


func _u32_to_bytes(v) -> PackedByteArray:
	return PackedByteArray([v>>24 & 0xFF, v>>16 & 0xFF, v>>8 & 0xFF, v & 0xFF])


func _bytes_to_u16(bytes: PackedByteArray) -> int:
	return (bytes[0] << 8) | bytes[1]


func _init(p_port: int) -> void:
	_binding_port = p_port


func raise_warning(message: String):
	push_warning(message)
	warning_raised.emit(message)


# HOLE PUNCHING

func start_nat_hole_punching_detection(p_urls: Array[String]):
	public_ports.clear()
	
	if not peer.is_bound():
		var error := peer.bind(_binding_port)
		if error:
			raise_warning("cannot bind to {port}: {error}".format({
				"port": _binding_port,
				"error": error_string(error)
			}))
			return
	
	_binding_time = 0.0
	
	for url in p_urls:
		var splited := url.split(":")
		var address := splited[1]
		var port := int(splited[2])
		_send_stunbinding_request(address, port)


func is_nat_hole_punching_compliant() -> Compliance:
	var ports := {}
	for i_port in public_ports.values():
		ports[i_port] = 0
	
	if 1 < len(ports): # multiple ports --> mapping depends on destination
		return Compliance.NO
	
	if 1 == len(ports) and 1 < len(public_ports): # one port and multiple destinations --> NAT preserves mapping across destinations
		return Compliance.YES
	
	return Compliance.UNKNOWN


func _send_stunbinding_request(p_address: String, p_port: int) -> void:
	var error := peer.set_dest_address(p_address, p_port)
	if error:
		raise_warning("cannot set destionation address {address}:{port}: {error}".format({
			"address": p_address,
			"port": p_port,
			"error": error_string(error)
		}))
		return
	
	# Build STUN Binding Request packet (20 bytes header)
	var packet = PackedByteArray()
	packet.resize(0)
	packet.append_array(_u16_to_bytes(STUN_BINDING_REQUEST))  # Type
	packet.append_array(_u16_to_bytes(0)) # Message length 0 (no attributes)                  
	packet.append_array(_u32_to_bytes(STUN_MAGIC_COOKIE)) # Magic Cookie
	for i in 12: # Transaction ID (random)
		packet.append(randi() & 0xFF)
	
	error = peer.put_packet(packet)
	if error:
		raise_warning("cannot put packet to {address}:{port}: {error}".format({
			"address": p_address,
			"port": p_port,
			"error": error_string(error)
		}))
		return


func parse_stun_response(data: PackedByteArray):
	if data.size() < 20:
		raise_warning("STUN response too short")
		return
	
	var i := 20 #Skip header
	while i + 4 <= data.size():
		var attr_type := (data[i] << 8) | data[i+1]
		var attr_len := (data[i+2] << 8) | data[i+3]
		var value := data.slice(i+4, i+4+attr_len)
		i += 4 + attr_len
		# Attributes are 32-bit aligned: pad to 4 bytes
		if attr_len % 4 != 0:
			i += 4 - (attr_len % 4)

		# Decode port in attributes
		var port: int
		if attr_type == ATTR_XOR_MAPPED_ADDRESS and attr_len >= 8:
			port = ((value[2] << 8) | value[3]) ^ (STUN_MAGIC_COOKIE >> 16)

		elif attr_type == ATTR_MAPPED_ADDRESS and attr_len >= 8:
			port = (value[2] << 8) | value[3]

		else:
			continue
	
		var key := "{address}:{port}".format({
			"address": peer.get_packet_ip(),
			"port": peer.get_packet_port(),
		})
		public_ports[key] = port
		return


# PROCESS

func _process(delta: float) -> void:
	_binding_time += delta
	while 0 < peer.get_available_packet_count():
		var response = peer.get_packet()
		parse_stun_response(response)
		nat_hole_punching_compliance_updated.emit(is_nat_hole_punching_compliant())
	
	if WAITING_TIME < _binding_time:
		peer.close()
