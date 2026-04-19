shader_type spatial;

uniform sampler2D top_texture : source_color, filter_nearest;
uniform sampler2D side_texture : source_color, filter_nearest;
uniform vec3 albedo_color : source_color = vec3(1.0);
uniform float top_texture_scale : hint_range(0.01, 10.0) = 0.25;
uniform float side_scale : hint_range(0.1, 10.0) = 1.0;
uniform float height_darkening : hint_range(0.0, 1.0) = 0.3;
uniform float rim_highlight : hint_range(0.0, 1.0) = 0.2;
uniform float rim_size : hint_range(0.0, 0.5) = 0.05;
uniform float side_animation_speed : hint_range(-10.0, 10.0) = 0.0;
uniform sampler2D overlay_texture : source_color, hint_default_transparent, filter_nearest;
uniform float overlay_animation_speed : hint_range(-10.0, 10.0) = 0.0;

// NEW: Top edge blending parameters
uniform float top_edge_darkening : hint_range(0.0, 1.0) = 0.15;
uniform float top_edge_softness : hint_range(0.0, 0.5) = 0.1;
uniform float texture_tiling_noise : hint_range(0.0, 1.0) = 0.05;

varying float v_y;
varying vec3 v_normal;
varying vec3 v_vertex;
varying float v_scale_y;
varying vec3 v_world_pos;

void vertex() {
	v_y = VERTEX.y;
	v_normal = NORMAL;
	v_vertex = VERTEX;
	v_scale_y = length(MODEL_MATRIX[1].xyz);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	// Add subtle tiling noise to break up repetitions
	float noise = hash(v_world_pos.xz * 1.5) * texture_tiling_noise;
	
	// Top color from world-space coordinates for consistency and zero corner stretch
	vec2 top_uv = v_world_pos.xz * top_texture_scale + vec2(noise * 0.05);
	vec4 top_col = texture(top_texture, top_uv);
	
	// Hexagonal distance for accurate edge effects (Normalized to 1.0 at edges)
	// Points are rotated 30 degrees to match Arena.gd mesh rotation
	vec2 p_hex = v_vertex.xz;
	float dist_h = max(abs(p_hex.y), abs(p_hex.y) * 0.5 + abs(p_hex.x) * 0.86602540) * 1.1547005;
	
	// Top edge vignette (darkening)
	float top_vignette = smoothstep(1.0, 1.0 - top_edge_softness, dist_h);
	vec3 top_final_rgb = top_col.rgb * mix(1.0 - top_edge_darkening, 1.0, top_vignette);
	
	// Side mapping: Cylindrical mapping but with vertical scale from world space
	float angle = atan(v_vertex.x, v_vertex.z);
	vec2 side_uv = vec2(angle * 3.0 / 3.14159265, (v_vertex.y * v_scale_y) * side_scale * 0.5 + TIME * side_animation_speed);
	vec4 side_col = texture(side_texture, side_uv);
	
	vec2 overlay_uv = vec2(angle * 3.0 / 3.14159265, (v_vertex.y * v_scale_y) * side_scale * 0.5 + TIME * overlay_animation_speed);
	vec4 overlay_col = texture(overlay_texture, overlay_uv);
	side_col.rgb = mix(side_col.rgb, overlay_col.rgb, overlay_col.a);
	
	// --- BLENDING LOGIC ---
	float is_top = step(0.5, v_normal.y);
	
	// Wrap the top texture slightly over the side edge for a "rounded" feel
	float edge_blend_width = 0.08;
	float transition_blend = is_top;
	
	if (is_top < 0.5) {
		float top_side_fade = smoothstep(1.0 - edge_blend_width / v_scale_y, 1.0, v_y);
		transition_blend = top_side_fade * 0.45;
	}
	
	vec3 final_albedo = mix(side_col.rgb, top_final_rgb, transition_blend) * albedo_color;
	
	// --- SHADING LOGIC ---
	float height_factor = clamp((v_y + 1.0) * 0.5, 0.0, 1.0);
	final_albedo *= mix(1.0 - height_darkening, 1.0, pow(height_factor, 0.5));
	
	// Improved Rim highlight / Bevel / Edge Shadow
	if (is_top < 0.5) {
		float shadow_factor = smoothstep(1.0 - rim_size / v_scale_y, 1.0, v_y);
		final_albedo *= mix(1.0, 0.8, shadow_factor);
	}
	
	if (is_top > 0.5) {
		float edge_dist = smoothstep(1.0 - rim_size, 1.0, dist_h);
		final_albedo = mix(final_albedo, final_albedo + rim_highlight * 0.5, edge_dist);
	}
	
	ALBEDO = final_albedo;
	ROUGHNESS = mix(0.8, 0.5, is_top);
}
