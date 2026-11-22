shader_type canvas_item;
render_mode blend_add;
// Reflet qui balaie une carte en diagonale, de temps en temps.
// rainbow = 1 : reflet holographique arc-en-ciel (cartes épiques et légendaires).

uniform float rainbow = 0.0;
uniform float phase = 0.0;  // décalage pour que les cartes ne brillent pas toutes ensemble
uniform float period = 3.5;  // secondes entre deux passages
uniform float width = 0.14;
uniform float strength = 0.35;

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	float t = fract(TIME / period + phase);
	float sweep = t * 4.0 - 1.0;  // le reflet traverse la carte pendant le premier quart
	float diagonal = UV.x * 0.7 + UV.y * 0.5;
	float band = 1.0 - smoothstep(0.0, width, abs(diagonal - sweep));
	vec3 color = mix(vec3(1.0), hue(diagonal * 1.5 + TIME * 0.2), rainbow);
	COLOR = vec4(color * band * strength, 1.0);
}
