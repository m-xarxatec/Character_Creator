# IDEAS — Antes y después del MVP

> Aquí se apunta, no se construye. Para pasar una idea a `PLAN.md` hace falta mi aprobación.

---

## Antes del MVP (solo si sobra tiempo, sin desviar el plan)

- Presets de cuerpo: atlético, delgado, robusto, mayor.
- Botón "aleatorio" con límites razonables.
- Comparar antes y después (dos maniquíes lado a lado).
- Medidas reales (altura en cm) junto a los deslizadores.
- Atajos de teclado.
- Rehacer expresiones y visemas cuando la cara esté lista (quitadas el 2026-11-25: se veían mal; el código del 9.7 y del 9.8 se queda, `blender/expresiones.json` vacío).
- Pesos de mandíbula y ojos (junto con el montaje de ojos): los huesos `Jaw`, `LeftEye` y `RightEye` del 9.3 no tienen pesos y no mueven nada.
- Investigar los 0,48 GB de RAM de más respecto al 7.1 (0,83 → 1,31 GB al arrancar, medido el 2026-11-25).
- Guardar el `.glb` en un hilo (OPT.3c, quitado el 2026-11-25): funciona y quita ~180 ms del final, pero `GlbExporter.write` necesita el hilo principal libre (bloquearlo con `wait_to_finish()` lo cuelga). Antes hay que resolver qué pasa si se cierra la ventana a mitad (`body_actions._exit_tree` espera al hilo) y que la puerta espere dibujando. Con 9.7–9.3 el final subió a 287–312 ms con ventana: `MAX_GAP_MS` pasa a 400 (2026-11-25).
- Pies al suelo al animar (IK de pies): sin él, con las rodillas dobladas los pies flotan según las proporciones (medido en el 5.1: hasta 168 mm al sentarse).

---

## Después del MVP: más deslizadores

- Ir añadiendo filas a la tabla del paso 2.1 hasta cubrir cada detalle del cuerpo (MakeHuman trae unas 800 formas listas: orejas, nariz, mandíbula, dedos, pies…).
- Deslizador **Edad** (primera parte, de joven a mayor): la macro `age` de MakeHuman, con sus correcciones.

---

## Después del MVP: nuevas pestañas

- **Cara y ojos:** forma de la cara, ojos (forma y color), cejas, nariz, boca, orejas; expresiones y visemas.
- **Pelo:** peinados como piezas; melenas y coletas que se mueven con `SpringBoneSimulator3D`; más adelante, un pincel de pelo como el de VRoid.
- **Pelo con la cabeza muy grande** (PE.4b, 2026-11-26): con Cabeza › Tamaño ×2,5 las cadenas crecen con la cabeza y la nuca se hunde hasta 41,6 mm en cuello y hombros (hair_long). En el editor la apartan los choques del simulador; en el `.glb`, no. Apartarla también ahí (por ejemplo, posar las cadenas fuera de los choques antes de hornear).
- **Pelo que traspasa la piel al moverse** (juicio del responsable, 2026-11-26: «se ve natural, me gusta, aunque traspasan la piel con el movimiento»): los choques son por articulación, no por vértice. Probar más radio de articulación, colisiones más ajustadas o más articulaciones por cadena.
- **Ajustes de física por peinado** (PE.4): el campo `fisica` de `pack.json` (rigidez, freno, gravedad, sectores) para afinar cada peinado; hoy todos usan `HairPhysics.DEFAULTS`.
- **Ropa:** prendas que siguen al cuerpo (anclaje tipo `.mhclo`), capas, ocultar la piel que queda bajo la ropa.
- **Accesorios:** cascos, gafas o armas en los puntos de anclaje.
- **Materiales:** texturas de piel, estilo pixel art. (El color de piel pasó al MVP el 2026-11-12, solo el color: paso 4.7 de `PLAN.md`.) (El estilo ilustración con contorno ya está en `PLAN.md`.)
- **Exportar:** VRM 1.0, niveles de detalle (LOD).
- **Hombro con el brazo sobre la cabeza:** la piel se hunde 21 mm (neutro) y 43 mm (extremo) al «Atacar» (5.8); la clavícula al 25 % (5.15) arregla la pose T, no esto. Haría falta una forma correctora guiada por el ángulo del brazo (o pesos mejores en el hombro), y que el juego la use.
- **`shoulder_height_decr` en la mujer musculada y grasa:** con `gender` 0 y `muscle` y `weight` a 1 invierte 4 triángulos, sea cual sea el pecho (4 de las 32 esquinas; medido en PL.0b, 2026-11-20). `probar_formas_propias.py` lo enseña como `MEDIDA` y hace fallar «macros extremas».
- **Selector de polígonos al exportar:** Low-poly (proxy741), Ligero (proxy ~1.600), Medio (reducción automática de la base), Completo (base). Opción de sombreado plano. Mismos huesos y anclajes; pesos heredados de la base; textura de prenda horneada por nivel; pruebas de deformación por nivel.

---

## Después del MVP: pestaña Cara

- Deslizadores por rasgo (mentón, nariz, pómulos, mandíbula, ojos, boca…), como los creadores de personajes de los juegos. Valorar reutilizar las formas de cara de MakeHuman sobre la cabeza anime (mismos vértices).
- Deslizador de separación de los ojos con las formas CC0 de MakeHuman que mueven los ojos; el ancla de la calcomanía es un vértice fijo, así que el ojo lo sigue. En el preset anime los ojos se ven algo separados.
- Los ojos de calcomanía se deforman en tres cuartos y de perfil: hará falta otro sistema de ojos.
- Un deslizador por rasgo a partir de las formas de la cara anime (`cuenca_plana`, `boca_anime`, `mandibula_anime`, `menton_anime`, `nariz_anime`): cada una, una fila de la tabla del 2.1.
- ~~Esas formas aplastan las bolsas interiores de la boca y los ojos (hasta 58 mm)~~: ojos, resuelto en AC.3; boca, en el 9.6 (`ruta/pasos/9.6_bolsa_boca.md`).
- Boca, después del 9.8b (de momento el interior va negro, D58): o un hueso de mandíbula (el `Jaw` del perfil humanoide, paso 9.3) o una boca interactiva, con dientes y lengua propios (CC0). Lo decide el responsable más adelante.
- Candidatas CC0 de OpenGameArt para la pestaña Cara y la base chibi: Generic Anime Face (Barely_Banquo, con expresiones), 3d female anime head (ColdOneK), Base Rigged Stylized Humanoid YW (Girush) y Tiby (PINKCANNON, chibi).
- Cabezas con licencia CC-BY-SA como pack opcional, con aviso claro de la licencia al elegirlas.

---
- **Deslizadores de ojos más extremos** (responsable, 2026-11-25), cuando los ojos no sean solo dibujos. Cómo: el alcance `@` del CSV (como nariz, orejas y boca), con `probar_forma_ojo.py` a 0 cruces y 0 invertidos. Los que no se ampliaron en nariz, boca y orejas (`mouth_position`, `ear_wing` y una dirección de otros 6) ya añadían cruces o invertidos a ×1,1: necesitarían corregir la forma, no solo alargarla.

## Después del MVP: contorno

- Contorno tipo ilustración regulable: desde quitarlo del todo hasta muy grueso, con un deslizador; quizá también color del contorno y grosor distinto por zona (cara más fino, silueta más grueso).
- Hace grumos en los dedos de manos y pies (grosor en píxeles mayor que el dedo en pantalla): hace falta grosor por zona.

---

## Después del MVP: estilos visuales

- **Estilo como archivo de datos** (como la tabla de deslizadores): tonos de sombra (2, 3 o suave), dureza del borde, contorno (grosor y color), luz de borde y tono de la piel en sombra. Añadir un estilo = añadir un archivo.
- **Grado de realismo**, de anime a semirrealista: cambia el sombreado (toon o PBR), las texturas de piel y la cabeza. Sin hiperrealismo: el `.glb` sale con UV limpias y malla completa para que cada uno añada sus texturas en Blender.
- **Sombreado de la ampliación, meta estilo VRoid** (solo inspiración visual, sin su material ni assets): referencia visual `diseno/referencia_estilo_quaternius.png`; ver D44 en `ruta/DECISIONES.md`.
- **Acabado anime por capas** (D46, 2026-11-22): toon tipo VRoid y VTuber, con piel bonita en cualquier tono. Los ojos se hacen por capas y piezas, no pintados enteros en la cara; orden: base blanca, iris, pupila, brillos, párpado, pestañas. El shader sigue en la Fase SH de `PLAN.md` (D47); el toon suave queda solo como columna de comparación en SH.1. Imágenes de IA: antes, revisar su licencia.
- **Luz de vista previa en el editor:** control de ángulo e intensidad, solo para probar el personaje; no se exporta.
- **Sombra elegida a mano**, como mucho en un apartado «avanzado» (D48; no se hace ahora). Por defecto la sombra se calcula desde el color de cada zona (SH.2), sin galería.
- **Umbral del tono medio en la cara** como valor del acabado (no viaja a otros motores, por eso no es el arreglo de la franja de sombra).
- **Aplanar más las normales de la cara:** con fondo 0,35 sale una línea dura en la sien, probablemente por el escalón entre el medio elipsoide trasero y el delantero. Probar una transición gradual de la profundidad (sin escalón).
- **Estilos de ojos como packs** (iris, pestañas, brillos), según "Sistema de piezas".
- **Pantalla inicial con botones de estilo**, cada uno con un render del propio editor (nunca capturas de otros programas): Realista, Semi, Anime, Caricatura y Personalizado.
  - Cada botón elige una **BASE** (cabeza, proporciones de partida y qué deslizadores se muestran), que no se cambia a mitad de edición, y un **ACABADO** de partida (valores del shader), que sí se cambia en vivo.
  - Personalizado copia un acabado y lo guarda como archivo propio.
  - Caricatura, al final: necesita cabeza y proporciones propias; valorar compartir trabajo con el chibi.
- **Origen de los assets:** gratuitos con licencia comprobada o hechos por nosotros.
- **Decisión pendiente:** ¿la regla 5 admite CC-BY? Si se admite, el autor va a `CREDITOS.md` como el resto.

---

## Después del MVP: animaciones y suelo

- Más clips en la lista Animación, y una opción para cargar animaciones propias (un `.glb` con esqueleto humanoide).
- Suelo o rejilla en la vista 3D, y opciones para anclar los pies al suelo al animar (ver «Pies al suelo» más arriba).

## Después del MVP: interfaz

- Estética de la ventana del editor (tema, colores, tipografía, espaciado), según la maqueta. Hoy son los controles de Godot por defecto.
- Elegir tocando el cuerpo (IU.7) para partes pequeñas: rasgos de la cara (nariz, labios, cejas) u otras piezas, cuando el proyecto crezca.
- Barra de título de los diálogos (Ajustes, Comandos) con el tema: hoy es la gris de Godot (revisor, IU.11).
- Margen entre los textos del panel derecho («4 ajustes», «Más alto»…) y la barra de desplazamiento (revisor, IU.11).
- Cambio de color de 120 ms al pasar el ratón por los botones (guía §3 «Movimiento»): Godot no lo anima solo; pide código en cada botón. Fuera de IU.10.
- Miniaturas de piezas después del shader nuevo: imágenes comprimidas (WebP o PNG), generadas con un solo comando, sin depender del shader en tiempo de ejecución

## Pack "Universal Base Characters" de Quaternius (CC0)

El zip está en `referencias/` (git no lo guarda). Versión gratis: 2 cuerpos estilizados en pose T con ropa interior pintada, 8 peinados, cejas y barba. Mismo esqueleto que sus animaciones.

- **No sirve como cuerpo del MVP:** no trae formas (*blend shapes*), así que no habría deslizadores de Forma.
- **Peinados, cejas y barba:** primeras piezas para la pestaña Pelo.
- **Segunda base estilizada** (solo deslizadores de Proporción), como otra "especie".
- **Referencia de estilo** para esculpir nuestras formas propias (Fase 6) y para la ropa interior pintada.

---

## Sistema de piezas (packs)

- Carpeta de packs: `.glb` + ficha `.json` (tipo, ranura, autor, licencia, origen) + miniatura.
- Conversor de assets CC0 de MakeHuman a packs.
- Adaptador en Blender para piezas de otras webs (ajuste al cuerpo y pesos), con revisión a mano.
- Catálogo en línea: una lista en GitHub solo con piezas de licencia comprobada.

---

## Ampliación (visión a largo plazo)

- **Especies:** bases no humanas (criaturas, bestias) y bases estilizadas propias, sin rehacer el editor.
- **Plugin para Godot:** la misma herramienta como pestaña dentro del editor de Godot, junto a 2D, 3D y Script.
- **NPC en el juego:** usar el núcleo en tiempo de juego para crear multitudes variadas.
- **Versión web** (Three.js) con la misma carpeta `datos/`.
- **Android** (tablet).
- **Rig automático con IA** (UniRig) para mallas importadas sin huesos, cuando haya una GPU con más de 8 GB.
- **Comunidad:** repositorio de packs, guía para crear piezas, traducciones.
- **Aleatorio con candados y semilla** (de PL.5, quitado por el responsable el 2026-11-20): candado por zona para que el azar no la cambie, «Atrevido» (0–1) y la semilla visible para repetir una tirada.
- **Simetría relativa:** mover un lado suma lo mismo al otro y conserva la diferencia.
- **8 influencias:** opción de exportar con 8 influencias por vértice (sin pérdida; Godot lo admite, algunos motores solo leen 4).
- **Genitales (opcional):** cuando el cuerpo sea razonable, después del MVP. apagado por defecto y como pieza aparte; choca con «sin detalle anatómico», así que pide su propia decisión antes de entrar en un plan.
- **Cuelgue de GLTFDocument:** investigar el cuelgue de `GLTFDocument` al leer un glTF con BoneAttachment y sin malla ni piel; reproducción mínima y posible reporte a Godot.

---

## Para el juego oscuro (se hará junto con el juego)

- Espadas, escudos y linternas en los puntos de anclaje.
- Base chibi (unas 2,5 cabezas) y base esbelta con partes exageradas.
- Daño por zonas del cuerpo usando los mismos huesos.
- Piezas (2026-11-21, tras AB.5–AB.13): ponerlas y quitarlas con Deshacer (aplazado hasta después de la expansión, 2026-11-22); largo de manga, pernera y falda como
  deslizadores (bloque `parametros` del proyecto); borde de las prendas recortadas sin dientes (partir aristas);
  borrar al exportar la piel tapada (12.5); miniaturas de las piezas en las pestañas.

- **RE.1c, prendas de OverScore que no entraron** (no pasan los límites de la ficha `ruta/pasos/RE.1c_overscore_ropa.md`): Jean Shorts («Atacar» 6,73 %), Scallop Trim T-Shirt («Atacar» 16,0 mm), Sports Jersey («Atacar» 5,08 % y 18,9 mm), Hoodie with Hood Down (hueco 1,46 mm, hundida 6,19 mm, «Atacar» 19,5 mm), Short-Sleeve Sweatshirt (hueco −2,22 mm, hundida 8,27 mm, «Atacar» 12,3 mm), Turtleneck Sweater (hueco −4,49 mm, 3,43 % bajo la piel, «Atacar» 5,93 % y 19,9 mm, 60 cruces con pelo corto) y Long Sleeve Athletic Top (hueco −15,93 mm, 8,18 % bajo la piel, «Atacar» 18,8 mm).

---

## Descartadas (y por qué)

- **Pelo anime por parámetros** (PE.1, 2026-11-25): casquete y mechones en hoja generados en Blender. Probado en el programa: «las formas están raras, no parecen cabello». Se sigue con huesos para los peinados que ya hay (Fase PE).

- **VRoid Studio como base:** es cerrado y sus mallas son de pixiv.
- **MB-Lab:** sus personajes son AGPL.
- **SMPL / SMPL-X:** licencias restringidas.
- **Buscador abierto de assets en internet:** las licencias vienen mezcladas.
