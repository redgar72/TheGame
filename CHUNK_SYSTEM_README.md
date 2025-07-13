# Chunk Management System

This document describes the chunk management system implemented for the PhatCat game. The system divides the world into chunks for better performance and memory management.

## Overview

The chunk system consists of three main components:

1. **Chunk** (`chunk.gd`) - Individual chunk that manages tiles and objects
2. **ChunkManager** (`chunk_manager.gd`) - Manages loading/unloading of chunks based on player position
3. **World** (`world.gd`) - Updated to use the chunk system instead of a fixed-size world

## Key Features

### Chunk System
- **Chunk Size**: 16x16 tiles per chunk
- **Dynamic Loading**: Chunks load/unload based on player position
- **Procedural Generation**: Each chunk generates terrain and objects procedurally
- **Memory Management**: Unused chunks are automatically unloaded
- **Tile Management**: Individual tiles can be queried and modified
- **Object Management**: GameObjects are stored within chunks

### Performance Benefits
- **Reduced Memory Usage**: Only nearby chunks are loaded
- **Better Performance**: Smaller render batches and collision checks
- **Scalable World**: World can be infinitely large
- **Efficient Updates**: Only loaded chunks are updated

## Architecture

### Chunk Class (`chunk.gd`)

```gdscript
class_name Chunk
extends Node

signal tile_clicked(tile_position: Vector2i)

const CHUNK_SIZE = 16
const TILE_SIZE = 1.0

var chunk_position: Vector2i
var tiles = []  # 2D array of WorldTile objects
var objects = []  # Array of GameObjects
var rendered_tiles = {}  # Dictionary of rendered meshes
var is_loaded = false
```

**Key Methods:**
- `render_chunk()` - Renders all tiles in the chunk
- `unload_chunk()` - Removes all rendered content
- `generate_chunk()` - Generates procedural content
- `get_tile(world_pos)` - Get tile at world position
- `set_tile(world_pos, type)` - Set tile at world position
- `is_tile_walkable(world_pos)` - Check if tile is walkable

### ChunkManager Class (`chunk_manager.gd`)

```gdscript
class_name ChunkManager
extends Node

const LOAD_DISTANCE = 2  # Chunks to load around player
const UNLOAD_DISTANCE = 4  # Distance to unload chunks

var chunks = {}  # Dictionary of loaded chunks
var player: Player
var world: Node3D
```

**Key Methods:**
- `update_chunks_around_player(chunk_pos)` - Load/unload chunks based on player position
- `load_chunk(chunk_pos)` - Load and render a chunk
- `unload_chunk(chunk_pos)` - Unload and remove a chunk
- `get_chunk_at_position(world_pos)` - Get chunk at world position
- `is_tile_walkable(world_pos)` - Check if tile is walkable across chunks

## Usage

### Basic Setup

```gdscript
# In world.gd
func _ready():
    # Create player
    create_player()
    
    # Initialize chunk manager
    chunk_manager = ChunkManager.new(self, player)
    add_child(chunk_manager)
    
    # Connect tile click signal
    chunk_manager.tile_clicked.connect(_on_tile_clicked)
    
    # Load initial chunks
    var player_chunk_pos = chunk_manager.get_chunk_position_from_world(Vector2i(player.world_position))
    chunk_manager.update_chunks_around_player(player_chunk_pos)
```

### Tile Operations

```gdscript
# Get tile at position
var tile = chunk_manager.get_tile_at_position(Vector2i(10, 15))

# Set tile type
chunk_manager.set_tile_at_position(Vector2i(10, 15), Chunk.TILE_TYPE.STONE)

# Check if tile is walkable
var walkable = chunk_manager.is_tile_walkable(Vector2i(10, 15))
```

### Object Management

```gdscript
# Add object to chunk
var obj = GameObject.new("Tree", actions, Vector2i(10, 15))
chunk_manager.add_object_to_chunk(obj, Vector2i(10, 15))

# Remove object from chunk
chunk_manager.remove_object_from_chunk(obj, Vector2i(10, 15))
```

## Tile Types

The system supports three tile types:

```gdscript
enum TILE_TYPE {
    GRASS,   # Walkable, green
    STONE,   # Walkable, gray
    WATER    # Not walkable, blue
}
```

## Procedural Generation

Each chunk generates content using:
- **Seed-based generation** for consistency
- **Noise-based terrain** (grass, stone, water)
- **Random object placement** (trees, rocks, bushes)
- **Walkable tile validation** for object placement

## Performance Considerations

### Loading Distance
- **LOAD_DISTANCE = 2**: Loads 5x5 chunks around player (25 chunks total)
- **UNLOAD_DISTANCE = 4**: Unloads chunks beyond 4 chunk distance

### Memory Management
- Chunks are automatically unloaded when player moves away
- Rendered meshes and objects are properly cleaned up
- Tile data is preserved until chunk is unloaded

### Optimization Tips
- Adjust LOAD_DISTANCE based on performance requirements
- Use chunk bounds for spatial queries
- Batch operations when possible
- Consider LOD (Level of Detail) for distant chunks

## Debugging

### Debug Information
```gdscript
var debug_info = chunk_manager.get_debug_info()
print("Loaded chunks: ", debug_info.loaded_chunks)
print("Player chunk: ", debug_info.player_chunk)
```

### Manual Chunk Operations
```gdscript
# Force load specific chunk
chunk_manager.force_load_chunk(Vector2i(5, 5))

# Force unload specific chunk
chunk_manager.force_unload_chunk(Vector2i(5, 5))

# Reload all chunks
chunk_manager.reload_all_chunks()
```

## Integration with Existing Systems

### Player Movement
- Player position changes trigger chunk updates
- Movement is restricted to walkable tiles
- Pathfinding works across chunk boundaries

### Mouse Interaction
- Tile hover detection works with chunk system
- Click events are forwarded through chunk manager
- Object interaction remains unchanged

### Camera System
- Camera follows player as before
- No changes needed for camera functionality

## Future Enhancements

### Planned Features
- **Chunk Persistence**: Save/load chunk data to files
- **Multi-threading**: Generate chunks in background threads
- **LOD System**: Different detail levels for distant chunks
- **Chunk Streaming**: Load chunks asynchronously
- **Chunk Caching**: Cache frequently accessed chunks

### Optimization Opportunities
- **Mesh Instancing**: Share meshes between similar tiles
- **Frustum Culling**: Only render visible chunks
- **Occlusion Culling**: Skip hidden tiles
- **Texture Atlasing**: Combine tile textures

## Troubleshooting

### Common Issues

1. **Chunks not loading**: Check player position and chunk manager initialization
2. **Performance issues**: Reduce LOAD_DISTANCE or optimize chunk generation
3. **Memory leaks**: Ensure chunks are properly unloaded
4. **Tile access errors**: Verify chunk is loaded before accessing tiles

### Debug Commands
```gdscript
# Print chunk information
print("Chunk count: ", chunk_manager.get_chunk_count())
print("Loaded chunks: ", chunk_manager.get_loaded_chunks())

# Check specific tile
var tile = chunk_manager.get_tile_at_position(Vector2i(10, 15))
print("Tile type: ", tile.type if tile else "null")
```

## Conclusion

The chunk management system provides a scalable foundation for large worlds while maintaining good performance. The modular design allows for easy extension and optimization as the game grows. 