class_name PlayerCamera

static func setup_camera(parent):
	# Create camera
	var camera = Camera3D.new()
	camera.position = Vector3(8, 6, 8)  # Position camera at an angle above and to the side
	camera.look_at_from_position(Vector3(8, 6, 8), Vector3(5, 0, 5), Vector3.UP)  # Look at center of world
	parent.add_child(camera)
	
	# Make this camera the current camera
	camera.make_current()
	
	# Create directional light
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 10, 0)
	light.rotation = Vector3(-PI/4, 0, 0)  # Angle down at 45 degrees
	light.light_energy = 1.5
	parent.add_child(light)
	return camera
