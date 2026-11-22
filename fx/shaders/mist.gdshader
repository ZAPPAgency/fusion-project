shader_type canvas_item;
// Brume, ombres de nuages et rayons de lune, ancrés dans le monde (ils ne glissent pas
// avec la caméra). Un seul passage sur les pixels visibles, sans texture : bruit calculé.
// Le bruit est pris sur la grille des pixels du jeu (640×360) pour rester en pixel art.

uniform vec4 mist_color : source_color = vec4(0.75, 0.8, 1.0, 1.0);
uniform float mist_density = 0.0;  // 0 = pas de brume
uniform vec2 mist_scale = vec2(180.0, 120.0);  // taille des bancs de brume (pixels du jeu)
uniform vec2 wind = vec2(6.0, 1.5);  // vitesse de dérive (pixels du jeu par seconde)
uniform float cloud_shadow = 0.0;  // ombres de nuages qui passent (0 = aucune)
uniform float cloud_scale = 420.0;
uniform float shafts = 0.0;  // rayons de lune en biais (0 = aucun)
uniform vec4 shaft_color : source_color = vec4(0.8, 0.85, 1.0, 1.0);
uniform bool detailed = true;  // deuxième couche de bruit (qualité haute)
uniform float fade_top = 0.0;  // bandes (combat) : fondu en haut et en bas, en pixels du rectangle
uniform float fade_bottom = 0.0;
uniform vec2 rect_size = vec2(0.0);

varying vec2 world;
varying vec2 local;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	local = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = floor(world);
	float t = TIME;
	float mist = 0.0;
	if (mist_density > 0.0) {
		mist = noise((p - wind * t) / mist_scale);
		if (detailed) {
			mist = mist * 0.65 + noise((p - wind * t * 1.7) / (mist_scale * 0.4) + 7.3) * 0.35;
		}
		mist = smoothstep(0.4, 0.85, mist) * mist_density;
	}
	float shadow = 0.0;
	if (cloud_shadow > 0.0) {
		shadow = smoothstep(0.5, 0.78, noise((p - wind * t * 1.5) / cloud_scale + 31.0)) * cloud_shadow;
	}
	float shaft = 0.0;
	if (shafts > 0.0) {
		// Bandes en biais ; seule une partie d'entre elles est allumée, et elles s'allument
		// et s'éteignent lentement : quelques rayons épars, jamais des rayures régulières.
		float band = (p.x + p.y * 0.55) / 120.0 + t * 0.02;
		float index = floor(band);
		float lit = smoothstep(0.62, 0.85, noise(vec2(index * 1.37, t * 0.08)));
		float width_noise = 0.5 + 0.5 * hash(vec2(index, 3.0));
		shaft = pow(max(0.0, sin(fract(band) * 3.14159)), 3.0 + width_noise * 6.0) * lit;
		shaft *= 0.6 + 0.4 * noise(vec2(p.y / 60.0, index));  // plus ou moins dense sur sa longueur
		shaft *= shafts;
	}
	if (rect_size.y > 0.0) {
		float fade = 1.0;
		if (fade_top > 0.0) fade *= smoothstep(0.0, fade_top, local.y);
		if (fade_bottom > 0.0) fade *= smoothstep(rect_size.y, rect_size.y - fade_bottom, local.y);
		mist *= fade;
		shaft *= fade;
	}
	float alpha = clamp(mist + shaft + shadow, 0.0, 1.0);
	vec3 light = mist_color.rgb * mist + shaft_color.rgb * shaft;
	COLOR = vec4(alpha > 0.001 ? light / alpha : vec3(0.0), alpha);
}
