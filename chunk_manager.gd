extends Node
class_name ChunkManager

const CHUNK_SIZE = 16  # Must match Chunk.CHUNK_SIZE
const LOAD_DISTANCE = 2  # Number of chunks to load around player
const UNLOAD_DISTANCE = 4  # Distance at which chunks are unloaded

var chunks = {}  # Dictionary of loaded chunks: {Vector2i: Chunk}
var player: Player
var world: Node3D
var last_player_chunk: Vector2i = Vector2i.ZERO

signal tile_clicked(tile_position: Vector2i)

func _init(world_node: Node3D, player_node: Player):
	world = world_node
	player = player_node
	last_player_chunk = get_chunk_position_from_world(Vector2i(player.world_position))

func _ready():
	# Connect to player chunk change signal
	if player:
		if player.has_signal("chunk_changed"):
			player.chunk_changed.connect(_on_player_chunk_changed)
		else:
			print("Warning: Player does not have chunk_changed signal")

func _process(delta):
	# No longer need to check every frame - using signals instead
	pass

func get_chunk_position_from_world(world_pos: Vector2i) -> Vector2i:
	"""Convert world position to chunk position"""
	return Vector2i(floor(world_pos.x / float(CHUNK_SIZE)), floor(world_pos.y / float(CHUNK_SIZE)))

func get_world_position_from_chunk(chunk_pos: Vector2i) -> Vector2i:
	"""Convert chunk position to world position (top-left corner)"""
	return chunk_pos * CHUNK_SIZE

func _on_player_chunk_changed(new_chunk_pos: Vector2i):
	"""Handle player moving to a new chunk"""
	if not is_instance_valid(self):
		return
		
	print("Player moved to chunk: ", new_chunk_pos)
	last_player_chunk = new_chunk_pos
	update_chunks_around_player(new_chunk_pos)

func update_chunks_around_player(player_chunk_pos: Vector2i):
	"""Load chunks around player and unload distant chunks"""
	# Prevent multiple simultaneous updates
	if not is_processing():
		return
		
	var chunks_to_load = []
	var chunks_to_unload = []
	
	# Determine which chunks should be loaded
	for x in range(player_chunk_pos.x - LOAD_DISTANCE, player_chunk_pos.x + LOAD_DISTANCE + 1):
		for y in range(player_chunk_pos.y - LOAD_DISTANCE, player_chunk_pos.y + LOAD_DISTANCE + 1):
			var chunk_pos = Vector2i(x, y)
			if not chunks.has(chunk_pos):
				chunks_to_load.append(chunk_pos)
	
	# Determine which chunks should be unloaded
	for chunk_pos in chunks.keys():
		var distance = chunk_pos.distance_to(player_chunk_pos)
		if distance > UNLOAD_DISTANCE:
			chunks_to_unload.append(chunk_pos)
	
	# Unload distant chunks first
	for chunk_pos in chunks_to_unload:
		unload_chunk(chunk_pos)
	
	# Load new chunks
	for chunk_pos in chunks_to_load:
		load_chunk(chunk_pos)

func load_chunk(chunk_pos: Vector2i):
	"""Load and render a chunk at the specified position"""
	if chunks.has(chunk_pos):
		return  # Already loaded
	
	print("Loading chunk at position: ", chunk_pos)
	
	# Create new chunk
	var chunk = Chunk.new(chunk_pos)
	chunk.name = "Chunk_" + str(chunk_pos.x) + "_" + str(chunk_pos.y)
	
	# Add chunk to world first
	world.add_child(chunk)
	
	# Store chunk reference
	chunks[chunk_pos] = chunk
	
	# Connect tile click signal after chunk is added to scene
	call_deferred("_connect_chunk_signals", chunk)
	
	# Generate chunk content first, then render
	chunk.call_deferred("generate_chunk")
	
	print("Loading chunk at position: ", chunk_pos)

func _connect_chunk_signals(chunk: Chunk):
	"""Connect signals for a chunk after it's properly set up"""
	if not chunk or not is_instance_valid(chunk):
		print("Warning: Invalid chunk for signal connection")
		return
		
	if chunk.has_signal("tile_clicked"):
		# Disconnect first to avoid multiple connections
		if chunk.tile_clicked.is_connected(_on_chunk_tile_clicked):
			chunk.tile_clicked.disconnect(_on_chunk_tile_clicked)
		
		chunk.tile_clicked.connect(_on_chunk_tile_clicked)
		print("Connected tile_clicked signal for chunk at: ", chunk.chunk_position)
	else:
		print("Warning: Could not connect tile_clicked signal for chunk")

func unload_chunk(chunk_pos: Vector2i):
	"""Unload and remove a chunk"""
	if not chunks.has(chunk_pos):
		return  # Not loaded
	
	print("Unloading chunk at position: ", chunk_pos)
	
	var chunk = chunks[chunk_pos]
	
	# Disconnect signals safely
	if chunk and chunk.has_signal("tile_clicked"):
		if chunk.tile_clicked.is_connected(_on_chunk_tile_clicked):
			chunk.tile_clicked.disconnect(_on_chunk_tile_clicked)
	
	# Unload the chunk
	chunk.unload_chunk()
	
	# Remove from world
	world.remove_child(chunk)
	chunk.queue_free()
	
	# Remove from chunks dictionary
	chunks.erase(chunk_pos)
	
	print("Unloaded chunk at position: ", chunk_pos)

func get_chunk_at_position(world_pos: Vector2i) -> Chunk:
	"""Get the chunk at a world position"""
	var chunk_pos = get_chunk_position_from_world(world_pos)
	return chunks.get(chunk_pos, null)

func get_tile_at_position(world_pos: Vector2i):
	"""Get the tile at a world position"""
	var chunk = get_chunk_at_position(world_pos)
	if chunk:
		return chunk.get_tile(world_pos)
	return null

func set_tile_at_position(world_pos: Vector2i, tile_type: int):
	"""Set the tile at a world position"""
	var chunk = get_chunk_at_position(world_pos)
	if chunk:
		chunk.set_tile(world_pos, tile_type)

func is_tile_walkable(world_pos: Vector2i) -> bool:
	"""Check if a tile at world position is walkable"""
	var chunk = get_chunk_at_position(world_pos)
	if chunk:
		return chunk.is_tile_walkable(world_pos)
	return false

func add_object_to_chunk(object: GameObject, world_pos: Vector2i):
	"""Add a GameObject to the chunk at the specified world position"""
	var chunk = get_chunk_at_position(world_pos)
	if chunk:
		chunk.render_object(object)

func remove_object_from_chunk(object: GameObject, world_pos: Vector2i):
	"""Remove a GameObject from the chunk at the specified world position"""
	var chunk = get_chunk_at_position(world_pos)
	if chunk:
		chunk.remove_object(object)

func get_loaded_chunks() -> Array:
	"""Get all currently loaded chunk positions"""
	return chunks.keys()

func get_chunk_count() -> int:
	"""Get the number of currently loaded chunks"""
	return chunks.size()

func force_load_chunk(chunk_pos: Vector2i):
	"""Force load a specific chunk (useful for debugging or manual loading)"""
	load_chunk(chunk_pos)

func force_unload_chunk(chunk_pos: Vector2i):
	"""Force unload a specific chunk (useful for debugging or manual unloading)"""
	unload_chunk(chunk_pos)

func reload_all_chunks():
	"""Reload all currently loaded chunks"""
	var chunk_positions = chunks.keys()
	for chunk_pos in chunk_positions:
		unload_chunk(chunk_pos)
		load_chunk(chunk_pos)

func get_chunk_bounds() -> Dictionary:
	"""Get the bounds of all loaded chunks"""
	if chunks.is_empty():
		return {"min": Vector2i.ZERO, "max": Vector2i.ZERO}
	
	var min_pos = chunks.keys()[0]
	var max_pos = chunks.keys()[0]
	
	for chunk_pos in chunks.keys():
		min_pos = min_pos.min(chunk_pos)
		max_pos = max_pos.max(chunk_pos)
	
	return {
		"min": min_pos,
		"max": max_pos,
		"world_min": get_world_position_from_chunk(min_pos),
		"world_max": get_world_position_from_chunk(max_pos) + Vector2i(CHUNK_SIZE, CHUNK_SIZE)
	}

func _on_chunk_tile_clicked(tile_position: Vector2i):
	"""Handle tile click events from chunks"""
	print("ChunkManager received tile_clicked signal for tile: ", tile_position)
	emit_signal("tile_clicked", tile_position)

func save_chunk_data(chunk_pos: Vector2i) -> Dictionary:
	"""Save chunk data to a dictionary for persistence"""
	var chunk = chunks.get(chunk_pos, null)
	if not chunk:
		return {}
	
	var data = {
		"chunk_position": chunk_pos,
		"tiles": []
	}
	
	# Save tile data
	for i in range(CHUNK_SIZE):
		for j in range(CHUNK_SIZE):
			var world_pos = chunk.get_world_position() + Vector2i(i, j)
			var tile = chunk.get_tile(world_pos)
			if tile:
				data["tiles"].append({
					"position": [i, j],
					"type": tile.type
				})
	
	return data

func load_chunk_data(data: Dictionary):
	"""Load chunk data from a dictionary"""
	if not data.has("chunk_position"):
		return
	
	var chunk_pos = data["chunk_position"]
	
	# Load the chunk if not already loaded
	if not chunks.has(chunk_pos):
		load_chunk(chunk_pos)
	
	var chunk = chunks[chunk_pos]
	
	# Load tile data
	if data.has("tiles"):
		for tile_data in data["tiles"]:
			if tile_data.has("position") and tile_data.has("type"):
				var local_pos = Vector2i(tile_data["position"][0], tile_data["position"][1])
				var world_pos = chunk.get_world_position() + local_pos
				chunk.set_tile(world_pos, tile_data["type"])

func get_debug_info() -> Dictionary:
	"""Get debug information about the chunk manager"""
	return {
		"loaded_chunks": get_chunk_count(),
		"chunk_positions": get_loaded_chunks(),
		"player_chunk": last_player_chunk,
		"player_world_pos": Vector2i(player.world_position) if player else Vector2i.ZERO,
		"load_distance": LOAD_DISTANCE,
		"unload_distance": UNLOAD_DISTANCE,
		"chunk_size": CHUNK_SIZE
	}

func cleanup():
	"""Clean up all chunks and disconnect signals"""
	print("Cleaning up chunk manager...")
	
	# Unload all chunks
	var chunk_positions = chunks.keys()
	for chunk_pos in chunk_positions:
		unload_chunk(chunk_pos)
	
	# Clear references
	chunks.clear()
	player = null
	world = null
	
	print("Chunk manager cleanup complete")

func _exit_tree():
	"""Clean up when chunk manager is removed"""
	cleanup() 