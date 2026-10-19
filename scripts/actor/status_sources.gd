extends RefCounted
## Tracks effect sources without retaining Nodes or leaving status locks behind.
signal expired(source_id: int)
var _sources: Dictionary = {}
var _suspended := false
var _pending_expired: Array[int] = []


func track(source: Node) -> void:
	if not is_instance_valid(source):
		return
	var id := source.get_instance_id()
	if _sources.has(id):
		return
	_sources[id] = weakref(source)
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
	_pending_expired.clear()


func suspend() -> void:
	# Keep listening while the owner is detached: even a temporary source exit
	# ends its effects. Delay delivery until the owner can update its physics.
	_suspended = true


func resume() -> void:
	if not _suspended:
		return
	prune()
	_suspended = false
	var pending := _pending_expired.duplicate()
	_pending_expired.clear()
	for id in pending:
		expired.emit(id)


func _on_tree_exiting(source_id: int) -> void:
	forget(source_id)
	if _suspended:
		_pending_expired.append(source_id)
	else:
		expired.emit(source_id)
