# GameObject Hover System

This implementation adds a hover event system for GameObjects that creates a highlighted border around their 2D outline from the camera's perspective.

## Features

- **2D Outline Projection**: Projects the 3D mesh bounds to screen space to create a 2D outline
- **Hover Detection**: Detects when the mouse hovers over GameObjects using raycasting
- **Visual Feedback**: Shows a glowing golden border with corner indicators when hovering
- **Click Interaction**: Supports click events for object interaction
- **Automatic Cleanup**: Properly cleans up UI elements when objects are removed

## How It Works

### 1. GameObject Setup
Each GameObject automatically sets up:
- **Collision Detection**: Creates a StaticBody3D with collision shape based on mesh bounds
- **2D Outline**: Creates a Control node for drawing the 2D outline
- **Hover Timer**: Timer-based system for reliable hover exit detection

### 2. Hover Detection
The system uses two approaches:
- **Raycast Detection**: Main detection through the world's `check_mouse_hover()` function
- **Timer-based Fallback**: Backup detection using a timer to check mouse distance

### 3. Visual Feedback
When hovering over a GameObject:
- Golden glowing border appears around the object's 2D projection
- Corner indicators show at the four corners of the outline
- Outline updates in real-time as the camera moves

## Usage

### Creating GameObjects
```gdscript
var obj = GameObject.new(
	"My Object",
	{
		"Interact": func(): print("Interacting with object"),
		"Examine": func(): print("Examining object")
	},
	Vector2i(5, 5)  # Tile position
)

obj.mesh = preload("res://path/to/mesh.obj")
obj.position = Vector3(5, 0.5, 5)  # World position
world.add_child(obj)
```

### Customizing Actions
GameObjects can have multiple actions defined:
```gdscript
var actions = {
	"Interact": func(): print("Primary interaction"),
	"Examine": func(): print("Examine object"),
	"Use": func(): print("Use object"),
	"Destroy": func(): print("Destroy object")
}
```

### Visual Customization
The outline appearance can be customized by modifying the `_draw_outline()` function:
- Change colors for hovered vs non-hovered states
- Adjust outline thickness
- Modify glow effects
- Add custom visual elements

## Technical Details

### Components
- **GameObject**: Main class extending MeshInstance3D
- **StaticBody3D**: Collision detection
- **Control**: 2D outline rendering
- **Timer**: Hover exit detection

### Key Methods
- `setup_collision()`: Creates collision body and shape
- `setup_2d_outline()`: Creates and configures 2D outline
- `update_2d_outline()`: Projects 3D bounds to screen space
- `_draw_outline()`: Renders the visual outline
- `_on_input_event()`: Handles mouse input events

### Camera Integration
The system automatically finds the active camera and uses it to:
- Project 3D world positions to screen coordinates
- Calculate object visibility
- Update outline positions in real-time

## Performance Considerations

- Outlines are only updated when visible
- Timer-based hover detection reduces unnecessary checks
- Automatic cleanup prevents memory leaks
- Efficient raycasting for hover detection

## Future Enhancements

- Support for different outline styles
- Animation effects for hover transitions
- Custom outline shapes based on mesh geometry
- Multi-object selection support
- Tooltip system integration 
