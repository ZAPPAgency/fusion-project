shader_type canvas_item;
render_mode blend_add, unshaded;
// Rayons de lune : faisceaux qui partent d'un point (la lune) et s'effacent avec la distance.
// Leur intensité ondule lentement. Additif : n'éclaircit que là où il passe.

uniform vec2 source = vec2(0.0);  // position de la lune, en pixels du rectangle
uniform vec4 color : source_color = vec4(0.7, 0.75, 1.0, 1.0);
uniform float strength = 0.12;
uniform float reach = 300.0;  // distance (pixels du jeu) où les rayons ont disparu
uniform float cover = 0.0;  // nuage devant la lune : 1 = rayons éteints

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(float x) {
	return fract(sin(x * 91.17) * 43758.5453);
}

float rays(float angle, float t) {
	float a = angle * 9.0 + t * 0.05;
	float i = floor(a);
	float f = fract(a);
	f = f * f * (3.0 - 2.0 * f);
	float base = mix(hash(i), hash(i + 1.0), f);
	return smoothstep(0.45, 1.0, base);
}

void fragment() {
	vec2 delta = floor(local) - source;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);
	float beams = rays(angle, TIME) * (0.6 + 0.4 * sin(TIME * 0.4 + angle * 5.0));
	float fade = (1.0 - smoothstep(0.0, reach, dist)) * smoothstep(8.0, 30.0, dist);
	COLOR = vec4(color.rgb * beams * fade * strength * (1.0 - cover), 1.0);
}
