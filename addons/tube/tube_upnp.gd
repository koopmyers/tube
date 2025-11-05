class_name TubeUPNP extends RefCounted


signal warning_raised(message: String)
signal port_mapping_ready
signal port_mapped(public_port: int, local_port: int)


const MAPPING_DURATION := 60*2 #sec, 2 minutes
const MAPPING_RENEW_TIME := 0.75*MAPPING_DURATION


var mapped_ports: Dictionary[int, int] = {}
var mapped_times: Dictionary[int, float] = {}

var task_ids: Array[int] = []
var upnp := UPNP.new()

var is_port_mapping_ready := false
var mutex := Mutex.new()
var mapping_queue: Array[Callable] = []


func raise_warning(message: String):
	push_warning(message)
	warning_raised.emit(message)


func _init() -> void:
	if OS.get_name() == "Web":
		return
	
	port_mapping_ready.connect(_on_port_mapping_ready)
	task_ids.append(WorkerThreadPool.add_task(_upnp_init_task))


func _upnp_init_task() -> void:
	var error := upnp.discover()
	
	if error:
		raise_warning.call_deferred(
			"cannot map port, upnp discover error: {error}".format({
			"error": ClassDB.class_get_enum_constants("UPNP", "UPNPResult")[int(error)], # UPNPResult
		}))
		return
	
	var gateway := upnp.get_gateway()
	if null == gateway:
		raise_warning.call_deferred(
			"cannot map port, no gateway found".format({
		}))
		return
	
	if not gateway.is_valid_gateway():
		raise_warning.call_deferred(
			"cannot map port, gateway not valid".format({
		}))
		return
	
	mutex.lock()
	is_port_mapping_ready = true
	mutex.unlock()
	port_mapping_ready.emit.call_deferred()


func _on_port_mapping_ready():
	for callable in mapping_queue:
		WorkerThreadPool.add_task(callable, true)


func _process(delta: float):
	for port in mapped_times:
		if not mapped_ports.has(port):
			continue
		
		mapped_times[port] += delta
		if MAPPING_RENEW_TIME < mapped_times[port]:
			var local_port := mapped_ports[port]
			_add_port_mapping(port, local_port)
	
	var tmp_ids := Array(task_ids)
	task_ids.clear()
	while not tmp_ids.is_empty():
		var id := tmp_ids.pop_back()
		if WorkerThreadPool.is_task_completed(id):
			var error := WorkerThreadPool.wait_for_task_completion(id)
			if error:
				raise_warning("cannot wait for port mapping task completion: {error}".format({
					"error": error_string(error)
				}))
		else:
			task_ids.append(id)


func add_port_mapping(p_public_port: int, p_local_port: int) -> void:
	if mapped_ports.has(p_public_port):
		return
	
	_add_port_mapping(p_public_port, p_local_port)


func _add_port_mapping(p_public_port: int, p_local_port: int) -> void:
	mapped_ports[p_public_port] = p_local_port
	mapped_times[p_public_port] = 0.0
	
	var callable := _add_port_mapping_task.bind(
		p_public_port,
		p_local_port
	)
	mutex.lock()
	if is_port_mapping_ready:
		task_ids.append(WorkerThreadPool.add_task(callable, true))
	else:
		mapping_queue.append(callable)
	
	mutex.unlock()


func _add_port_mapping_task(p_public_port: int, p_local_port: int) -> void:
	mutex.lock()
	if not is_port_mapping_ready:
		raise_warning.call_deferred(
			"cannot map port {port} to internal port {internal_port}, upnp not ready".format({
			"port": p_public_port,
			"internal_port": p_local_port,
		}))
		return
	mutex.unlock()
	
	var result := upnp.add_port_mapping(
		p_public_port,
		p_local_port,
		"Tube", #ProjectSettings.get_setting("application/config/name"),
		"UDP",
		MAPPING_DURATION
	)
	if result:
		raise_warning.call_deferred(
			"cannot map port {port} to internal port {internal_port}, error: {error}".format({
			"port": p_public_port,
			"internal_port": p_local_port,
			"error": ClassDB.class_get_enum_constants("UPNP", "UPNPResult")[int(result)]
		}))
	
	else:
		port_mapped.emit.call_deferred(
			p_public_port,
			p_local_port
		)


func delete_port_mapping(p_public_port: int):
	if not mapped_ports.has(p_public_port):
		return
	
	mapped_ports.erase(p_public_port)
	mapped_times.erase(p_public_port)
	
	var callable := _delete_port_mapping_task.bind(
		p_public_port,
	)
	mutex.lock()
	if is_port_mapping_ready:
		task_ids.append(WorkerThreadPool.add_task(callable, true))
	else:
		mapping_queue.append(callable)
	mutex.unlock()


func _delete_port_mapping_task(p_public_port: int) -> void:
	mutex.lock()
	if not is_port_mapping_ready:
		raise_warning.call_deferred(
			"cannot delete port mapping {port}, upnp not ready".format({
			"port": p_public_port,
		}))
		return
	mutex.unlock()
	
	var result := upnp.delete_port_mapping(p_public_port, "UDP")
	if result:
		raise_warning.call_deferred(
			"cannot delete port mapping {port}, error: {error}".format({
			"port": p_public_port,
			"error": ClassDB.class_get_enum_constants("UPNP", "UPNPResult")[int(result)]
		}))


func clear_port_mapping() -> void:
	for port in mapped_ports:
		delete_port_mapping(port)
	
	mapped_ports.clear()
	mapped_times.clear()


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for port in mapped_ports:
			delete_port_mapping(port)
	
		mapped_ports.clear()
		mapped_times.clear()
		
		for id in task_ids:
			var error := WorkerThreadPool.wait_for_task_completion(id)
			if error:
				raise_warning("cannot wait for port mapping task completion: {error}".format({
					"error": error_string(error)
				}))
				return
		
		task_ids.clear()
