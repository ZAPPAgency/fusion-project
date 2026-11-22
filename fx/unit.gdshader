shader_type canvas_item;
// Effets appliqués au sprite d'un combattant :
// - flash : le sprite vire à une couleur vive (impact, parade). Valeurs > 1 → brille avec le glow.
// - dissolution : le sprite part en cendres, pixel par pixel, avec un bord incandescent (mort).

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float flash_intensity = 1.7;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float edge_intensity = 4.0;
uniform float edge_width = 0.1;
uniform sampler2D noise : repeat_enable, filter_nearest;

void fragment() {
	vec4 color = COLOR;  // texture × modulate
	color.rgb = mix(color.rgb, flash_color.rgb * flash_intensity, flash_amount);

	if (dissolve > 0.0) {
		// Bruit échantillonné par pixel du sprite : la dissolution reste « pixel art ».
		vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
		float value = texture(noise, pixel / 64.0).r;
		if (value < dissolve) {
			color.a = 0.0;
		} else if (value < dissolve + edge_width) {
			color.rgb = edge_color.rgb * edge_intensity;
		}
	}
	COLOR = color;
}
