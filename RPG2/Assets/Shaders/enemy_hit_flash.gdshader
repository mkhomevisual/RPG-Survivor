shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // DŮLEŽITÉ: respektovat COLOR (modulate, alpha, atd.)
    vec4 tex = texture(TEXTURE, UV) * COLOR;

    vec3 white = vec3(1.0);
    tex.rgb = mix(tex.rgb, white, flash_amount);

    COLOR = tex;
}
