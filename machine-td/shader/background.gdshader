shader_type canvas_item;

uniform float speed = 0.5;

void vertex() {
	//UV.x -= speed * TIME;
	UV.y += speed * TIME;
}


//void fragment() {
	//vec4 tex = texture(TEXTURE, UV);
	//// 只在 UV.y>0.4 之后开始变暗，0~0.4底部保持全亮
	//float mask = smoothstep(0.4, 1.0, UV.y);
	//float light = 1.0 - mask * 0.7;
	//COLOR = tex * light;
//}