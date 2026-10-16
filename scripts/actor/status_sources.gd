extends RefCounted
## Tracks effect sources without retaining Nodes or leaving status locks behind.
signal expired(source_id: int)
var _sources: Dictionary = {}
var _suspended := false


func track(source: Node) -> void:
	if not is_instance_valid(source):
		return
	var id := source.get_instance_id()
	if _sources.has(id):
		return
	_sources[id] = weakref(source)
	if not _suspended:
		source.tree_exiting.connect(_on_tree_exiting.bind(id), CONNECT_ONE_SHOT)


func forget(source_id: int) -> void:
	var reference: WeakRef = _sources.get(source_id)
	_sources.erase(source_id)
	if reference == null:
		return
	var source := reference.get_ref() as Node
	if is_instance_valid(source):
		var callback := _on_tree_exiting.bind(source_id)
		if source.tree_exiting.is_connected(callback):
			source.tree_exiting.disconnect(callback)


func prune() -> void:
	for id in _sources.keys():
		if not is_instance_valid((_sources[id] as WeakRef).get_ref()):
			_on_tree_exiting(id)


func clear() -> void:
	for id in _sources.keys():
		forget(id)


func suspend() -> void:
	_suspended = true
	for id in _sources:
		var source := (_sources[id] as WeakRef).get_ref() as Node
		if is_instance_valid(source):
			var callback := _on_tree_exiting.bind(id)
			if source.tree_exiting.is_connected(callback):
				source.tree_exiting.disconnect(callback)


func resume() -> void:
	if not _suspended:
		return
	_suspended = false
	var sources := _sources.duplicate()
	_sources.clear()
	for id in sources:
		var source := (sources[id] as WeakRef).get_ref() as Node
		if is_instance_valid(source):
			track(source)
		else:
			expired.emit(id)


func _on_tree_exiting(source_id: int) -> void:
	forget(source_id)
	expired.emit(source_id)
