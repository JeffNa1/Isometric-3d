shader_type canvas_item;

// --- AUTHENTIC MEDIEVAL DUNGEON STONE WALL SHADER ---
// Matches medieval_dungeon_floor.gdshader style, color palette, and dynamic torchlight:
// - Heavy cut interlocking masonry stone blocks (running-bond course)
// - 3D chiseled stone bevels: top/left edges catch highlight, bottom/right in shadow
// - Cold gothic stone palette (slate gray, dark granite, deep basalt)
// - Micro-grain stone texture & chiseled fissures
// - Architectural stone coping / parapet cap on top of walls
// - Ground contact shadow anchoring wall into the stone floor
// - Synchronized dynamic player torchlight with flicker and cold ambient contrast

uniform vec3 stone_col_base : source_color = vec3(0.15, 0.17, 0.21); // Cold Slate Stone
uniform vec3 stone_col_alt  : source_color = vec3(0.19, 0.21, 0.26); // Blue-Gray Granite
uniform vec3 stone_col_dark : source_color = vec3(0.11, 0.12, 0.15); // Deep Basalt Block
uniform vec3 mortar_col     : source_color = vec3(0.02, 0.02, 0.03); // Deep Mortar Groove
uniform vec3 stone_bevel_hi : source_color = vec3(0.38, 0.42, 0.48); // Chiseled Bevel Highlight
uniform vec3 stone_bevel_sh : source_color = vec3(0.04, 0.04, 0.06); // Recessed Edge Shadow

// Block dimensions on wall face: Ashlar fortress masonry (distinct from wide floor slabs)
uniform float block_width  : hint_range(32.0, 128.0) = 56.0;
uniform float course_height: hint_range(20.0, 60.0)  = 30.0;
uniform float mortar_width : hint_range(1.0, 6.0)    = 2.6;
uniform float wall_full_height = 200.0;

// Directional wall exposure: NE walls catch ambient fill, NW walls in shadow
uniform float wall_light_mult : hint_range(0.5, 1.5) = 1.0;

// Dynamic Player Torchlight (synchronized with floor)
uniform vec2 player_pos = vec2(0.0, 0.0);
uniform vec3 torch_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float torch_radius = 560.0;
uniform float torch_intensity = 1.45;
uniform float ambient_light = 0.28;

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
	// Pixel-quantized world coordinates for retro aesthetic
	vec2 p_world = floor(world_pos / 1.5) * 1.5;
	
	// UV coordinates passed from wall geometry:
	// UV.x = continuous horizontal distance along wall (in pixels)
	// UV.y = vertical height above ground (in pixels, 0.0 at base to wall_height at top)
	float S = UV.x;
	float h_up = UV.y;
	
	// 1. TOP PARAPET COPING / CORNICE (Top 18px of tall wall)
	float cap_height = 18.0;
	bool is_cap = (wall_full_height > 50.0) && (h_up >= wall_full_height - cap_height);
	bool is_curb = (wall_full_height <= 50.0);
	
	vec3 surface_color = stone_col_base;
	bool is_mortar = false;
	
	if (is_cap) {
		// Architectural stone parapet ledge
		float cap_v = wall_full_height - h_up; // 0.0 at very top, 18.0 at base of cap
		surface_color = stone_col_alt * 1.15; // Slightly lighter chiseled coping stone
		
		// Top highlight rim
		if (cap_v < 2.5) {
			surface_color = stone_bevel_hi * 1.25;
		} else if (cap_v > 15.5) {
			surface_color = stone_bevel_sh; // Underside shadow
		}
		
		// Subtle block segmentation on the cap every 96px
		float cap_joint = mod(S, 96.0);
		if (cap_joint < 2.2) {
			surface_color = mortar_col;
			is_mortar = true;
		}
	} else if (is_curb) {
		// Low 24px curb / balustrade
		surface_color = stone_col_base * 0.90;
		// Subtle vertical curb block joints every 72px
		float curb_joint = mod(S, 72.0);
		if (curb_joint < 2.2) {
			surface_color = mortar_col;
			is_mortar = true;
		}
		// Top curb rail highlight
		if (h_up >= wall_full_height - 3.0) {
			surface_color = stone_bevel_hi;
		} else if (h_up <= 2.5) {
			surface_color = mortar_col;
			is_mortar = true;
		}
	} else {
		// MAIN WALL STONE MASONRY COURSES
		// Staggered running bond pattern
		float row = floor(h_up / course_height);
		float row_shift = mod(row, 2.0) * (block_width * 0.5);
		float col = floor((S + row_shift) / block_width);
		
		vec2 block_id = vec2(col, row);
		float block_u = fract((S + row_shift) / block_width) * block_width;
		float block_v = fract(h_up / course_height) * course_height;
		
		// Distances to block edges
		float dist_left   = block_u;
		float dist_right  = block_width - block_u;
		float dist_bottom = block_v;
		float dist_top    = course_height - block_v;
		
		float min_dist_x = min(dist_left, dist_right);
		float min_dist_y = min(dist_bottom, dist_top);
		
		is_mortar = (min_dist_x < mortar_width) || (min_dist_y < mortar_width);
		
		// Randomized stone tone variation per block (matching floor)
		float r1 = hash(block_id + vec2(13.4, 57.1));
		float r2 = hash2(block_id + vec2(49.2, 81.3));
		
		if (r1 < 0.35) {
			surface_color = stone_col_alt;
		} else if (r1 > 0.70) {
			surface_color = stone_col_dark;
		} else {
			surface_color = stone_col_base;
		}
		
		// 3D CHISELED STONE BEVELS
		// Light comes from upper-left in isometric projection:
		// Top & Left edges catch light
		// Bottom & Right edges are recessed in shadow
		bool is_bevel_top_left = (dist_top < (mortar_width + 2.0) && dist_top >= mortar_width) ||
		                         (dist_left < (mortar_width + 2.0) && dist_left >= mortar_width);
		bool is_bevel_bottom_right = (dist_bottom < (mortar_width + 2.5) && dist_bottom >= mortar_width) ||
		                             (dist_right < (mortar_width + 2.5) && dist_right >= mortar_width);
		
		if (is_bevel_top_left) {
			surface_color = mix(surface_color, stone_bevel_hi, 0.65);
		} else if (is_bevel_bottom_right) {
			surface_color = mix(surface_color, stone_bevel_sh, 0.75);
		}
		
		// Occasional cracked stone blocks
		if (r2 > 0.82 && !is_mortar) {
			float crack_line = abs(block_u - (block_v * 1.5 + (r1 - 0.5) * 14.0));
			if (crack_line < 1.4) {
				surface_color *= 0.45; // Dark chiseled fissure
			}
		}
		
		// Drop shadow cast by the top parapet cap onto the course beneath it
		if (h_up >= wall_full_height - cap_height - 12.0) {
			float sh_factor = (h_up - (wall_full_height - cap_height - 12.0)) / 12.0;
			surface_color *= mix(1.0, 0.55, sh_factor);
		}
		
		// Ground contact shadow (ambient occlusion where wall meets floor)
		if (h_up < 12.0) {
			float ao = h_up / 12.0;
			surface_color *= mix(0.50, 1.0, ao);
		}
	}
	
	// Vertical stonemason tooth-chisel striations (distinct from floor slate grain)
	float chisel = sin((S + hash(floor(h_up / course_height) * vec2(3.1, 7.7)) * 14.0) * 0.45) * 0.022;
	surface_color += vec3(chisel);
	
	// Fine stone micro-grain
	float grain = (hash(p_world * 0.25) - 0.5) * 0.035;
	surface_color += vec3(grain);
	
	// Apply directional wall exposure multiplier
	surface_color *= wall_light_mult;
	
	// Final stone vs mortar color
	vec3 final_wall = is_mortar ? mortar_col : surface_color;
	
	// DYNAMIC TORCHLIGHT & COLD AMBIENT CONTRAST
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
	
	// Cold dungeon ambient (deep blue-gray)
	vec3 ambient_rgb = final_wall * ambient_light * vec3(0.65, 0.75, 0.95);
	// Warm golden torchlight illumination
	vec3 torch_rgb = final_wall * torch_color * total_torch_factor;
	
	COLOR = vec4((ambient_rgb + torch_rgb) * COLOR.rgb, COLOR.a);
}
