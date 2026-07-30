shader_type canvas_item;

uniform float speed = 0.5;
uniform float darkness : hint_range(0.0, 1.0) = 0.7;  // 0=全黑顶部，1=无变化
// 定义一个变量，将原始UV传递给fragment
varying float base_y;

void vertex() {
	//UV.x -= speed * TIME;
	base_y = UV.y;          // 先保存原始的Y坐标（0~1）
	UV.y += speed * TIME;
}


void fragment() {
    // 用滚动后的UV采样纹理（实现滚动效果）
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 用原始的base_y计算暗化（始终在0~1之间，不会变白）
    // 顶部(base_y=0)变暗，底部(base_y=1)保持原色
    float factor = mix(darkness, 1.0, base_y);
    
    COLOR = tex_color * factor;
}