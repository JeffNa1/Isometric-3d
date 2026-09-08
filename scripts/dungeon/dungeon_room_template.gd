class_name DungeonRoomTemplate
extends RefCounted

## Defines 10 Distinct Room Shapes & Doorway Sockets for Procedural Dungeon Generation
## Uses a discrete 2D grid cell system mapped to 2:1 Isometric space.

enum ShapeType {
	SQUARE_ATRIUM,      # 1. 2x2 Square
	GRAND_CATHEDRAL,    # 2. 3x3 Giant Hall
	LONG_GALLERY,       # 3. 3x1 Horizontal Rectangle
	PILLAR_CORRIDOR,    # 4. 1x3 Vertical Rectangle
	HOLY_CROSS,         # 5. Plus (+) Shape
	L_JUNCTION,         # 6. L-Corner / Elbow
	T_SPLIT,            # 7. T-Junction Crossroads
	DONUT_CLOISTER,     # 8. Hollow Center Ring
	DIAMOND_ARENA,      # 9. Wide Octagonal Arena
	VAULT_DEADEND       # 10. 1x1 Compact Dead-End
}

const DIR_NE = Vector2i(0, -1)
const DIR_SE = Vector2i(1, 0)
const DIR_SW = Vector2i(0, 1)
const DIR_NW = Vector2i(-1, 0)

const ALL_DIRS = [DIR_NE, DIR_SE, DIR_SW, DIR_NW]

static func get_opposite_dir(dir: Vector2i) -> Vector2i:
	return -dir

static func get_dir_name(dir: Vector2i) -> String:
	match dir:
		DIR_NE: return "North-East"
		DIR_SE: return "South-East"
		DIR_SW: return "South-West"
		DIR_NW: return "North-West"
		_: return "Unknown"

# Returns definition for a specific shape
static func get_template(shape: ShapeType) -> Dictionary:
	match shape:
		ShapeType.SQUARE_ATRIUM:
			return {
				"type": ShapeType.SQUARE_ATRIUM,
				"name": "Square Atrium",
				"color": Color(0.20, 0.25, 0.35),
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0),
					Vector2i(0, 1), Vector2i(1, 1)
				],
				"doors": [
					{"cell": Vector2i(0, 0), "dir": DIR_NW},
					{"cell": Vector2i(1, 0), "dir": DIR_NE},
					{"cell": Vector2i(1, 1), "dir": DIR_SE},
					{"cell": Vector2i(0, 1), "dir": DIR_SW}
				]
			}
			
		ShapeType.GRAND_CATHEDRAL:
			var cells: Array[Vector2i] = []
			for x in range(3):
				for y in range(3):
					cells.append(Vector2i(x, y))
			return {
				"type": ShapeType.GRAND_CATHEDRAL,
				"name": "Grand Cathedral",
				"color": Color(0.28, 0.22, 0.32),
				"cells": cells,
				"doors": [
					{"cell": Vector2i(0, 1), "dir": DIR_NW},
					{"cell": Vector2i(1, 0), "dir": DIR_NE},
					{"cell": Vector2i(2, 1), "dir": DIR_SE},
					{"cell": Vector2i(1, 2), "dir": DIR_SW}
				]
			}
			
		ShapeType.LONG_GALLERY:
			return {
				"type": ShapeType.LONG_GALLERY,
				"name": "Long Gallery",
				"color": Color(0.22, 0.30, 0.28),
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)
				],
				"doors": [
					{"cell": Vector2i(0, 0), "dir": DIR_NW},
					{"cell": Vector2i(2, 0), "dir": DIR_SE},
					{"cell": Vector2i(1, 0), "dir": DIR_NE}
				]
			}
			
		ShapeType.PILLAR_CORRIDOR:
			return {
				"type": ShapeType.PILLAR_CORRIDOR,
				"name": "Pillar Corridor",
				"color": Color(0.25, 0.28, 0.22),
				"cells": [
					Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)
				],
				"doors": [
					{"cell": Vector2i(0, 0), "dir": DIR_NE},
					{"cell": Vector2i(0, 2), "dir": DIR_SW},
					{"cell": Vector2i(0, 1), "dir": DIR_SE}
				]
			}
			
		ShapeType.HOLY_CROSS:
			return {
				"type": ShapeType.HOLY_CROSS,
				"name": "The Holy Cross (+)",
				"color": Color(0.32, 0.28, 0.18),
				"cells": [
					Vector2i(1, 0),
					Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
					Vector2i(1, 2)
				],
				"doors": [
					{"cell": Vector2i(1, 0), "dir": DIR_NE},
					{"cell": Vector2i(0, 1), "dir": DIR_NW},
					{"cell": Vector2i(2, 1), "dir": DIR_SE},
					{"cell": Vector2i(1, 2), "dir": DIR_SW}
				]
			}
			
		ShapeType.L_JUNCTION:
			return {
				"type": ShapeType.L_JUNCTION,
				"name": "L-Junction Elbow",
				"color": Color(0.24, 0.20, 0.30),
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0),
					Vector2i(0, 1)
				],
				"doors": [
					{"cell": Vector2i(1, 0), "dir": DIR_SE},
					{"cell": Vector2i(0, 1), "dir": DIR_SW}
				]
			}
			
		ShapeType.T_SPLIT:
			return {
				"type": ShapeType.T_SPLIT,
				"name": "T-Split Crossroads",
				"color": Color(0.30, 0.22, 0.22),
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
					Vector2i(1, 1)
				],
				"doors": [
					{"cell": Vector2i(0, 0), "dir": DIR_NW},
					{"cell": Vector2i(2, 0), "dir": DIR_SE},
					{"cell": Vector2i(1, 1), "dir": DIR_SW}
				]
			}
			
		ShapeType.DONUT_CLOISTER:
			var cells_donut: Array[Vector2i] = [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
				Vector2i(0, 1),                  Vector2i(2, 1),
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
			]
			return {
				"type": ShapeType.DONUT_CLOISTER,
				"name": "Donut Cloister",
				"color": Color(0.18, 0.28, 0.32),
				"cells": cells_donut,
				"doors": [
					{"cell": Vector2i(0, 1), "dir": DIR_NW},
					{"cell": Vector2i(1, 0), "dir": DIR_NE},
					{"cell": Vector2i(2, 1), "dir": DIR_SE},
					{"cell": Vector2i(1, 2), "dir": DIR_SW}
				]
			}
			
		ShapeType.DIAMOND_ARENA:
			return {
				"type": ShapeType.DIAMOND_ARENA,
				"name": "Diamond Arena",
				"color": Color(0.32, 0.18, 0.26),
				"cells": [
					                Vector2i(1, 0), Vector2i(2, 0),
					Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
					                Vector2i(1, 2), Vector2i(2, 2)
				],
				"doors": [
					{"cell": Vector2i(1, 0), "dir": DIR_NE},
					{"cell": Vector2i(0, 1), "dir": DIR_NW},
					{"cell": Vector2i(3, 1), "dir": DIR_SE},
					{"cell": Vector2i(2, 2), "dir": DIR_SW}
				]
			}
			
		ShapeType.VAULT_DEADEND:
			return {
				"type": ShapeType.VAULT_DEADEND,
				"name": "Vault Dead-End",
				"color": Color(0.35, 0.30, 0.15),
				"cells": [
					Vector2i(0, 0)
				],
				"doors": [
					{"cell": Vector2i(0, 0), "dir": DIR_SW}
				]
			}
			
	return {}

# Returns all 10 templates as an array
static func get_all_templates() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for st in ShapeType.values():
		list.append(get_template(st as ShapeType))
	return list
