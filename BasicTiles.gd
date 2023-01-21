tool
extends TileMap

const GRASS = 1
const STONE = 2
const WALL = 3

var binds = {
	GRASS: [STONE],
	GRASS: [WALL],
	STONE: [GRASS],
	STONE: [WALL],
	WALL: [STONE],
	WALL: [GRASS]
}

func _is_tile_bound(drawn_id, neighbour_id):
	if drawn_id in binds:
		return neighbour_id in binds[drawn_id]
	return false
