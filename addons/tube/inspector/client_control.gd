extends Control


var client: TubeClient:
	set(x):
		client = x
		
		if not is_instance_valid(client):
			return
		
		if is_instance_valid(client_label):
			client_label.text = client.name
		
		if is_instance_valid(context_label):
			context_label.text = client.context.resource_name
		
		if is_instance_valid(app_id_label):
			app_id_label.text = client.context.app_id
		
		if is_instance_valid(root_node_label):
			root_node_label.text = client.multiplayer_root_node.get_path()


@onready var client_label: Label = %ClientLabel
@onready var context_label: Label = %ContextLabel
@onready var app_id_label: Label = %AppIdLabel
@onready var root_node_label: Label = %RootNodeLabel
