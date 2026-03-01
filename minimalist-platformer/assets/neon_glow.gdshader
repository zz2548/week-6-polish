shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.0;
uniform int glow_steps : hint_range(1, 10) = 6;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    float glow_amount = 0.0;
    
    for (int i = 1; i <= glow_steps; i++) {
        float offset = float(i) * TEXTURE_PIXEL_SIZE.x * 2.0;
        float falloff = 1.0 - float(i) / float(glow_steps);
        
        float s = 0.0;
        s += texture(TEXTURE, UV + vec2( offset,  0.0   )).a;
        s += texture(TEXTURE, UV + vec2(-offset,  0.0   )).a;
        s += texture(TEXTURE, UV + vec2( 0.0,     offset)).a;
        s += texture(TEXTURE, UV + vec2( 0.0,    -offset)).a;
        s += texture(TEXTURE, UV + vec2( offset,  offset)).a;
        s += texture(TEXTURE, UV + vec2(-offset,  offset)).a;
        s += texture(TEXTURE, UV + vec2( offset, -offset)).a;
        s += texture(TEXTURE, UV + vec2(-offset, -offset)).a;
        
        glow_amount += (s / 8.0) * falloff;
    }
    
    glow_amount = clamp(glow_amount / float(glow_steps), 0.0, 1.0);
    
    vec4 glow = glow_color * glow_amount * glow_intensity;
    COLOR = col + glow * (1.0 - col.a);
}