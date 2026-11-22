shader_type canvas_item;
// Effets appliqués au sprite d'un personnage :
// - évolution des héros (voir HeroStage) : recoloration des couleurs vives, teinte du métal,
//   contour lumineux qui pulse ;
// - flash : le sprite vire à une couleur vive (impact, parade). Valeurs > 1 → brille avec le glow ;
// - dissolution : le sprite part en cendres, pixel par pixel, avec un bord incandescent (mort).

uniform float recolor_hue_min = 0.0;
uniform float recolor_hue_max = 0.0;  // min = max : pas de recoloration
uniform float recolor_hue_target = 0.0;
uniform float recolor_saturation = 1.0;
uniform float recolor_value = 1.0;
uniform vec4 metal_tint : source_color = vec4(1.0);
uniform float metal_amount = 0.0;
uniform vec4 outline_color = vec4(0.0);  // alpha = force du contour (0 = aucun)

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float flash_intensity = 1.7;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float edge_intensity = 4.0;
uniform float edge_width = 0.1;
uniform sampler2D noise : repeat_enable, filter_nearest;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 color = COLOR;  // texture × modulate

	// Évolution : nouvelles couleurs de tenue et d'armure.
	if (color.a > 0.0) {
		vec3 hsv = rgb_to_hsv(color.rgb);
		bool vivid = hsv.y > 0.25;
		if (vivid && recolor_hue_max > recolor_hue_min && hsv.x >= recolor_hue_min && hsv.x <= recolor_hue_max) {
			// Garde les nuances d'origine autour de la nouvelle teinte.
			float centered = hsv.x - (recolor_hue_min + recolor_hue_max) * 0.5;
			hsv.x = fract(recolor_hue_target + centered * 0.5);
			hsv.y = clamp(hsv.y * recolor_saturation, 0.0, 1.0);
			hsv.z = min(hsv.z * recolor_value, 1.0);  // pas au-delà de 1 : le corps ne doit pas briller
			color.rgb = hsv_to_rgb(hsv);
		} else if (!vivid && hsv.z > 0.15) {
			color.rgb = mix(color.rgb, min(metal_tint.rgb * hsv.z * 1.25, vec3(1.0)), metal_amount);
		}
	}

	// Contour lumineux : pixel transparent touchant un pixel du personnage.
	if (outline_color.a > 0.0 && color.a < 0.5) {
		vec2 step_uv = TEXTURE_PIXEL_SIZE;
		float near = texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a + texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a + texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a;
		if (near > 0.5) {
			float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
			color = vec4(outline_color.rgb, outline_color.a * pulse);
		}
	}

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
