extends Node

# Test script for hover system
func _ready():
	print("Testing hover system...")
	
	# Test GameObject creation
	var test_world = Node3D.new()
	add_child(test_world)
	
	# Create a test GameObject
	var test_obj = GameObject.new(
		"Test Object",
		{
			"Interact": func(): print("Test interaction"),
			"Examine": func(): print("Test examination")
		},
		Vector2i(0, 0)
	)
	
	test_world.add_child(test_obj)
	
	# Test if GameObject has required properties
	print("Test object created: ", test_obj.name)
	print("Has collision body: ", test_obj.collision_body != null)
	print("Has outline 2D: ", test_obj.outline_2d != null)
	print("Has hover timer: ", test_obj.hover_timer != null)
	
	print("Hover system test completed!") 