shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 shallow : source_color = vec4(0.25, 0.80, 0.95, 0.55);
uniform vec4 deep : source_color = vec4(0.02, 0.28, 0.65, 0.88);
uniform float wave_h = 0.05;
varying vec3 wp;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 1.2 + TIME * 1.6) * cos(w.z * 1.1 + TIME * 1.3) * wave_h;
	wp = w;
}

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float rip = sin(wp.x * 3.0 + TIME * 2.0) * sin(wp.z * 3.0 - TIME * 1.7) * 0.5 + 0.5;
	vec4 c = mix(shallow, deep, f);
	ALBEDO = c.rgb + rip * 0.06;
	ALPHA = mix(c.a, 0.95, f);
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
}
