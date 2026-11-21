// Paso 9.4: ojos anime pintados en un parche de la cara (eye_piece.gd). El dibujo (pestañas, iris, pupila y brillo)
// es la textura que pinta EyePiece.paint(); fuera de la forma del ojo el alfa es 0 y no se dibuja. Sin luces: color
// plano, como en una ilustración. Se adelanta depth_pull metros hacia la cámara para no pelearse con la piel.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D eye_texture : source_color, filter_linear, repeat_disable;
uniform float depth_pull = 0.001;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz -= normalize(view.xyz) * depth_pull;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	vec4 color = texture(eye_texture, UV);
	if (color.a < 0.5) {
		discard;
	}
	ALBEDO = color.rgb;
}
