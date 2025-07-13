extends Node3D
class_name World

const TILE_SIZE = 1.0  # Size of each tile in world units

var hovered: Vector2i = Vector2i(-1, -1)  # Track hovered tile position
var hovered_game_object: GameObject = null  # Track hovered GameObject
var player: Player
var camera: Camera3D
var chunk_manager: ChunkManager

var outline_shader = preload("res://new_out.gdshader")

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
	camera = PlayerCamera.setup_camera(self)
	
	# Create the player
	create_player()
	
	# Initialize chunk manager
	chunk_manager = ChunkManager.new(self, player)
	add_child(chunk_manager)
	
	# Connect tile click signal
	chunk_manager.tile_clicked.connect(_on_tile_clicked)
	
	# Load initial chunks around player
	var player_chunk_pos = chunk_manager.get_chunk_position_from_world(Vector2i(player.world_position))
	chunk_manager.update_chunks_around_player(player_chunk_pos)

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
	var new_hovered_game_object: GameObject = null
	
	if result:
		# Get the hit position and collider
		var hit_pos = result.position
		var collider = result.collider
		
		# Check if we hit a GameObject
		if collider is StaticBody3D:
			var parent = collider.get_parent()
			if parent is GameObject:
				new_hovered_game_object = parent as GameObject
			else:
				# Check if the StaticBody3D itself is a GameObject (though this shouldn't happen)
				if collider is GameObject:
					new_hovered_game_object = collider as GameObject
		
		# If we didn't hit a GameObject, check for tiles
		if not new_hovered_game_object:
			# Convert world position to tile position
			# Add 0.5 to offset the collision box center, then floor to get tile index
			var tile_pos = Vector2i(floor(hit_pos.x + 0.5), floor(hit_pos.z + 0.5))
			
			# Check if tile position is within loaded chunks
			if chunk_manager and chunk_manager.get_chunk_at_position(tile_pos):
				new_hovered = tile_pos
	
	# Update hovered tile and visual feedback
	if new_hovered != hovered:
		# Remove highlight from previous tile
		if hovered != Vector2i(-1, -1):
			var chunk = chunk_manager.get_chunk_at_position(hovered)
			if chunk:
				chunk.update_tile_outline(hovered, Color.BLACK)
		
		# Add highlight to new tile
		if new_hovered != Vector2i(-1, -1):
			var chunk = chunk_manager.get_chunk_at_position(new_hovered)
			if chunk:
				chunk.update_tile_outline(new_hovered, Color.GOLD)
		
		hovered = new_hovered
	
	# Update hovered GameObject
	if new_hovered_game_object != hovered_game_object:
		# Remove highlight from previous GameObject
		if hovered_game_object:
			hovered_game_object.is_hovered = false
			if hovered_game_object.outline_2d and is_instance_valid(hovered_game_object.outline_2d):
				hovered_game_object.outline_2d.visible = false
				hovered_game_object.outline_2d.queue_redraw()
			print("Mouse exited GameObject: ", hovered_game_object.name)
		
		# Add highlight to new GameObject
		if new_hovered_game_object:
			new_hovered_game_object.is_hovered = true
			if new_hovered_game_object.outline_2d and is_instance_valid(new_hovered_game_object.outline_2d):
				new_hovered_game_object.outline_2d.visible = true
				new_hovered_game_object.outline_2d.queue_redraw()
			print("Mouse entered GameObject: ", new_hovered_game_object.name)
		
		hovered_game_object = new_hovered_game_object

func _on_tile_clicked(tile_position: Vector2i):
	"""Handle tile click events from chunk manager"""
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



func find_closest_walkable_tile(clicked_tile: Vector2i, player_tile: Vector2i) -> Vector2i:
	# If the clicked tile is walkable, use it
	if chunk_manager and chunk_manager.is_tile_walkable(clicked_tile):
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
					
					# Check if tile is in a loaded chunk
					if not chunk_manager or not chunk_manager.get_chunk_at_position(check_tile):
						continue
					
					# If this tile is walkable
					if chunk_manager.is_tile_walkable(check_tile):
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
	# Use chunk manager to check if tile is walkable
	if chunk_manager:
		return chunk_manager.is_tile_walkable(tile_pos)
	return false

func create_game_objects():
	# This function is now handled by the chunk system
	# Objects are generated automatically within chunks
	pass

func create_test_objects():
	# This function is now handled by the chunk system
	# Objects are generated automatically within chunks
	pass

#func setup_camera():
	## Create camera
	#camera = Camera3D.new()
	#camera.position = Vector3(8, 6, 8)  # Position camera at an angle above and to the side
	#camera.look_at_from_position(Vector3(8, 6, 8), Vector3(5, 0, 5), Vector3.UP)  # Look at center of world
	#add_child(camera)
	#
	## Make this camera the current camera
	#camera.make_current()
	#
	## Create directional light
	#var light = DirectionalLight3D.new()
	#light.position = Vector3(0, 10, 0)
	#light.rotation = Vector3(-PI/4, 0, 0)  # Angle down at 45 degrees
	#light.light_energy = 1.5
	#add_child(light)
