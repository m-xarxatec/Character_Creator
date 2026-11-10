// Material del cuerpo: piel o prenda base según el color por vértice `garment` (rojo; 1 = prenda), con corte en 0,5.
// El corte es por píxel: el borde sale recto y sigue al cuerpo. Sin luces por ahora; el estilo ilustración llega en el paso 3.10.
shader_type spatial;
render_mode unshaded;

uniform vec3 skin_color : source_color = vec3(0.93, 0.80, 0.70);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform bool show_garment = true;

void fragment() {
	float garment = show_garment ? step(0.5, COLOR.r) : 0.0;
	ALBEDO = mix(skin_color, garment_color, garment);
}
