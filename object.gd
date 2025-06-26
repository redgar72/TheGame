extends MeshInstance3D
class_name GameObject

var actions
var tile: Vector2i
var mesh_instance: MeshInstance3D
var is_hovered: bool = false
var outline_2d: Control
var collision_body: StaticBody3D
var world_camera: Camera3D
var hover_timer: Timer

class Action:
	var callback: Callable
	var name: String
	
	func _init(_name, _callback):
		callback = _callback
		name = _name

func _init(_name, _actions, _tile) -> void:
	self.name = _name
	self.actions = _actions
	self.tile = _tile

func _ready():
	# Setup collision detection
	setup_collision()
	
	# Setup 2D outline
	setup_2d_outline()
	
	# Setup hover timer
	setup_hover_timer()
	
	# Connect input events
	if collision_body:
		collision_body.input_event.connect(_on_input_event)

func setup_collision():
	# Create collision body
	collision_body = StaticBody3D.new()
	add_child(collision_body)
	
	# Create collision shape based on mesh bounds
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	
	# Get mesh bounds and create appropriate collision shape
	if mesh:
		var aabb = mesh.get_aabb()
		shape.size = aabb.size
		collision_shape.position = aabb.position + aabb.size * 0.5
	else:
		# Default collision shape if no mesh
		shape.size = Vector3(1.0, 2.0, 1.0)
		collision_shape.position = Vector3(0, 1.0, 0)
	
	collision_shape.shape = shape
	collision_body.add_child(collision_shape)

func setup_2d_outline():
	# Create 2D outline control
	outline_2d = Control.new()
	outline_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline_2d.visible = false
	
	# Connect the draw function
	outline_2d.draw.connect(_draw_outline)
	
	# Add to the UI layer (assuming there's a CanvasLayer or Control node for UI)
	var ui_layer = get_tree().get_root().get_node_or_null("UI")
	if not ui_layer:
		# Create UI layer if it doesn't exist
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		get_tree().get_root().add_child(ui_layer)
	
	ui_layer.add_child(outline_2d)

func _process(delta):
	# Get camera reference if not set
	if not world_camera:
		world_camera = get_viewport().get_camera_3d()
	
	# Only update outline if it's visible
	if outline_2d and world_camera and outline_2d.visible:
		update_2d_outline()

func update_2d_outline():
	if not world_camera:
		return
	
	# If no mesh, use a default bounding box
	var aabb: AABB
	if mesh:
		aabb = mesh.get_aabb()
	else:
		# Default bounding box
		aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1.0, 2.0, 1.0))
	
	var object_transform = global_transform
	
	# Get the 8 corners of the bounding box
	var corners = []
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				var local_pos = Vector3(x * aabb.size.x * 0.5, y * aabb.size.y * 0.5, z * aabb.size.z * 0.5) + aabb.position + aabb.size * 0.5
				var world_pos = object_transform * local_pos
				corners.append(world_pos)
	
	# Project all corners to screen space
	var screen_corners = []
	for corner in corners:
		var screen_pos = world_camera.unproject_position(corner)
		# Handle both Vector2 and Vector3 return types
		if screen_pos is Vector3:
			if screen_pos.z > 0:  # Only include corners in front of camera
				screen_corners.append(Vector2(screen_pos.x, screen_pos.y))
		elif screen_pos is Vector2:
			# If it returns Vector2, assume it's in front of camera
			screen_corners.append(screen_pos)
	
	if screen_corners.size() < 3:
		outline_2d.visible = false
		return
	
	# Calculate bounding rectangle
	var min_pos = screen_corners[0]
	var max_pos = screen_corners[0]
	for pos in screen_corners:
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	
	# Add padding
	var padding = 10.0
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)
	
	# Update outline position and size
	outline_2d.position = min_pos
	outline_2d.size = max_pos - min_pos
	
	# Force redraw
	outline_2d.queue_redraw()

func _draw_outline():
	# Draw the outline
	var rect = Rect2(Vector2.ZERO, outline_2d.size)
	var color = Color.GOLD if is_hovered else Color.WHITE
	var thickness = 4.0 if is_hovered else 2.0
	
	# Draw a glowing effect for hovered objects
	if is_hovered:
		# Draw outer glow
		var glow_color = Color.GOLD
		glow_color.a = 0.3
		outline_2d.draw_rect(rect.grow(2), glow_color, true)
		# Draw inner glow
		glow_color.a = 0.2
		outline_2d.draw_rect(rect.grow(-2), glow_color, true)
	
	# Draw main outline
	outline_2d.draw_rect(rect, Color.TRANSPARENT)
	outline_2d.draw_rect(rect, color, false, thickness)
	
	# Draw corner indicators for hovered objects
	if is_hovered:
		var corner_size = 8.0
		var corners = [
			Vector2(0, 0),  # Top-left
			Vector2(rect.size.x, 0),  # Top-right
			Vector2(rect.size.x, rect.size.y),  # Bottom-right
			Vector2(0, rect.size.y)  # Bottom-left
		]
		
		for corner in corners:
			var corner_rect = Rect2(corner - Vector2(corner_size/2, corner_size/2), Vector2(corner_size, corner_size))
			outline_2d.draw_rect(corner_rect, Color.GOLD, true)

func setup_hover_timer():
	# Create timer for hover exit detection
	hover_timer = Timer.new()
	hover_timer.wait_time = 0.1  # Check every 0.1 seconds
	hover_timer.timeout.connect(_check_hover_exit)
	add_child(hover_timer)

func _check_hover_exit():
	if is_hovered and world_camera:
		# Check if mouse is still over the object
		var mouse_pos = get_viewport().get_mouse_position()
		var object_screen_pos = world_camera.unproject_position(global_position)
		
		# Handle both Vector2 and Vector3 return types
		if object_screen_pos is Vector3:
			# Check if object is in front of camera
			if object_screen_pos.z > 0:
				# Simple distance check - if mouse is far from object center, consider it exited
				var distance = mouse_pos.distance_to(Vector2(object_screen_pos.x, object_screen_pos.y))
				if distance > 100:  # Threshold for mouse exit
					is_hovered = false
					if outline_2d:
						outline_2d.visible = false
						outline_2d.queue_redraw()
					print("Mouse exited: ", name)
			else:
				# Object is behind camera, hide outline
				is_hovered = false
				if outline_2d:
					outline_2d.visible = false
					outline_2d.queue_redraw()
				print("Object behind camera: ", name)
		elif object_screen_pos is Vector2:
			# If it returns Vector2, assume it's in front of camera
			var distance = mouse_pos.distance_to(object_screen_pos)
			if distance > 100:  # Threshold for mouse exit
				is_hovered = false
				if outline_2d:
					outline_2d.visible = false
					outline_2d.queue_redraw()
				print("Mouse exited: ", name)

func _on_input_event(camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int):
	if event is InputEventMouseMotion:
		if not is_hovered:
			is_hovered = true
			if outline_2d:
				outline_2d.visible = true
				outline_2d.queue_redraw()
			print("Hovered over: ", name)
		
		# Reset hover timer
		if hover_timer:
			hover_timer.start()
			
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Clicked on: ", name)
		# Handle click actions here
		if actions.has("Interact"):
			actions["Interact"].call()

func _input_event(camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int):
	# This is a fallback method for input events
	_on_input_event(camera, event, position, normal, shape_idx)

func _exit_tree():
	# Clean up 2D outline when object is removed
	if outline_2d and is_instance_valid(outline_2d):
		outline_2d.queue_free()

static func create_tree(world_node: Node3D) -> GameObject:
	var mesh = preload("res://assets/GreyTree.obj")
	
	var tree = GameObject.new(
		"First Tree",
		{
		"Gather": func gather(): print("Gather from the tree"),
		"Interact": func interact(): print("Interacting with the tree")
		},
		Vector2i(3, 3)
	)
	
	# Store the mesh instance
	tree.mesh = mesh
	
	# Position the tree on top of the specified tile
	# Assuming tile size is 1.0 and tree should sit on top of the tile
	var tile_position = Vector3(tree.tile.x * 1.0, 0.5, tree.tile.y * 1.0)  # 0.5 is half tile height
	tree.position = tile_position
	
	# Add the tree to the world
	world_node.add_child(tree)
	
	print("Tree created and positioned at tile: ", tree.tile, " world position: ", tile_position)
	
	return tree
