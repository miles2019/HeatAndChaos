shader_type canvas_item;
// Full-screen feel pass: radial distortion waves, chromatic aberration, heat window-rim,
// instability glitch lines, flash + afterglow, boss-steam fog.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec4 wave0 = vec4(0.5, 0.5, 2.0, 0.0);   // xy = uv, z = progress (>1 inactive), w = strength
uniform vec4 wave1 = vec4(0.5, 0.5, 2.0, 0.0);
uniform vec4 wave2 = vec4(0.5, 0.5, 2.0, 0.0);
uniform float aberration = 0.0;
uniform float heat = 0.0;
uniform float pulse_speed = 2.0;
uniform float instability = 0.0;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 afterglow = vec4(0.0);
uniform float fog = 0.0;
uniform float scan = 0.12;

vec2 wave_offset(vec4 w, vec2 uv) {
	if (w.z > 1.0 || w.w <= 0.0) { return vec2(0.0); }
	vec2 d = uv - w.xy;
	d.x *= 1.777;
	float dist = length(d);
	float ring = w.z * 0.7;
	float band = exp(-pow((dist - ring) * 16.0, 2.0));
	return normalize(d + 0.0001) * band * w.w * (1.0 - w.z) * 0.045 * vec2(1.0 / 1.777, 1.0);
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = wave_offset(wave0, uv) + wave_offset(wave1, uv) + wave_offset(wave2, uv);
	// instability: horizontal tear lines that get worse with the value
	float row = floor(uv.y * 90.0);
	float tear = step(1.0 - instability * 0.06, hash(row + floor(TIME * 9.0)));
	off.x += tear * 0.012 * instability * (hash(row * 3.1 + TIME) - 0.5) * 2.0;
	vec2 cuv = uv + off;
	float ab = aberration + length(off) * 1.4 + instability * 0.0003 + heat * heat * 0.0003;
	vec2 dir = normalize((uv - vec2(0.5)) + 0.0001);
	vec3 col;
	col.r = texture(screen_tex, cuv + dir * ab).r;
	col.g = texture(screen_tex, cuv).g;
	col.b = texture(screen_tex, cuv - dir * ab).b;
	// subtle scanlines
	float sl = 0.5 + 0.5 * sin(uv.y * 540.0 * 3.14159);
	col *= 1.0 - scan * 0.5 * sl;
	// heat: window rim pulses red, in sync with the heartbeat / pulse speed
	vec2 q = (uv - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.5, 1.0, length(q) * 1.5);
	float beat = 0.55 + 0.45 * sin(TIME * pulse_speed * 3.14159);
	col += vec3(1.0, 0.18, 0.05) * v * v * heat * heat * (0.5 + 0.9 * beat);
	// violet instability tint at the edges
	col += vec3(0.5, 0.15, 1.0) * v * instability * instability * 0.25 * (0.6 + 0.4 * sin(TIME * 17.0));
	// steam fog (boss phase 2): darkens and greys the arena
	col = mix(col, vec3(0.32, 0.33, 0.36) * (0.6 + 0.4 * v), fog * 0.5);
	col *= 1.0 - fog * v * 0.5;
	// afterglow + flash
	col += afterglow.rgb * afterglow.a;
	col = mix(col, flash.rgb, flash.a);
	COLOR = vec4(col, 1.0);
}
