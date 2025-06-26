extends Node3D
class_name World

const WORLD_SIZE = 10  # Size of the world in tiles
const TILE_SIZE = 1.0  # Size of each tile in world units

var hovered: Vector2i = Vector2i(-1, -1)  # Track hovered tile position
var player: Player
var camera: Camera3D
var tile_outlines = {}  # Store references to outline meshes for updating

class TileType:
	var name: String
	var walkable: bool
	var color: Color
	
	func _init(_name, _walk, _color):
		name = _name
		walkable = _walk
		color = _color

var TILE_TYPES = {
	TYLE.GRASS: TileType.new("Grass", true, Color.FOREST_GREEN),
	TYLE.STONE: TileType.new("Stone", true, Color.DARK_GRAY),
	TYLE.WATER: TileType.new("Water", false, Color.DARK_BLUE),
}

enum TYLE {
	GRASS,
	STONE,
	WATER,
}



# Simple struct to represent a tile
class WorldTile:
	var type: int
	
	func _init(tile_type: int = -1):
		if tile_type < 0:
			var rng = RandomNumberGenerator.new()
			type = rng.randi_range(0, 2)
		else: type = tile_type

var world_tiles = []

func _ready():
	# Create and setup camera
	setup_camera()
	
	# Create the player
	create_player()
	
	# Initialize the world with empty tiles
	world_tiles = _initialize_tiles()
	
	# Generate and render the world
	# generate_world()
	render_world(world_tiles)

func _process(delta):
	# Check for mouse hover every frame
	check_mouse_hover()

func create_player():
	# Create an instance of the Player class
	player = Player.new()
	add_child(player)
	print("Player added to world at: ", player.get_path())

func check_mouse_hover():
	# Get mouse position in viewport
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Create a ray from camera through mouse position
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	# Create a physics query
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Adjust collision mask as needed
	
	# Perform the raycast
	var result = space_state.intersect_ray(query)
	
	var new_hovered = Vector2i(-1, -1)
	
	if result:
		# Get the hit position
		var hit_pos = result.position
		
		# Convert world position to tile position
		# Add 0.5 to offset the collision box center, then floor to get tile index
		var tile_pos = Vector2i(floor(hit_pos.x + 0.5), floor(hit_pos.z + 0.5))
		
		# Check if tile position is within bounds
		if tile_pos.x >= 0 and tile_pos.x < WORLD_SIZE and tile_pos.y >= 0 and tile_pos.y < WORLD_SIZE:
			new_hovered = tile_pos
	
	# Update hovered tile and visual feedback
	if new_hovered != hovered:
		# Remove highlight from previous tile
		if hovered != Vector2i(-1, -1) and tile_outlines.has(hovered):
			update_tile_outline(hovered, Color.BLACK)
			print("Mouse exited tile: ", hovered)
		
		# Add highlight to new tile
		if new_hovered != Vector2i(-1, -1):
			update_tile_outline(new_hovered, Color.GOLD)
			print("Mouse entered tile: ", new_hovered)
		
		hovered = new_hovered

func update_tile_outline(tile_pos: Vector2i, color: Color):
	if tile_outlines.has(tile_pos):
		var outline = tile_outlines[tile_pos]
		var material = outline.material_override as StandardMaterial3D
		if material:
			material.albedo_color = color

func _initialize_tiles():
	var tiles =  []
	for i in range(WORLD_SIZE):
		var row = []
		for j in range(WORLD_SIZE):
			row.append(WorldTile.new())  # Initialize with grass tile type
		tiles.append(row)
	return tiles

func render_world(tiles: Array = []):
	if tiles == null:
		tiles = world_tiles
	
	print("Starting to render world...")
	# Render all tiles in the world
	for i in range(WORLD_SIZE):
		for j in range(WORLD_SIZE):
			var tile = tiles[i][j]
			render_tile(Vector2i(i, j), tile.type)
	
	print("Finished rendering world. Total tiles created: ", get_child_count())

func render_tile(tile_position: Vector2i, tile_type: int = 0):
	if tile_position.x < 0 or tile_position.x >= WORLD_SIZE or tile_position.y < 0 or tile_position.y >= WORLD_SIZE:
		return  # Out of bounds
	
	# Create a simple box mesh
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 0.5, 1.0)  # Width: 1, Height: 0.5, Depth: 1
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	# Position the tile - center of tile at grid position
	mesh_instance.position = Vector3(tile_position.x * TILE_SIZE, 0.25, tile_position.y * TILE_SIZE)
	
	# Set material color based on tile type
	var material = StandardMaterial3D.new()
	match tile_type:
		0: material.albedo_color = Color(0, 1, 0)      # Grass - bright green
		1: material.albedo_color = Color.WHITE          # Stone - using white
		2: material.albedo_color = Color.CYAN           # Water - using cyan
		_: material.albedo_color = Color.MAGENTA       # Default - using magenta
	
	material.albedo_color = TILE_TYPES[tile_type].color
	mesh_instance.material_override = material
	
	# Create outline wireframe - check if this is the hovered tile
	var outline_color = Color.GOLD if tile_position == hovered else Color.BLACK
	var outline_mesh = create_wireframe_mesh(Vector3(1.0, 0.5, 1.0))
	var outline_instance = MeshInstance3D.new()
	outline_instance.mesh = outline_mesh
	outline_instance.position = mesh_instance.position
	
	# Create outline material
	var outline_material = StandardMaterial3D.new()
	outline_material.albedo_color = outline_color
	outline_material.flags_unshaded = true
	outline_material.flags_transparent = true
	outline_material.albedo_color.a = 0.8
	outline_instance.material_override = outline_material
	
	# Store reference to outline for later updates
	tile_outlines[tile_position] = outline_instance
	
	# Add collision detection for clicking
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.0, 0.5, 1.0)  # Same size as mesh
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	
	# Connect input event to the static body
	static_body.input_event.connect(_on_tile_clicked.bind(tile_position))
	
	# Add the static body to the mesh instance
	mesh_instance.add_child(static_body)
	
	# Add to scene tree
	add_child(mesh_instance)
	add_child(outline_instance)
	
	# Debug output
	print("Created tile at position: ", tile_position, " with type: ", tile_type, " at world position: ", mesh_instance.position)

func create_wireframe_mesh(size: Vector3) -> Mesh:
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

func _on_tile_clicked(camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int, tile_position: Vector2i):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Clicked on tile at position: ", tile_position)
		
		# Get player's current tile position
		var player_tile_pos = Vector2i(floor(player.character_body.global_position.x), floor(player.character_body.global_position.z))
		
		# Find the closest walkable tile
		var target_tile = find_closest_walkable_tile(tile_position, player_tile_pos)
		
		if target_tile != Vector2i(-1, -1):
			# Set the player's target position to the walkable tile
			if player:
				player.target_position = Vector2(target_tile.x, target_tile.y)
				print("Player target set to walkable tile: ", player.target_position)
			else:
				print("Player not found!")
		else:
			print("No walkable tile found near: ", tile_position)

func find_closest_walkable_tile(clicked_tile: Vector2i, player_tile: Vector2i) -> Vector2i:
	# If the clicked tile is walkable, use it
	if is_tile_walkable(clicked_tile):
		return clicked_tile
	
	# If we clicked on the player's current tile, we're already as close as possible
	if clicked_tile == player_tile:
		return player_tile
	
	# Calculate distance from clicked tile to player's current position
	var distance_to_player = clicked_tile.distance_to(player_tile)
	
	# Start with distance 1 and expand outward
	var max_distance = 10  # Maximum search distance to prevent infinite loops
	var current_distance = 1
	
	while current_distance <= max_distance:
		# If we're searching farther than the player's current distance, stop
		if current_distance > distance_to_player:
			print("Stopping search - current distance (", current_distance, ") is farther than player distance (", distance_to_player, ")")
			break
		
		var closest_tile = Vector2i(-1, -1)
		var closest_distance = INF
		
		# Check all tiles at current_distance from the clicked tile
		for dx in range(-current_distance, current_distance + 1):
			for dy in range(-current_distance, current_distance + 1):
				# Only check tiles at exactly current_distance (on the perimeter)
				if abs(dx) == current_distance or abs(dy) == current_distance:
					var check_tile = Vector2i(clicked_tile.x + dx, clicked_tile.y + dy)
					
					# Check bounds
					if check_tile.x < 0 or check_tile.x >= WORLD_SIZE or check_tile.y < 0 or check_tile.y >= WORLD_SIZE:
						continue
					
					# If this tile is walkable
					if is_tile_walkable(check_tile):
						# Calculate distance to player
						var tile_distance_to_player = check_tile.distance_to(player_tile)
						
						# If we found a tile closer to the player than our current best
						if tile_distance_to_player < closest_distance:
							closest_distance = tile_distance_to_player
							closest_tile = check_tile
						
						# If this tile is the player's current tile, we can't get any closer
						if check_tile == player_tile:
							return player_tile
		
		# If we found a walkable tile at this distance, return it
		if closest_tile != Vector2i(-1, -1):
			print("Found walkable tile at distance ", current_distance, ": ", closest_tile, " (distance to player: ", closest_distance, ")")
			return closest_tile
		
		current_distance += 1
	
	# If we get here, no walkable tile was found within max_distance
	print("No walkable tile found within distance ", max_distance, " of ", clicked_tile)
	return Vector2i(-1, -1)

func is_tile_walkable(tile_pos: Vector2i) -> bool:
	# Check bounds
	if tile_pos.x < 0 or tile_pos.x >= WORLD_SIZE or tile_pos.y < 0 or tile_pos.y >= WORLD_SIZE:
		return false
	
	# Get the tile type
	var tile_type = world_tiles[tile_pos.x][tile_pos.y].type
	
	# Define which tile types are walkable
	return TILE_TYPES[tile_type].walkable

func setup_camera():
	# Create camera
	camera = Camera3D.new()
	camera.position = Vector3(8, 6, 8)  # Position camera at an angle above and to the side
	camera.look_at_from_position(Vector3(8, 6, 8), Vector3(5, 0, 5), Vector3.UP)  # Look at center of world
	add_child(camera)
	
	# Make this camera the current camera
	camera.make_current()
	
	# Create directional light
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 10, 0)
	light.rotation = Vector3(-PI/4, 0, 0)  # Angle down at 45 degrees
	light.light_energy = 1.5
	add_child(light)
