class_name IsoUtils
extends RefCounted

## Shared 8-directional isometric math and direction utilities.

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

const DIR_NAMES = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

static func get_dir8_from_vector(v: Vector2) -> Dir8:
	if v.length_squared() < 0.001:
		return Dir8.S
	var iso_angle = atan2(v.y * 1.35, v.x)
	var octant = int(round(iso_angle / (TAU / 8.0)))
	if octant < 0:
		octant += 8
	return (octant % 8) as Dir8

static func get_vector_from_dir8(dir: int) -> Vector2:
	match dir:
		Dir8.E:  return Vector2(1.0, 0.0)
		Dir8.SE: return Vector2(0.894, 0.447).normalized()
		Dir8.S:  return Vector2(0.0, 1.0)
		Dir8.SW: return Vector2(-0.894, 0.447).normalized()
		Dir8.W:  return Vector2(-1.0, 0.0)
		Dir8.NW: return Vector2(-0.894, -0.447).normalized()
		Dir8.N:  return Vector2(0.0, -1.0)
		Dir8.NE: return Vector2(0.894, -0.447).normalized()
	return Vector2.DOWN
