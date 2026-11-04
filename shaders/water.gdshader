shader_type spatial;
render_mode blend_mix, cull_back;

// Pool surface: animated waves, refraction of the pool floor, fresnel and sun sparkle.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 shallow : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.28, 0.65, 1.0);
uniform float wave_h = 0.05;
varying vec3 wp;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 1.2 + TIME * 1.6) * cos(w.z * 1.1 + TIME * 1.3) * wave_h;
	wp = w;
}

void fragment() {
	vec3 nw = normalize(vec3(
		sin(wp.x * 2.3 + TIME * 1.5) * 0.12 + sin(wp.z * 4.1 - TIME * 1.9) * 0.08,
		1.0,
		cos(wp.z * 2.1 + TIME * 1.3) * 0.12 + cos(wp.x * 3.7 + TIME * 1.7) * 0.08));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nw, 0.0)).xyz, 0.7));
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 scr = textureLod(screen_tex, SCREEN_UV + NORMAL.xy * 0.035, 0.0).rgb;
	vec3 body = mix(scr * shallow.rgb * 1.1, deep.rgb, 0.4);
	float spark = pow(max(0.0, sin(wp.x * 9.0 + TIME * 2.2) * sin(wp.z * 9.0 - TIME * 1.8)), 8.0);
	ALBEDO = vec3(0.0);
	EMISSION = mix(body, vec3(0.8, 0.95, 1.0), f * 0.6) + vec3(1.0) * spark * 0.15;
	ALPHA = 1.0;
	ROUGHNESS = 0.03;
	SPECULAR = 1.0;
}
