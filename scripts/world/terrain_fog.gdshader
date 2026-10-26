shader_type spatial;
// 地形と木の色。霧の印(探索済みなら 1)がない場所は暗く塗りつぶす(AC-021)

uniform sampler2D fog_mask : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(256.0, 256.0);
uniform bool use_vertex_color = true;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 fog_color : source_color = vec4(0.30, 0.33, 0.37, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 頂点色は sRGB で入っているので、明るさを合わせるために線形に直す
	vec3 color = use_vertex_color ? pow(COLOR.rgb, vec3(2.2)) : base_color.rgb;
	float explored = step(0.001, texture(fog_mask, world_pos.xz / map_size).r);
	ALBEDO = mix(fog_color.rgb, color, explored);
	ROUGHNESS = 0.9;
}
