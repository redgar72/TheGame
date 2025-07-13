extends Node
class_name Player

signal position_changed(new_position: Vector2)
signal chunk_changed(new_chunk: Vector2i)

var world_position = Vector2(5, 5)  # Center tile position
var target_position = Vector2(5, 5)
var character_body: CharacterBody3D
var move_speed = 3.0  # Units per second
var current_chunk = Vector2i(0, 0)  # Track current chunk position

func _ready():
	create_character()
	# Initialize current chunk
	current_chunk = get_chunk_position_from_world(Vector2i(world_position))

func _process(delta):
	# Move towards target position
	move_towards_target(delta)

func create_character():
	# Create the CharacterBody3D
	character_body = CharacterBody3D.new()
	add_child(character_body)
	
	# Create the capsule collision shape
	var collision_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.5
	capsule_shape.height = 2.0
	collision_shape.shape = capsule_shape
	collision_shape.transform.origin.y = 1.0  # Position the collider at the center of the capsule
	character_body.add_child(collision_shape)
	
	# Create the visual capsule mesh
	var mesh_instance = MeshInstance3D.new()
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = 0.5
	capsule_mesh.height = 2.0
	mesh_instance.mesh = capsule_mesh
	mesh_instance.transform.origin.y = 1.0  # Position the mesh at the center of the capsule
	character_body.add_child(mesh_instance)
	
	# Create a blue material for the capsule
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLUE
	mesh_instance.material_override = material
	
	# Set initial position to center tile (5, 5) with proper height
	character_body.global_position = Vector3(world_position.x, 1.0, world_position.y)
	
	print("Player created at position: ", character_body.global_position)

func move_towards_target(delta):
	# Convert target position to 3D world position
	var target_world_pos = Vector3(target_position.x, 1.0, target_position.y)
	
	# Calculate distance to target
	var distance = character_body.global_position.distance_to(target_world_pos)
	
	# If we're not at the target, move towards it
	if distance > 0.1:  # Small threshold to prevent jittering
		var direction = (target_world_pos - character_body.global_position).normalized()
		character_body.global_position += direction * move_speed * delta
		
		# Update world_position to match current position
		var new_world_position = Vector2(character_body.global_position.x, character_body.global_position.z)
		world_position = new_world_position
		
		# Check if we've moved to a new chunk
		var new_chunk = get_chunk_position_from_world(Vector2i(world_position))
		if new_chunk != current_chunk:
			current_chunk = new_chunk
			chunk_changed.emit(current_chunk)
		
		# Optional: Make the character face the direction it's moving
		if direction.length() > 0.1:
			character_body.look_at(target_world_pos, Vector3.UP)

func get_chunk_position_from_world(world_pos: Vector2i) -> Vector2i:
	"""Convert world position to chunk position"""
	const CHUNK_SIZE = 16
	return Vector2i(floor(world_pos.x / float(CHUNK_SIZE)), floor(world_pos.y / float(CHUNK_SIZE)))
