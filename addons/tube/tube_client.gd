@icon("./icons/tube_client.svg")
class_name TubeClient extends Node
## Node to create or join multiplayer session as simple as possible.
##
## One player creates a session and shares the session ID with others. The other players can then join and play together. That’s it, no server deployment needed.
## [br][br]
## This class will set up all the High-level multiplayer api for [member multiplayer_root_node] Node.
## [br][br]
## [b]Note[/b]: It uses WebRTC for peer connections, as it, it works automatically in HTML5, but require an external GDExtension plugin on other non-HTML5 platforms. Check out the [url=https://github.com/godotengine/webrtc-native/releases]webrtc-native plugin repository[/url] for instructions. No specific error message will appear if WebRTC implementation is missing.
## [br][br]
## When exporting to Android, make sure to enable the [code]INTERNET[/code] permission in the Android export preset before exporting the project or using one-click deploy. Otherwise, network communication of any kind will be blocked by Android.
##
## @tutorial(README): https://github.com/koopmyers/tube
## @tutorial(Demo project): https://github.com/koopmyers/pixelary

## Emitted when a session has been successfully created.
signal session_created

## Emitted when the client has successfully joined a session.
signal session_joined

## Emitted when the client has left the current session. Emitted after calling [method leave_session]. Also emitted on non-sever when the server leaves (closes) the session or the connection is unrecoverable.
signal session_left

## Emitted when a peer connection is refused. Only emitted on server if [member refuse_new_connections] is set to [code]true[/code] while player try to connect to the session.
signal peer_refused(peer_id: int)

## Emitted when a peer successfully joins the session.
## Emitted on all peers for every other peer.
## [br][br]
## When joining a session, it will be emitted for all peers, both server and non-server, already connected to the session.
## This is equivalent to [signal MultiplayerPeer.peer_connected].
signal peer_connected(peer_id: int)

## Emitted when a peer leaves the session or its connection becomes unrecoverable.
## Emitted on all peers for every other peer.
## [br][br]
## This is equivalent to [signal MultiplayerPeer.peer_disconnected].
signal peer_disconnected(peer_id: int)

## Emitted when a peer becomes temporarily unavailable, indicating a lost connection to the server.
## [br][br]
## This condition may represent a temporary network issue. If the connection recovers, [signal peer_stabilized] will be emitted. Otherwise, [signal peer_disconnected] will be emitted later. RPC on transport mode [code]"reliable"[/code] will be received when connection stabilizes again.
## [br][br]
## Emitted on both server and non-server peers. On non-server peers, this signal is only emitted for the server (where [param peer_id] equals 1), in this state, communication with other peers are also unstable.
signal peer_unstabilized(peer_id: int)

## Emitted when the connection to a peer stabilizes after being unstable ([signal peer_unstabilized]). Communication with other peers is now possible again.
## [br][br]
## Emitted on both server and non-server peers. On non-server peers, this signal is only emitted for the server (where [param peer_id] equals 1).
signal peer_stabilized(peer_id: int)

## Emitted when an error occurs during session. [code]message[/code] is a human-readable description of the error.
signal error_raised(code: SessionError, message: String)


signal _session_initiated
signal _local_signaling_peer_initiated(signaling_peer: TubeLocalSignalingPeer)
signal _tracker_initiated(tracker: TubeTracker)
signal _peer_initiated(peer: TubePeer)


enum State {
	## No active session. Can only create or join new session in this state.
	IDLE,
	
	## Attempting to create a session.
	CREATING_SESSION, 
	
	## The session has been successfully created. Waiting for other player to join.
	SESSION_CREATED, 
	
	## Attempting to join a session.
	JOINING_SESSION, 
	
	## A session has been successfully joined. Connected to server.
	SESSION_JOINED, 
}


enum SessionError {
	## Failed to create a session.
	CREATE_SESSION_FAILED, 
	
	## Failed to join a session.
	JOIN_SESSION_FAILED, 
	
	## Failed to kick a peer from the session.
	KICK_PEER_FAILED,
	
	## Session signaling failed, only for server. Meaning new players will not be able to join the session. The session is still considerated open as communication will connected peer is still possible. 
	## [br][br]
	## Signaling is composed of local and online signaling.  
	SIGNALING_FAILED, 
	
	## Session online signaling failed, only for server. Meaning new players will not be able to join the via Internet session. The session is still considerated open as communication will connected peer is still possible.
	## [br][br]
	## Local signaling is not available on Web platform, meaing if online signaling failed on Web platform there is no other way for player to join the session. [signal error_raised] will be emitted once with [enum SessionError.ONLINE_SIGNALING_FAILED] and a second time with [enum SessionError.SIGNALING_FAILED].
	ONLINE_SIGNALING_FAILED, 
}

const _SERVER_PEER_ID: int = 1


## Session context used to create or join a session.
@export var context: TubeContext

## Timeout (in seconds) before signaling with a peer is considered failed. Will try again util [member peer_signaling_max_attempts] is reached.
@export var peer_signaling_timeout:float = 2.0

## Maximum number of signaling attempts with a peer before failing.
@export var peer_signaling_max_attempts: int = 3

## Root node to which the multiplayer API should attach.
## If null, scene tree's root node will be used.
@export var multiplayer_root_node: Node

## Current state of the session client.
var state := State.IDLE

## The ID of the current session, if any.
var session_id := ""

## The unique ID of this peer in the session.
var peer_id: int

## Whether this peer is acting as the server, creator of a session.
var is_server: bool:
	get:
		return _SERVER_PEER_ID == peer_id

## Instance of [MultiplayerAPI] used for High-level multiplayer 
var multiplayer_api := MultiplayerAPI.create_default_interface()

## Instance of [MultiplayerPeer] used for managing peer connections.
var multiplayer_peer := WebRTCMultiplayerPeer.new()

## Server will refuse new connections if set to [code]true[/code].
var refuse_new_connections: bool = false:
	get:
		if not is_server:
			return false
		
		return refuse_new_connections
	
	set(x):
		if not is_server:
			push_error("Cannot refuse new connections, not server")
			return
		
		refuse_new_connections = x
		multiplayer_peer.refuse_new_connections = x


var _local_signaling_peer: TubeLocalSignalingPeer
var _trackers: Array[TubeTracker] = []
var _peers: Dictionary[int, TubePeer] = {}
var _upnp := TubeUPNP.new()


func _raise_error(p_code: int, p_message: String):
	printerr(p_message)
	error_raised.emit(p_code, p_message)


func _ready() -> void:
	var node_path := NodePath()
	if is_instance_valid(multiplayer_root_node):
		node_path = multiplayer_root_node.get_path()
	
	get_tree().set_multiplayer(multiplayer_api, node_path)
	
	if not multiplayer_api.peer_connected.is_connected(
		peer_connected.emit
	):
		multiplayer_api.peer_connected.connect(
			peer_connected.emit
		)
		multiplayer_api.peer_disconnected.connect(
			peer_disconnected.emit
		)


# API ###

## Creates a new multiplayer session.
## Emits [signal session_created] if successful, or [signal error_raised] with [code]SessionError.CREATE_SESSION_FAILED[/code] if failed.
func create_session() -> void:
	if not is_inside_tree():
		_session_initiated.emit()
		_raise_error(SessionError.CREATE_SESSION_FAILED, "Session creation failed, client is not inside tree")
		return
	
	if State.IDLE != state:
		_session_initiated.emit()
		_raise_error(SessionError.CREATE_SESSION_FAILED, "Session creation failed, not in idle state")
		return
	
	if null == context:
		_session_initiated.emit()
		_raise_error(SessionError.CREATE_SESSION_FAILED, "Session creation failed, context is missing")
		return
	
	if not context.is_valid():
		_session_initiated.emit()
		_raise_error(SessionError.CREATE_SESSION_FAILED, "Session creation failed, context is invalid")
		return
	
	state = State.CREATING_SESSION
	session_id = context.generate_session_id()
	peer_id = _SERVER_PEER_ID
	refuse_new_connections = false
	_session_initiated.emit()
	
	var error := multiplayer_peer.create_server()
	if error:
		_terminate_session()
		_raise_error(SessionError.CREATE_SESSION_FAILED, "Session creation failed, cannot create mutiplayer peer server: {error}".format({
			"error": error_string(error),
		}))
		return
	
	multiplayer_api.multiplayer_peer = multiplayer_peer
	
	_initiate_local_signaling()
	for url in context.trackers_urls:
		_initiate_tracker(url)
	
	if _is_local_signaling() and not _is_online_signaling():
		state = State.SESSION_CREATED
		session_created.emit()

## Attempts to join a active session [param p_session_id] created by a server.
## Emits [signal session_joined] if successful, or [signal error_raised] with [code]SessionError.JOIN_SESSION_FAILED[/code] if failed.
func join_session(p_session_id: String) -> void:
	if not is_inside_tree():
		_session_initiated.emit()
		_raise_error(SessionError.JOIN_SESSION_FAILED, "Joining session failed, client is not inside tree")
		return
	
	if State.IDLE != state:
		_session_initiated.emit()
		_raise_error(SessionError.JOIN_SESSION_FAILED, "Joining session failed, not in idle state")
		return
	
	if null == context:
		_session_initiated.emit()
		_raise_error(SessionError.JOIN_SESSION_FAILED, "Joining session failed, context is missing")
		return
	
	if not context.is_valid():
		_session_initiated.emit()
		_raise_error(SessionError.JOIN_SESSION_FAILED, "Joining session failed, context is invalid")
		return
	
	if not context.is_session_id_valid(p_session_id):
		_session_initiated.emit()
		_raise_error(SessionError.JOIN_SESSION_FAILED, "Joining session failed, session id invalid '{id}'".format({
			"id": p_session_id,
		}))
		return
	
	state = State.JOINING_SESSION
	session_id = p_session_id
	peer_id = multiplayer_peer.generate_unique_id()
	_session_initiated.emit()
	
	var error := multiplayer_peer.create_client(peer_id)
	if error:
		_terminate_session()
		_raise_error(SessionError.JOIN_SESSION_FAILED, "Joining session failed, cannot create mutiplayer peer client: {error}".format({
			"error": error_string(error),
		}))
		return
	
	multiplayer_api.multiplayer_peer = multiplayer_peer
	
	var peer := _initiate_peer(_SERVER_PEER_ID)
	if not peer.valid:
		return
	
	_initiate_local_signaling()
	for url in context.trackers_urls:
		_initiate_tracker(url)

## Attempts to remove a peer [param p_peer_id from the session. 
## Emits [signal peer_disconnected] if successful [signal error_raised] with [code]SessionError.KICK_PEER_FAILED[/code] if the operation fails.
func kick_peer(p_peer_id: int) -> void:
	if not is_server:
		_raise_error(SessionError.KICK_PEER_FAILED, "Kick peer failed, not server")
		return
	
	if not _peers.has(p_peer_id):
		_raise_error(SessionError.KICK_PEER_FAILED, "Kick peer failed, peer {peer_id}".format({
			"peer_id": p_peer_id
		}))
		return
	
	multiplayer_peer.disconnect_peer(p_peer_id)


## Leaves the current session. Will close the session for all other client if called by server.
func leave_session() -> void:
	session_left.emit()
	_terminate_session()


# SIGNALING ###


func _terminate_signaling():
	if null != _local_signaling_peer:
		_local_signaling_peer.close()
		_local_signaling_peer = null
	
	for i_tracker in _trackers:
		i_tracker.close(
			context.get_info_hash(session_id),
			context.get_peer_id_hash(peer_id)
		)


func _terminate_session():
	state = State.IDLE
	_upnp.clear_port_mapping()
	
	if null != _local_signaling_peer:
		_local_signaling_peer.close()
		_local_signaling_peer = null
	
	for i_tracker in _trackers:
		i_tracker.close(
			context.get_info_hash(session_id),
			context.get_peer_id_hash(peer_id)
		)
	
	for i_peer: TubePeer in _peers.values():
		i_peer.close() # will be clean collected
	
	session_id = ""
	multiplayer_peer.close()


func _is_local_signaling() -> bool:
	if null == _local_signaling_peer:
		return false
	
	return _local_signaling_peer.is_bound()


func _is_online_signaling() -> bool:
	return not _trackers.is_empty()


func _initiate_local_signaling() -> void:
	if not TubeLocalSignalingPeer.is_local_signaling_available():
		return
	
	_local_signaling_peer = TubeLocalSignalingPeer.new()
	var error := _local_signaling_peer.bind(
		context.app_id,
		session_id,
		peer_id
	)
	_local_signaling_peer_initiated.emit(
		_local_signaling_peer
	)
	
	if error:
		_local_signaling_peer = null
		return
	
	_local_signaling_peer.received_signaling_data.connect(
		_handle_local_signaling_data
	)


func _initiate_tracker(p_url: String) -> void:
	var tracker := TubeTracker.new()
	var error := tracker.connect_to_url(p_url)
	_tracker_initiated.emit(tracker)
	
	if error:
		return
	
	_trackers.append(tracker)
	tracker.connected.connect(
		_on_tracker_connected.bind(tracker)
	)
	tracker.received_answer.connect(
		_handle_tracker_answer.bind(tracker)
	)
	tracker.interval_timeout.connect(
		_on_tracker_interval_timeout.bind(tracker)
	)


func _on_tracker_connected(p_tracker: TubeTracker): 
	p_tracker.send_announce(
		context.get_info_hash(session_id),
		context.get_peer_id_hash(peer_id),
	)
	
	if State.CREATING_SESSION == state:
		state = State.SESSION_CREATED
		session_created.emit()
	
	if is_server:
		return
	
	if not _peers.has(_SERVER_PEER_ID):
		return
	
	var server_peer := _peers[_SERVER_PEER_ID]
	if server_peer.is_signaling_ready():
		_send_signaling_data(server_peer, p_tracker)


func _all_trackers_disconnected(): # is_online_signaling false
	if State.CREATING_SESSION == state:
		if _is_local_signaling():
			_raise_error(
				SessionError.ONLINE_SIGNALING_FAILED,
				"Online signaling failed, cannot connect to any tracker"
			)
			return
		
		_raise_error(
			SessionError.CREATE_SESSION_FAILED,
			"Session creation failed, cannot connect to any tracker"
		)
		_terminate_session()
	
	elif State.SESSION_CREATED == state:
		_raise_error(
			SessionError.ONLINE_SIGNALING_FAILED,
			"Signaling failed, lost all trackers connections"
		)
		
		if not _is_local_signaling():
			_raise_error(
				SessionError.ONLINE_SIGNALING_FAILED,
				"Signaling failed, lost all trackers connections"
			)
		
	
	elif State.JOINING_SESSION == state:
		if _peers.has(_SERVER_PEER_ID):
			var peer = _peers[_SERVER_PEER_ID]
			if peer.remote_session_description.is_empty():
				_raise_error(
					SessionError.JOIN_SESSION_FAILED,
					"Joining session failed, cannot connect to any tracker"
				)
				_terminate_session()


func _handle_local_signaling_data(p_data: Dictionary, p_address: String):
	var from_app_id := TubeLocalSignalingPeer.get_app_id_from_signaling_data(p_data)
	if from_app_id != context.app_id:
		_local_signaling_peer.raise_warning("Received signaling data from other app ID")
		return
	
	var from_session_id := TubeLocalSignalingPeer.get_session_id_from_signaling_data(p_data)
	if from_session_id != session_id:
		_local_signaling_peer.raise_warning("Received signaling data from other session ID")
		return
	
	var from_peer_id := TubeLocalSignalingPeer.get_peer_id_from_signaling_data(p_data)
	if is_server and from_peer_id == _SERVER_PEER_ID:
		_local_signaling_peer.raise_warning("Received signaling data from peer id 1 as server")
		return
	
	if not is_server and from_peer_id != _SERVER_PEER_ID:
		_local_signaling_peer.raise_warning("Received signaling data from peer {peer_id}, but not as server".format({
			"peer_id": from_peer_id
		}))
		return
	
	if refuse_new_connections:
		peer_refused.emit(from_peer_id)
		return
	
	var peer: TubePeer = _peers.get(from_peer_id)
	if null == peer:
		peer = _initiate_peer(from_peer_id)
		if not peer.valid:
			return
	
	peer.local_address = p_address
	
	if WebRTCPeerConnection.ConnectionState.STATE_CONNECTED == peer.get_connection_state():
		peer.raise_warning(
			"Receive signaling data but already connected"
		)
		return
	
	if peer.remote_session_description.is_empty():
		var type := TubeLocalSignalingPeer.get_type_from_signaling_data(p_data)
		var sdp := TubeLocalSignalingPeer.get_sdp_from_signaling_data(p_data)
		if peer.set_remote_description(type, sdp): # error
			return
	
	for candidate_data in TubeLocalSignalingPeer.get_ice_candidates_from_signaling_data(p_data):
		
		if not TubeLocalSignalingPeer.is_ice_candidate_data_valid(candidate_data):
			peer.raise_warning(
				"Cannot add ice candidate, ice data invalid"
			)
			continue
		
		peer.add_ice_candidate(
			TubeLocalSignalingPeer.get_media_from_ice_candidate_data(
				candidate_data
			),
			TubeLocalSignalingPeer.get_index_from_ice_candidate_data(
				candidate_data
			),
			TubeLocalSignalingPeer.get_sdp_from_ice_candidate_data(
				candidate_data
			)
		)


func _handle_tracker_answer(data: Dictionary, p_tracker: TubeTracker):
	var from_peer_id_hash := TubeTracker.get_peer_id_hash_from_answer_data(data)
	if not context.is_peer_id_hash_valid(from_peer_id_hash):
		p_tracker.raise_warning("answer peer id invalid")
		return
	
	var from_peer_id := context.get_peer_id(from_peer_id_hash)
	if refuse_new_connections:
		peer_refused.emit(from_peer_id)
		return
	
	var peer: TubePeer = _peers.get(from_peer_id)
	if null == peer:
		peer = _initiate_peer(from_peer_id)
		if not peer.valid:
			return
	
	
	if WebRTCPeerConnection.ConnectionState.STATE_CONNECTED == peer.get_connection_state():
		peer.raise_warning(
			"Receive signaling data but already connected"
		)
		return
	
	if peer.remote_session_description.is_empty():
		var type := TubeTracker.get_type_from_answer_data(data)
		var sdp := TubeTracker.get_sdp_from_answer_data(data)
		if peer.set_remote_description(type, sdp): # error
			return
	
	for candidate_data in TubeTracker.get_ice_candidates_from_answer_data(data):
		
		if not TubeTracker.is_ice_candidate_data_valid(candidate_data):
			peer.raise_warning(
				"Cannot add ice candidate, ice data invalid"
			)
			continue
		
		peer.add_ice_candidate(
			TubeTracker.get_media_from_ice_candidate_data(
				candidate_data
			),
			TubeTracker.get_index_from_ice_candidate_data(
				candidate_data
			),
			TubeTracker.get_sdp_from_ice_candidate_data(
				candidate_data
			)
		)


func _on_tracker_interval_timeout(p_tracker: TubeTracker):
	p_tracker.send_announce(
		context.get_info_hash(session_id),
		context.get_peer_id_hash(peer_id),
	)


func _send_signaling_data(p_peer: TubePeer, p_tracker: TubeTracker = null):
	
	if _local_signaling_peer:
		if is_server:
			_local_signaling_peer.send_signaling_data(
				p_peer.local_address,
				context.app_id,
				session_id,
				peer_id,
				p_peer.id,
				p_peer.local_session_description,
				p_peer.ice_candidates,
			)
		else:
			_local_signaling_peer.broadcast_signaling_data(
				context.app_id,
				session_id,
				peer_id,
				p_peer.id,
				p_peer.local_session_description,
				p_peer.ice_candidates,
			)
	
	var info_hash := context.get_info_hash(session_id)
	var peer_id_hash := context.get_peer_id_hash(peer_id)
	var to_peer_id_hash := context.get_peer_id_hash(p_peer.id)
	
	var to_trackers = _trackers
	if p_tracker:
		to_trackers = [p_tracker]
	
	for i_tracker in to_trackers:
		if not i_tracker.is_open():
			continue
		
		i_tracker.send_answer(
			info_hash,
			peer_id_hash,
			to_peer_id_hash,
			p_peer.local_session_description,
			p_peer.ice_candidates,
		)


# PEER CONNECTION ###

func _initiate_peer(p_peer_id: int) -> TubePeer:
	var peer := TubePeer.new(p_peer_id)
	peer.signaling_timeout_time = peer_signaling_timeout
	peer.signaling_max_attempts = peer_signaling_max_attempts
	var error := peer.initialize(
		context.get_ice_servers()
	)
	
	if error: # error raised with peer.failed
		return peer
	
	
	peer.signaling_readied.connect(
		_on_peer_signaling_readied.bind(peer)
	)
	peer.signaling_timeout.connect(
		_on_peer_signaling_timeout.bind(peer)
	)
	peer.connected.connect(
		_on_peer_connected.bind(peer)
	)
	peer.disconnected.connect(
		_on_peer_disconnected.bind(peer)
	)
	peer.failed.connect(
		_on_peer_failed.bind(peer)
	)
	peer.closed.connect(
		_on_peer_closed.bind(peer)
	)
	peer.port_mapped.connect(
		_upnp.add_port_mapping
	)
	
	_peers[p_peer_id] = peer
	_peer_initiated.emit(peer)
	error = multiplayer_peer.add_peer(peer, p_peer_id)
	if error:
		peer.valid = false
		peer.error_message = "cannot add to multiplayer: ".format({
			"error": error_string(error)
		})
		peer.failed.emit()
	
	if not is_server:
		error = peer.create_offer()
		if error: # error raised with peer.failed
			return peer
	
	return peer


func _clean_peer(p_peer: TubePeer):
	if multiplayer_peer.has_peer(p_peer.id):
		multiplayer_peer.remove_peer(p_peer.id)
	
	for port in p_peer.mapped_ports:
		_upnp.delete_port_mapping(port)
	
	#if _peers.has(p_peer.id): # garbage collected
		#_peers.erase(p_peer.id)
	p_peer.has_joined_session = false
	p_peer.close()



func _on_peer_signaling_readied(p_peer: TubePeer):
	_send_signaling_data(p_peer)
	p_peer.start_connection_attempt()


func _on_peer_signaling_timeout(p_peer: TubePeer):
	_send_signaling_data(p_peer)
	p_peer.start_connection_attempt()


func _on_peer_connected(p_peer: TubePeer):
	if State.IDLE == state:
		_clean_peer(p_peer)
		return
	
	if State.JOINING_SESSION == state:
		state = State.SESSION_JOINED
		_terminate_signaling()
		session_joined.emit()
	
	if p_peer.has_joined_session:
		peer_stabilized.emit(p_peer.id)
	p_peer.has_joined_session = true
	#peer connected will be emitted by multiplayer


func _on_peer_disconnected(p_peer: TubePeer): # temporary disconnection
	if State.IDLE == state:
		_clean_peer(p_peer)
		return
	
	peer_unstabilized.emit(p_peer.id)


func _on_peer_failed(p_peer: TubePeer):
	_clean_peer(p_peer)
	if State.IDLE == state:
		return
	
	if not is_server:
		if State.JOINING_SESSION == state:
			_raise_error(
				SessionError.JOIN_SESSION_FAILED,
				"Joining session failed, peer {peer_id} connection failed: {error}".format({
					"peer_id": p_peer.id,
					"error": p_peer.error_message
				})
			)
		
		elif State.SESSION_JOINED == state:
			session_left.emit()
		
		_terminate_session()


func _on_peer_closed(p_peer: TubePeer):
	_clean_peer(p_peer)
	if State.IDLE == state:
		return
	
	if not is_server:
		if State.SESSION_JOINED == state:
			session_left.emit()
		
		_terminate_session()


# PROCESS ###

func _process(delta):
	
	if _upnp:
		_upnp._process(delta)
	
	if _local_signaling_peer:
		_local_signaling_peer._process(delta)
	
	var tracker_closed := false
	var updated_trackers: Array[TubeTracker] = []
	for i_tracker in _trackers:
		i_tracker._process(delta)
		if i_tracker.is_close():
			tracker_closed = true
			continue
		
		updated_trackers.append(i_tracker)
	
	_trackers = updated_trackers
	if tracker_closed and not _is_online_signaling():
		_all_trackers_disconnected()
	
	
	var updated_peers: Dictionary[int, TubePeer] = {}
	for i_peer_id in _peers:
		var i_peer := _peers[i_peer_id]
		i_peer._process(delta)
		if WebRTCPeerConnection.STATE_CLOSED == i_peer.connection_state: # don't use is_close to use connection_state
			_clean_peer(i_peer)
			continue
		
		updated_peers[i_peer_id] = i_peer
	
	_peers = updated_peers
