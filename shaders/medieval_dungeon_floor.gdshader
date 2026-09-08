shader_type canvas_item;

// --- AUTHENTIC MEDIEVAL DUNGEON STONE FLAGSTONE SHADER ---
// Features:
// - Heavy cut interlocking masonry flagstones (staggered rectangular stone slabs)
// - 3D chiseled stone bevels: crisp edge highlights and deep recessed drop shadows
// - Cold gothic stone palette (slate gray, dark graphite, basalt) — ZERO muddy dirt!
// - Sharp mortar channels and occasional cracked pavers
// - Retro pixel-quantized stone texture
// - Warm dynamic torchlight with cold ambient contrast

uniform vec3 stone_col_base : source_color = vec3(0.15, 0.17, 0.21); // Cold Slate Stone
uniform vec3 stone_col_alt  : source_color = vec3(0.19, 0.21, 0.26); // Blue-Gray Granite
uniform vec3 stone_col_dark : source_color = vec3(0.11, 0.12, 0.15); // Deep Basalt Paver
uniform vec3 mortar_col     : source_color = vec3(0.02, 0.02, 0.03); // Deep Mortar Groove
uniform vec3 stone_bevel_hi : source_color = vec3(0.38, 0.42, 0.48); // Chiseled Bevel Highlight
uniform vec3 stone_bevel_sh : source_color = vec3(0.04, 0.04, 0.06); // Recessed Edge Shadow

uniform float tile_width : hint_range(32.0, 160.0) = 64.0;
uniform float tile_height: hint_range(16.0, 80.0)  = 32.0;
uniform float mortar_width : hint_range(1.0, 6.0)  = 2.5;

// Dynamic Player Torchlight
uniform vec2 player_pos = vec2(0.0, 0.0);
uniform vec3 torch_color : source_color = vec3(1.0, 0.75, 0.42);
uniform float torch_radius = 480.0;
uniform float torch_intensity = 1.35;
uniform float ambient_light = 0.32;

// Wall Torches
const int MAX_TORCHES = 8;
uniform vec2 wall_torch_positions[8];
uniform float wall_torch_intensities[8];
uniform int wall_torch_count = 0;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453123);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Pixel-quantized world position for authentic retro dungeon crawler texture
	vec2 p_world = floor(world_pos / 1.5) * 1.5;

	// Isometric 2:1 coordinate transformation
	// Slabs aligned to isometric grid axes
	float u = (p_world.x * 0.5 + p_world.y);
	float v = (p_world.x * 0.5 - p_world.y);

	// Staggered running-bond flagstone pattern
	float row = floor(v / tile_height);
	// Shift every alternating row by half tile width (classic masonry running bond)
	float row_shift = mod(row, 2.0) * (tile_width * 0.5);
	float col = floor((u + row_shift) / tile_width);

	vec2 slab_id = vec2(col, row);
	float slab_u = fract((u + row_shift) / tile_width) * tile_width;
	float slab_v = fract(v / tile_height) * tile_height;

	// Distances to slab edges
	float dist_left   = slab_u;
	float dist_right  = tile_width - slab_u;
	float dist_top    = slab_v;
	float dist_bottom = tile_height - slab_v;

	// Mortar trench mask
	float min_dist_x = min(dist_left, dist_right);
	float min_dist_y = min(dist_top, dist_bottom);

	bool is_mortar = (min_dist_x < mortar_width) || (min_dist_y < mortar_width);

	// Slab variation hash
	float r1 = hash(slab_id);
	float r2 = hash2(slab_id);

	// Base stone slab tone
	vec3 slab_color = stone_col_base;
	if (r1 < 0.35) {
		slab_color = stone_col_alt;
	} else if (r1 > 0.70) {
		slab_color = stone_col_dark;
	}

	// 3D CHISELED STONE BEVELS (Gives flagstones depth and elevated slab feel)
	// Top and Left edges catch light (chiseled bevel highlight)
	// Bottom and Right edges are in shadow (recessed into mortar)
	bool is_bevel_top_left = (dist_top < (mortar_width + 2.0) && dist_top >= mortar_width) ||
	                         (dist_left < (mortar_width + 2.0) && dist_left >= mortar_width);
	bool is_bevel_bottom_right = (dist_bottom < (mortar_width + 2.5) && dist_bottom >= mortar_width) ||
	                             (dist_right < (mortar_width + 2.5) && dist_right >= mortar_width);

	if (is_bevel_top_left) {
		slab_color = mix(slab_color, stone_bevel_hi, 0.65);
	} else if (is_bevel_bottom_right) {
		slab_color = mix(slab_color, stone_bevel_sh, 0.75);
	}

	// Subtle stone flagstone surface texture (slate grain, not muddy dirt)
	float grain = (hash(p_world * 0.25) - 0.5) * 0.035;
	slab_color += vec3(grain);

	// Rare sharp stone fracture cracks across ancient slabs
	if (r2 > 0.82) {
		float crack_line = abs(slab_u - (slab_v * 1.8 + (r1 - 0.5) * 12.0));
		if (crack_line < 1.4 && !is_mortar) {
			slab_color *= 0.45; // Dark chiseled fissure
		}
	}

	// Rare inlaid iron corner rivet on some dungeon slabs
	if (r2 < 0.12 && dist_left > 5.0 && dist_left < 9.0 && dist_top > 5.0 && dist_top < 9.0) {
		slab_color = vec3(0.08, 0.08, 0.10); // Dark iron rivet
	}

	// Final floor color: Mortar vs Stone Slab
	vec3 final_floor = is_mortar ? mortar_col : slab_color;

	// DYNAMIC TORCHLIGHT & COLD DUNGEON AMBIENT
	float dist_to_player = length(p_world - player_pos);
	float flicker = 1.0 + (sin(TIME * 7.2) + cos(TIME * 13.1)) * 0.02;
	float torch_rad = torch_radius * flicker;
	float player_factor = clamp(1.0 - (dist_to_player / torch_rad), 0.0, 1.0);
	player_factor = pow(player_factor, 1.7) * torch_intensity;

	float total_torch_factor = player_factor;
	for (int i = 0; i < wall_torch_count; i++) {
		if (i >= 8) break;
		float d_torch = length(p_world - wall_torch_positions[i]);
		float w_rad = 340.0 * wall_torch_intensities[i] * (1.0 + (sin(TIME * 8.5 + float(i) * 2.1) + cos(TIME * 11.3 + float(i))) * 0.03);
		float tf = clamp(1.0 - (d_torch / w_rad), 0.0, 1.0);
		total_torch_factor += pow(tf, 1.6) * 1.25;
	}

	// Cold dungeon darkness ambient (deep blue-gray, NOT brown)
	vec3 ambient_rgb = final_floor * ambient_light * vec3(0.65, 0.75, 0.95);
	// Warm torchlight illumination
	vec3 torch_rgb = final_floor * torch_color * total_torch_factor;

	COLOR = vec4(ambient_rgb + torch_rgb, 1.0);
}
