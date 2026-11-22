shader_type canvas_item;
// Brasier pixel art procédural :
// - la zone est découpée en gros pixels (grid) : tout le calcul se fait par case ;
// - deux bruits défilent vers le haut et ondulent : ils forment des langues de flamme qui montent ;
// - la chaleur baisse avec la hauteur (les flammes s'éteignent vers la tête), plus haute sur les côtés
//   (le feu enveloppe le héros) et nulle aux bords ;
// - la chaleur est découpée en paliers de la palette (rouge sombre → orange → jaune → blanc).

uniform sampler2D palette : filter_nearest;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 grid = vec2(40.0, 40.0);  // nombre de gros pixels en largeur et hauteur
uniform float front_cut = 1.0;  // calque de devant : seulement le bas (ex. 0.12)
uniform float seed = 0.0;  // décalage pour que deux feux ne soient pas identiques
uniform float steps = 6.0;

void fragment() {
	vec2 cell = (floor(UV * grid) + 0.5) / grid;
	float y = 1.0 - cell.y;  // 0 en bas, 1 en haut
	if (y > front_cut) {
		discard;
	}
	float x = cell.x;
	float sway = sin(y * 7.0 - TIME * 3.0 + seed) * 0.03 * y;  // les flammes ondulent en montant
	float n1 = texture(noise_tex, vec2((x + sway) * 2.2 + seed, y * 0.9 - TIME * 0.85)).r;
	float n2 = texture(noise_tex, vec2((x + sway) * 4.5 + seed * 2.0, y * 1.8 - TIME * 1.6)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	// Forme de flamme : la zone qui brûle se resserre en montant (elle épouse le héros).
	float side = abs(x - 0.5) * 2.0 / mix(1.0, 0.55, y);  // 0 au centre, 1 au bord
	float envelope = (1.0 - smoothstep(0.7, 1.0, side)) * mix(0.85, 1.05, smoothstep(0.3, 0.7, side));
	float heat = envelope * (1.05 - y * 1.5) + (n - 0.5) * 1.0;
	if (heat < 0.18) {
		discard;
	}
	float level = ceil(clamp(heat, 0.0, 1.0) * steps) / steps;
	COLOR = texture(palette, vec2(min(level, 0.999), 0.5));
}
