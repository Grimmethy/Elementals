shader_type spatial;

uniform sampler2D top_texture : source_color, filter_nearest;
uniform sampler2D side_texture : source_color, filter_nearest;
uniform vec3 albedo_color : source_color = vec3(1.0);
uniform float side_scale : hint_range(0.1, 10.0) = 1.0;
uniform float height_darkening : hint_range(0.0, 1.0) = 0.3;
uniform float rim_highlight : hint_range(0.0, 1.0) = 0.2;
uniform float rim_size : hint_range(0.0, 0.2) = 0.05;
uniform float side_animation_speed : hint_range(-10.0, 10.0) = 0.0;
uniform sampler2D overlay_texture : source_color, hint_default_transparent, filter_nearest;
uniform float overlay_animation_speed : hint_range(-10.0, 10.0) = 0.0;

varying float v_y;
varying vec3 v_normal;
varying vec3 v_vertex;
varying float v_scale_y;

void vertex() {
	v_y = VERTEX.y;
	v_normal = NORMAL;
	v_vertex = VERTEX;
	v_scale_y = length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	// Top color from standard UVs
	vec4 top_col = texture(top_texture, UV);
	
	// Side mapping: Cylindrical mapping but with vertical scale from world space
	// to prevent stretching on taller cliffs.
	float angle = atan(v_vertex.x, v_vertex.z);
	// We divide angle by PI * 2 to get 0..1 range around the hex.
	// Since it's a hex, we might want to scale this to tile better.
	vec2 side_uv = vec2(angle * 3.0 / 3.14159265, (v_vertex.y * v_scale_y) * side_scale * 0.5 + TIME * side_animation_speed);
	vec4 side_col = texture(side_texture, side_uv);
	
	vec2 overlay_uv = vec2(angle * 3.0 / 3.14159265, (v_vertex.y * v_scale_y) * side_scale * 0.5 + TIME * overlay_animation_speed);
	vec4 overlay_col = texture(overlay_texture, overlay_uv);
	side_col.rgb = mix(side_col.rgb, overlay_col.rgb, overlay_col.a);
	
	// Blend based on normal. Cylinder top normal.y is 1.0, sides are 0.0.
	float is_top = step(0.5, v_normal.y);
	vec3 final_albedo = mix(side_col.rgb, top_col.rgb, is_top) * albedo_color;
	
	// Height-based shading (darken bottom)
	// v_y is between -1.0 (bottom) and 1.0 (top) in local space.
	// We use the scaled height to make the transition more natural on tall cliffs?
	// Actually, just darkening the bottom of the visible cylinder is fine.
	float height_factor = clamp((v_y + 1.0) * 0.5, 0.0, 1.0);
	final_albedo *= mix(1.0 - height_darkening, 1.0, pow(height_factor, 0.5));
	
	// Rim highlight / Bevel
	// 1. Top of the side faces
	if (is_top < 0.5 && v_y > (1.0 - rim_size / v_scale_y)) {
		final_albedo += vec3(rim_highlight);
	}
	// 2. Edge of the top face
	if (is_top > 0.5 && length(v_vertex.xz) > (1.0 - rim_size)) {
		final_albedo += vec3(rim_highlight);
	}
	
	ALBEDO = final_albedo;
	// Metallic/Roughness for a more natural look
	ROUGHNESS = mix(0.8, 0.5, is_top);
}
