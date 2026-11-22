shader_type canvas_item;
// Effets plein écran, appliqués sur l'image du combat (pas sur l'interface) :
// - onde de choc : anneau de distorsion qui s'élargit (parade parfaite, contre-attaque) ;
// - aberration chromatique : décalage rouge/bleu bref sur les gros impacts ;
// - vignette : bords assombris pour l'ambiance, teintée en rouge quand un héros est touché.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform vec2 shock_center = vec2(0.5);  // en coordonnées écran (0 à 1)
uniform float shock_radius = 0.0;  // en hauteurs d'écran
uniform float shock_strength = 0.0;
uniform float shock_width = 0.05;

uniform float aberration = 0.0;  // en pixels du jeu (l'écran fait 640 de large)

uniform float vignette = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;  // largeur / hauteur

	if (shock_strength > 0.0) {
		vec2 delta = (uv - shock_center) * vec2(aspect, 1.0);
		float dist = length(delta);
		float ring = 1.0 - smoothstep(0.0, shock_width, abs(dist - shock_radius));
		uv -= normalize(delta + 0.0001) / vec2(aspect, 1.0) * ring * shock_strength;
	}

	vec2 offset = vec2(aberration / 640.0, 0.0);
	vec3 color = vec3(
		texture(screen_texture, uv + offset).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - offset).b
	);

	float edge = smoothstep(0.35, 0.85, length((SCREEN_UV - 0.5) * vec2(aspect, 1.0) * 0.75));
	color = mix(color, vignette_color.rgb, edge * vignette);
	COLOR = vec4(color, 1.0);
}
