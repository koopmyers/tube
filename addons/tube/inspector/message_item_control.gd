class_name EditorTubeMessagesItemControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.


enum Type {INFO, ERROR, WARNING, SENT, RECEIVED, SUCCESS}


@export var type := Type.INFO:
	set(x):
		type = x
		if is_instance_valid(type_texture_rect):
			type_texture_rect.texture = icons.get(type)
			type_texture_rect.modulate = colors.get(type)

@export var message_control: EditorTubeMessageControl


@export var icons: Dictionary[Type, Texture] = {}

@export var colors: Dictionary[Type, Color] = {
	Type.INFO: Color.BEIGE,
	Type.ERROR: Color.CRIMSON,
	Type.WARNING: Color.GOLDENROD,
	Type.SUCCESS: Color.PALE_GREEN,
	Type.SENT: Color.DODGER_BLUE,
	Type.RECEIVED: Color.PLUM,
}

@export var strings: Dictionary[Type, String] = {
	Type.INFO: "-",
	Type.ERROR: "X",
	Type.WARNING: "!",
	Type.SUCCESS: "*",
	Type.SENT: "<",
	Type.RECEIVED: ">",
}


var data: Variant:
	set(x):
		data = x
		if is_instance_valid(data_label):
			data_label.text = str(data)


var from_address: String:
	set(x):
		from_address = x
		if from_address.is_empty():
			return
		
		if is_instance_valid(from_label):
			from_label.text =  "{address}:{port}".format({
				"address": from_address,
				"port": str(from_id)
			})
		
		if is_instance_valid(from_label):
			from_label.modulate = EditorTubePeerItemControl.get_peer_color(from_address.hash() + from_id)


var from_id: int:
	set(x):
		from_id = x
		if is_instance_valid(from_label):
			if from_address.is_empty():
				from_label.text =  EditorTubePeerItemControl.get_peer_string(from_id)
				from_label.visible = bool(from_id)
			else:
				from_label.text =  "{address}:{port}".format({
					"address": from_address,
					"port": str(from_id)
				})
		
		if is_instance_valid(from_label):
			if from_address.is_empty():
				from_label.modulate = EditorTubePeerItemControl.get_peer_color(from_id)
			else:
				from_label.modulate = EditorTubePeerItemControl.get_peer_color(from_address.hash() + from_id)


var time: String:
	set(x):
		time = x
		if is_instance_valid(time_label):
			time_label.text = time


var button_group: ButtonGroup

@onready var button: Button = %Button
@onready var type_texture_rect: TextureRect = %TypeTextureRect
@onready var time_label: Label = %TimeLabel
@onready var from_label: Label = %FromLabel
@onready var data_label: Label = %DataLabel


func _init() -> void:
	time = Time.get_time_string_from_system()


func _ready() -> void:
	type = type
	data = data
	time = time
	from_id = from_id
	button.button_group = button_group


func _to_string() -> String:
	return "{type}\t{time}\t{address}\t{from}\t{data}".format({
		"type": strings.get(type, "-"),
		"time": time,
		"address": from_address,
		"from": from_id,
		"data": str(data),
	})


func _on_button_toggled(toggled_on: bool) -> void:
	if not is_instance_valid(message_control):
		return
	
	if toggled_on:
		message_control.message_item_control = self
	else:
		message_control.message_item_control = null
		
	#pressed.emit()


func is_pressed() -> bool:
	return button.button_pressed


func info():
	type = Type.INFO


func error():
	type = Type.ERROR


func warning():
	type = Type.WARNING


func success():
	type = Type.SUCCESS


func received(p_from_id: int = 0):
	type = Type.RECEIVED
	from_id = p_from_id


func sent():
	type = Type.SENT
