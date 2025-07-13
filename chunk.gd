extends Node
class_name Chunk

signal tile_clicked(tile_position: Vector2i)

const CHUNK_SIZE = 16  # Size of each chunk in tiles
const TILE_SIZE = 1.0  # Size of each tile in world units

var chunk_position: Vector2i  # Position of this chunk in chunk coordinates
var tiles = []  # 2D array of tiles in this chunk
var objects = []  # Array of GameObjects in this chunk
var rendered_tiles = {}  # Dictionary to track rendered tile meshes
var tile_outlines = {}  # Store references to outline meshes for updating
var is_loaded = false  # Whether this chunk is currently loaded/rendered

# Tile types enum (matching world.gd)
enum TILE_TYPE {
	GRASS,
	STONE,
	WATER,
}

# Tile type definitions (matching world.gd)
var TILE_TYPES = {
	TILE_TYPE.GRASS: {"name": "Grass", "walkable": true, "color": Color.FOREST_GREEN},
	TILE_TYPE.STONE: {"name": "Stone", "walkable": true, "color": Color.DARK_GRAY},
	TILE_TYPE.WATER: {"name": "Water", "walkable": false, "color": Color.DARK_BLUE},
}

# Simple struct to represent a tile
class WorldTile:
	var type: int
	
	func _init(tile_type: int = -1):
		if tile_type < 0:
			var rng = RandomNumberGenerator.new()
			type = rng.randi_range(0, 2)
		else: 
			type = tile_type

func _init(pos: Vector2i):
	chunk_position = pos
	_initialize_tiles()

func _initialize_tiles():
	# Initialize the tiles array
	tiles = []
	for i in range(CHUNK_SIZE):
		var row = []
		for j in range(CHUNK_SIZE):
			row.append(WorldTile.new())
		tiles.append(row)

func get_world_position() -> Vector2i:
	"""Convert chunk position to world position (top-left corner of chunk)"""
	return chunk_position * CHUNK_SIZE

func get_chunk_position_from_world(world_pos: Vector2i) -> Vector2i:
	"""Convert world position to chunk position"""
	return Vector2i(floor(world_pos.x / float(CHUNK_SIZE)), floor(world_pos.y / float(CHUNK_SIZE)))

func get_local_position_from_world(world_pos: Vector2i) -> Vector2i:
	"""Convert world position to local position within this chunk"""
	return Vector2i(world_pos.x % CHUNK_SIZE, world_pos.y % CHUNK_SIZE)

func is_position_in_chunk(world_pos: Vector2i) -> bool:
	"""Check if a world position is within this chunk"""
	var chunk_world_pos = get_world_position()
	return (world_pos.x >= chunk_world_pos.x and 
			world_pos.x < chunk_world_pos.x + CHUNK_SIZE and
			world_pos.y >= chunk_world_pos.y and 
			world_pos.y < chunk_world_pos.y + CHUNK_SIZE)

func get_tile(world_pos: Vector2i) -> WorldTile:
	"""Get tile at world position"""
	if not is_position_in_chunk(world_pos):
		return null
	
	var local_pos = get_local_position_from_world(world_pos)
	return tiles[local_pos.x][local_pos.y]

func set_tile(world_pos: Vector2i, tile_type: int):
	"""Set tile at world position"""
	if not is_position_in_chunk(world_pos):
		return
	
	var local_pos = get_local_position_from_world(world_pos)
	tiles[local_pos.x][local_pos.y].type = tile_type
	
	# Update rendered tile if chunk is loaded
	if is_loaded:
		update_tile_visual(world_pos, tile_type)

func render_chunk():
	"""Render all tiles in this chunk"""
	if is_loaded:
		return  # Already rendered
	
	print("Rendering chunk at position: ", chunk_position)
	
	for i in range(CHUNK_SIZE):
		for j in range(CHUNK_SIZE):
			var world_pos = get_world_position() + Vector2i(i, j)
			var tile = tiles[i][j]
			render_tile(world_pos, tile.type)
	
	is_loaded = true
	print("Finished rendering chunk at: ", chunk_position)

func unload_chunk():
	"""Remove all rendered tiles and objects from this chunk"""
	if not is_loaded:
		return
	
	print("Unloading chunk at position: ", chunk_position)
	
	# Remove all rendered tiles
	for tile_mesh in rendered_tiles.values():
		if is_instance_valid(tile_mesh):
			tile_mesh.queue_free()
	rendered_tiles.clear()
	
	# Remove all tile outlines
	for outline in tile_outlines.values():
		if is_instance_valid(outline):
			outline.queue_free()
	tile_outlines.clear()
	
	# Remove all objects
	for obj in objects:
		if is_instance_valid(obj):
			obj.queue_free()
	objects.clear()
	
	is_loaded = false
	print("Finished unloading chunk at: ", chunk_position)

func render_tile(world_pos: Vector2i, tile_type: int):
	"""Render a single tile at world position"""
	# Create a simple box mesh
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 0.5, 1.0)  # Width: 1, Height: 0.5, Depth: 1
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	# Position the tile - center of tile at grid position
	mesh_instance.position = Vector3(world_pos.x * TILE_SIZE, 0.25, world_pos.y * TILE_SIZE)
	
	# Set material color based on tile type
	var material = StandardMaterial3D.new()
	if tile_type < TILE_TYPES.size():
		material.albedo_color = TILE_TYPES[tile_type]["color"]
	else:
		material.albedo_color = Color.MAGENTA  # Default color
	
	mesh_instance.material_override = material
	
	# Create outline wireframe
	var outline_mesh = create_wireframe_mesh(Vector3(1.0, 0.5, 1.0))
	var outline_instance = MeshInstance3D.new()
	outline_instance.mesh = outline_mesh
	outline_instance.position = mesh_instance.position
	
	# Create outline material
	var outline_material = StandardMaterial3D.new()
	outline_material.albedo_color = Color.BLACK
	outline_material.flags_unshaded = true
	outline_material.flags_transparent = true
	outline_material.albedo_color.a = 0.8
	outline_instance.material_override = outline_material
	
	# Add collision detection for clicking
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.0, 0.5, 1.0)  # Same size as mesh
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	
	# Connect input event to the static body
	static_body.input_event.connect(_on_tile_clicked.bind(world_pos))
	
	# Add the static body to the mesh instance
	mesh_instance.add_child(static_body)
	
	# Add to scene tree
	add_child(mesh_instance)
	add_child(outline_instance)
	
	# Store references for later updates
	rendered_tiles[world_pos] = mesh_instance
	tile_outlines[world_pos] = outline_instance

func update_tile_visual(world_pos: Vector2i, tile_type: int):
	"""Update the visual appearance of a tile"""
	if not rendered_tiles.has(world_pos):
		return
	
	var mesh_instance = rendered_tiles[world_pos]
	var material = mesh_instance.material_override as StandardMaterial3D
	if material and tile_type < TILE_TYPES.size():
		material.albedo_color = TILE_TYPES[tile_type]["color"]

func update_tile_outline(world_pos: Vector2i, color: Color):
	"""Update the outline color of a tile"""
	if tile_outlines.has(world_pos):
		var outline = tile_outlines[world_pos]
		var material = outline.material_override as StandardMaterial3D
		if material:
			material.albedo_color = color

func create_wireframe_mesh(size: Vector3) -> Mesh:
	"""Create a wireframe mesh for tile outlines"""
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	# Calculate half sizes
	var half_x = size.x / 2.0
	var half_y = size.y / 2.0
	var half_z = size.z / 2.0
	
	# Define the 8 vertices of a box
	var vertices = [
		Vector3(-half_x, -half_y, -half_z),  # 0: bottom front left
		Vector3(half_x, -half_y, -half_z),   # 1: bottom front right
		Vector3(half_x, -half_y, half_z),    # 2: bottom back right
		Vector3(-half_x, -half_y, half_z),   # 3: bottom back left
		Vector3(-half_x, half_y, -half_z),   # 4: top front left
		Vector3(half_x, half_y, -half_z),    # 5: top front right
		Vector3(half_x, half_y, half_z),     # 6: top back right
		Vector3(-half_x, half_y, half_z)     # 7: top back left
	]
	
	# Define the 12 edges of a box (each edge as 2 vertices)
	var edges = [
		# Bottom face
		[0, 1], [1, 2], [2, 3], [3, 0],
		# Top face
		[4, 5], [5, 6], [6, 7], [7, 4],
		# Vertical edges
		[0, 4], [1, 5], [2, 6], [3, 7]
	]
	
	# Add all edges
	for edge in edges:
		surface_tool.add_vertex(vertices[edge[0]])
		surface_tool.add_vertex(vertices[edge[1]])
	
	surface_tool.index()
	return surface_tool.commit()

func render_object(object: GameObject):
	"""Add a GameObject to this chunk"""
	if not objects.has(object):
		objects.append(object)
		add_child(object)
		print("Added object ", object.name, " to chunk at: ", chunk_position)

func remove_object(object: GameObject):
	"""Remove a GameObject from this chunk"""
	if objects.has(object):
		objects.erase(object)
		if is_instance_valid(object):
			remove_child(object)
		print("Removed object ", object.name, " from chunk at: ", chunk_position)

func generate_chunk(size: int = CHUNK_SIZE):
	"""Generate procedural content for this chunk"""
	print("Generating chunk at position: ", chunk_position)
	
	# Use the chunk position as a seed for consistent generation
	var rng = RandomNumberGenerator.new()
	var seed_value = chunk_position.x * 1000 + chunk_position.y
	rng.seed = seed_value
	
	# Generate terrain
	for i in range(size):
		for j in range(size):
			var world_pos = get_world_position() + Vector2i(i, j)
			
			# Simple noise-based generation
			var noise_value = rng.randf()
			var tile_type = TILE_TYPE.GRASS  # Default
			
			if noise_value < 0.1:
				tile_type = TILE_TYPE.WATER
			elif noise_value < 0.3:
				tile_type = TILE_TYPE.STONE
			
			set_tile(world_pos, tile_type)
	
	# Generate objects (trees, rocks, etc.)
	generate_objects(rng)
	
	# Render the chunk after generation is complete
	call_deferred("render_chunk")
	
	print("Finished generating chunk at: ", chunk_position)

func generate_objects(rng: RandomNumberGenerator):
	"""Generate objects within this chunk"""
	var num_objects = rng.randi_range(0, 3)  # Reduced from 5 to 3 for performance
	
	for i in range(num_objects):
		var local_pos = Vector2i(rng.randi_range(0, CHUNK_SIZE-1), rng.randi_range(0, CHUNK_SIZE-1))
		var world_pos = get_world_position() + local_pos
		
		# Only place objects on walkable tiles
		var tile = get_tile(world_pos)
		if tile and TILE_TYPES[tile.type]["walkable"]:
			# Random object type
			var object_type = rng.randi_range(0, 2)
			var obj_name = ""
			var obj_mesh = null
			
			match object_type:
				0:  # Tree
					obj_name = "Tree"
					obj_mesh = preload("res://assets/GreyTree.obj")
				1:  # Rock
					obj_name = "Rock"
					obj_mesh = preload("res://assets/Rock_01.obj")
				2:  # Bush
					obj_name = "Bush"
					obj_mesh = preload("res://assets/Bush_01.obj")
			
			if obj_mesh:
				var obj = GameObject.new(
					obj_name + "_" + str(i),
					{
						"Interact": func(): print("Interacting with ", obj_name),
						"Examine": func(): print("Examining ", obj_name)
					},
					world_pos
				)
				
				obj.mesh = obj_mesh
				var material = StandardMaterial3D.new()
				obj.set_surface_override_material(0, material)
				
				var tile_position = Vector3(world_pos.x * TILE_SIZE, 0.5, world_pos.y * TILE_SIZE)
				obj.position = tile_position
				
				# Add object directly to avoid deferred call issues
				render_object(obj)

func _on_tile_clicked(camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int, tile_position: Vector2i):
	"""Handle tile click events"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Clicked on tile at position: ", tile_position, " in chunk: ", chunk_position)
		
		# Emit signal to notify world of tile click
		# This will be handled by the chunk manager
		if has_signal("tile_clicked"):
			print("Emitting tile_clicked signal for tile: ", tile_position)
			emit_signal("tile_clicked", tile_position)
		else:
			print("Warning: tile_clicked signal not found in chunk")

func is_tile_walkable(world_pos: Vector2i) -> bool:
	"""Check if a tile at world position is walkable"""
	var tile = get_tile(world_pos)
	if tile and tile.type < TILE_TYPES.size():
		return TILE_TYPES[tile.type]["walkable"]
	return false

func get_chunk_bounds() -> Array:
	"""Get the world bounds of this chunk"""
	var world_pos = get_world_position()
	return [
		world_pos,  # Top-left
		world_pos + Vector2i(CHUNK_SIZE, CHUNK_SIZE)  # Bottom-right
	]
	
