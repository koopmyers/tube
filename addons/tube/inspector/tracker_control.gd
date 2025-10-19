class_name EditorTubeTrackerControl extends Control
## @experimental: This class is used as part of the TubeClientDebugPanel scene and is part of a scene. Should not be used as itself.

@export var tracker_item: EditorTubeTrackerItemControl:
	set(x):
		show()
		
		if is_instance_valid(messages_container):
			if tracker_item != x or not messages_container.is_displaying_from(self):
				messages_container.display_messages(
					x.message_item_controls,
					self
				)
		
		if is_instance_valid(url_label):
			url_label.text = str(x.tracker)
		
		tracker_item = x


@export var messages_container: EditorTubeMessagesContainer


@onready var url_label: Label = %UrlLabel
@onready var connection_time_label: Label = %ConnectingTimeLabel
@onready var up_time_label: Label = %UpTimeLabel
@onready var interval_time_left_label: Label = %IntervalTimeLeftLabel
@onready var interval_time_label: Label = %IntervalTimeLabel



func _ready() -> void:
	hide()


func update_messages():
	if null == tracker_item:
		return
	
	if is_instance_valid(messages_container):
		if messages_container.is_displaying_from(self):
			messages_container.display_messages(
				tracker_item.message_item_controls,
				self
			)


func _process(_delta: float) -> void:
	if null == tracker_item:
		return
	
	connection_time_label.text = str(
		tracker_item.tracker.connecting_time
	).pad_decimals(3)
	up_time_label.text = str(
		tracker_item.tracker.up_time
	).pad_decimals(3)
	
	interval_time_left_label.text = str(
		tracker_item.tracker.interval_time_left
	).pad_decimals(3)
	interval_time_label.text = str(
		tracker_item.tracker.interval_time
	).pad_decimals(3)
