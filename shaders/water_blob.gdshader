shader_type spatial;
render_mode blend_mix, cull_back;

// Liquid body for the water form: wobbling surface, refraction of what is behind it,
// bright fresnel rim, sharp wet highlights and moving caustics.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float wobble = 0.06;

varying vec3 lp;

void vertex() {
	float w = sin(VERTEX.x * 5.0 + TIME * 2.7) * sin(VERTEX.y * 4.0 + TIME * 2.1)
		+ sin(VERTEX.z * 5.5 - TIME * 2.4) * 0.6;
	VERTEX += NORMAL * w * wobble;
	lp = VERTEX;
}

void fragment() {
	vec3 pert = vec3(
		cos(lp.x * 9.0 + TIME * 3.0),
		cos(lp.y * 8.0 - TIME * 2.0),
		cos(lp.z * 9.0 + TIME * 2.5)) * 0.07;
	NORMAL = normalize(NORMAL + pert);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec2 off = NORMAL.xy * 0.05;
	vec3 scr = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	float caustic = pow(max(0.0, sin(lp.x * 14.0 + TIME * 2.0) * sin(lp.z * 14.0 - TIME * 1.6)), 4.0);
	vec3 body = scr * tint.rgb * 1.25 + vec3(0.0, 0.05, 0.12);
	vec3 col = mix(body, vec3(0.8, 0.96, 1.0), fres * 0.65);
	ALBEDO = vec3(0.0);
	EMISSION = col + vec3(0.6, 0.9, 1.0) * caustic * 0.22;
	ALPHA = clamp(0.9 + fres * 0.1, 0.0, 1.0);
	ROUGHNESS = 0.03;
	SPECULAR = 1.0;
}
