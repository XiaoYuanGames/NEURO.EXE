shader_type canvas_item;

uniform float speed : hint_range(0.05, 2.0) = 0.35;
uniform float glow_intensity : hint_range(0.5, 3.0) = 1.4;
uniform float blur_size : hint_range(0.1, 1.0) = 0.55;

const vec3 BG_DARK   = vec3(0.015, 0.010, 0.025);
const vec3 BG_TINT   = vec3(0.040, 0.020, 0.060);

const vec3 ORB_PURPLE = vec3(0.55, 0.10, 0.90);
const vec3 ORB_RED    = vec3(0.95, 0.10, 0.25);
const vec3 ORB_BLUE   = vec3(0.15, 0.30, 1.00);
const vec3 ORB_MAGENTA= vec3(0.80, 0.15, 0.65);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float orb(vec2 uv, vec2 center, float radius, float softness) {
	float d = distance(uv, center);
	float falloff = 1.0 - smoothstep(0.0, radius * softness, d);
	return pow(falloff, 2.2);
}

void fragment() {
	vec2 uv = UV;
	uv.x *= 1.777;

	float t = TIME * speed;

	vec2 p1 = vec2(0.50 + 0.45 * sin(t * 0.7),         0.40 + 0.30 * cos(t * 0.9));
	vec2 p2 = vec2(0.70 + 0.30 * cos(t * 0.5 + 1.3),   0.65 + 0.35 * sin(t * 0.6 + 2.1));
	vec2 p3 = vec2(0.30 + 0.40 * sin(t * 0.4 + 3.0),   0.55 + 0.40 * cos(t * 0.8 + 0.5));
	vec2 p4 = vec2(0.85 + 0.25 * sin(t * 0.6 + 4.2),   0.25 + 0.35 * cos(t * 0.5 + 1.8));
	vec2 p5 = vec2(0.20 + 0.30 * cos(t * 0.8 + 2.5),   0.80 + 0.20 * sin(t * 0.7 + 3.7));

	p1.x *= 1.777; p2.x *= 1.777; p3.x *= 1.777;
	p4.x *= 1.777; p5.x *= 1.777;

	float breath1 = 0.85 + 0.15 * sin(t * 1.8);
	float breath2 = 0.80 + 0.20 * sin(t * 1.3 + 1.0);
	float breath3 = 0.75 + 0.25 * sin(t * 1.6 + 2.5);
	float breath4 = 0.85 + 0.15 * sin(t * 2.1 + 0.8);
	float breath5 = 0.80 + 0.20 * sin(t * 1.4 + 3.2);

	float g1 = orb(uv, p1, 0.55, blur_size) * breath1;
	float g2 = orb(uv, p2, 0.45, blur_size) * breath2;
	float g3 = orb(uv, p3, 0.60, blur_size) * breath3;
	float g4 = orb(uv, p4, 0.40, blur_size) * breath4;
	float g5 = orb(uv, p5, 0.50, blur_size) * breath5;

	vec3 col = mix(BG_DARK, BG_TINT, smoothstep(0.0, 1.0, length(UV - 0.5)));

	col += ORB_PURPLE  * g1 * glow_intensity;
	col += ORB_RED     * g2 * glow_intensity;
	col += ORB_BLUE    * g3 * glow_intensity;
	col += ORB_MAGENTA * g4 * glow_intensity * 0.8;
	col += ORB_BLUE    * g5 * glow_intensity * 0.7;

	float total_glow = g1 + g2 + g3 + g4 + g5;
	vec3 bloom = (ORB_PURPLE + ORB_RED + ORB_BLUE) / 3.0;
	col += bloom * pow(total_glow, 1.5) * 0.15;

	float vignette = 1.0 - smoothstep(0.55, 1.10, length(UV - 0.5));
	col *= mix(0.55, 1.0, vignette);

	float grain = (hash(UV * 1000.0 + TIME * 0.1) - 0.5) * 0.015;
	col += grain;

	col = col / (col + vec3(0.85));
	col = pow(col, vec3(0.92));

	COLOR = vec4(col, 1.0);
}
