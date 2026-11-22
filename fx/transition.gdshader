shader_type canvas_item;
// Transition en losanges pixelisés qui balaient l'écran en diagonale.
// progress = 0 : écran visible ; progress = 1 : écran entièrement couvert.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float cell_size = 20.0;  // taille d'un losange, en pixels
uniform vec2 screen_size = vec2(640.0, 360.0);
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 local = fract(UV * screen_size / cell_size) - 0.5;
	float diamond = abs(local.x) + abs(local.y);  // 0 au centre du losange, 1 aux coins
	float sweep = (UV.x + UV.y) * 0.5;  // 0 en haut à gauche, 1 en bas à droite
	float covered = step(diamond, progress * 2.0 - sweep);
	COLOR = vec4(cover_color.rgb, covered * cover_color.a);
}
