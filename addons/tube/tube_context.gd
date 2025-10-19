@icon("./icons/tube_context.svg")
@tool
class_name TubeContext extends Resource
## A resource that holds configuration and helper methods for managing simple multiplayer session.

const _STRING_CHARACTER_SET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"

@export_tool_button("Generate app id", "RandomNumberGenerator") var _generate_app_id_tool_button = (func():
	app_id = _get_random_string(15)
)

## Application identifier for this multiplayer context.
## Must be exactly 15 characters long.
@export var app_id: String

## List of tracker server URLs used for session signaling.
@export var trackers_urls: Array[String] = []

## List of STUN server URLs used for WebRTC ICE candidate resolution.
@export var stun_servers_urls: Array[String] = []

## List of TURN servers (optional). Turn server are dictionnary in the form:
## [codeblock]
## {
##		"urls": "turn:turn.example.com:3478",
##		"username: "my-username",
##		"credential": "my-credential",
## }
@export var turn_servers: Array[Dictionary] = []


func _to_string() -> String:
	return "AppID: %s | Trackers: %s | STUN: %s" % [app_id, str(trackers_urls), str(stun_servers_urls)]


## Checks if the context configuration is valid.
func is_valid() -> bool:
	if null == app_id or 15 != app_id.length():
		printerr("App id is invalid")
		return false
	
	return true

## Returns ICE server configuration dictionary for WebRTC peer connection.
## 
## Example:
## [codeblock]
## {
## 	"iceServers": [
## 		{
## 			"urls": [ "stun:stun.example.com:3478" ], # One or more STUN servers.
## 		},
## 		{
## 			"urls": [ "turn:turn.example.com:3478" ], # One or more TURN servers.
## 			"username": "a_username", # Optional username for the TURN server.
## 			"credential": "a_password", # Optional password for the TURN server.
## 		}
## 	]
## }

## [/codeblock]
func get_ice_servers() -> Dictionary:
	var ice_servers := []
	
	if null != stun_servers_urls:
		for url in stun_servers_urls:
			ice_servers.append({
				"urls": url
			})
	
	if null != turn_servers:
		for turn_server in turn_servers:
			ice_servers.append(turn_server)
	
	if ice_servers.is_empty():
		return {}
	
	return {
		"iceServers": ice_servers
	}


func _get_random_string(p_size: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	var character_set_length := _STRING_CHARACTER_SET.length()
	
	var out := ""
	for i in range(p_size):
		var index := rng.randi()%character_set_length
		out += _STRING_CHARACTER_SET[index]
	
	return out
	

## Generates a random 5-character session ID.
func generate_session_id() -> String:
	return _get_random_string(5)


## Validates if a session ID is correct
func is_session_id_valid(p_session_id: String) -> bool:
	return 5 == p_session_id.length()


## Validates if a peer ID hash is numeric and valid.
func is_peer_id_hash_valid(p_peer_id_hash: String) -> bool:
	return p_peer_id_hash.is_valid_int()

## Returns the combined "info hash" (app ID and session ID) for tracker usage.
func get_info_hash(p_session_id: String) -> String:
	if not is_session_id_valid(p_session_id):
		printerr("Invalid session id")
		return ""
	
	return app_id + p_session_id


## Converts a integer peer ID hash into an peer ID hash for tracker usage.
func get_peer_id_hash(p_peer_id: int) -> String:
	return str(p_peer_id).pad_zeros(20)


## Converts a peer ID hash into an integer peer ID.
func get_peer_id(p_peer_id_hash: String) -> int:
	if not is_peer_id_hash_valid(p_peer_id_hash):
		return 0
	
	return int(p_peer_id_hash)
