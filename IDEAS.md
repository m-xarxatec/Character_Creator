# IDEAS — Antes y después del MVP

> Aquí se apunta, no se construye. Para pasar una idea a `PLAN.md` hace falta mi aprobación.

---

## Antes del MVP (solo si sobra tiempo, sin desviar el plan)

- Presets de cuerpo: atlético, delgado, robusto, mayor.
- `probar_rendimiento.gd` debería aceptar rutas relativas al `.glb` (hoy pide la absoluta; con `datos/humana/cuerpo.glb` no lo abre).
- Botón "aleatorio" con límites razonables.
- Comparar antes y después (dos maniquíes lado a lado).
- Medidas reales (altura en cm) junto a los deslizadores.
- Atajos de teclado.

---

## Después del MVP: más deslizadores

- Ir añadiendo filas a la tabla del paso 2.1 hasta cubrir cada detalle del cuerpo (MakeHuman trae unas 800 formas listas: orejas, nariz, mandíbula, dedos, pies…).
- Deslizador **Edad** (de adulto joven a mayor; nunca menores): la macro `age` de MakeHuman, con sus correcciones.

---

## Después del MVP: nuevas pestañas

- **Cara y ojos:** forma de la cara, ojos (forma y color), cejas, nariz, boca, orejas; expresiones y visemas.
- **Pelo:** peinados como piezas; melenas y coletas que se mueven con `SpringBoneSimulator3D`; más adelante, un pincel de pelo como el de VRoid.
- **Ropa:** prendas que siguen al cuerpo (anclaje tipo `.mhclo`), capas, ocultar la piel que queda bajo la ropa.
- **Accesorios:** cascos, gafas o armas en los puntos de anclaje.
- **Materiales:** texturas de piel, estilo pixel art. (El color de piel pasó al MVP el 2026-11-12, solo el color: paso 4.7 de `PLAN.md`.) (El estilo ilustración con contorno ya está en `PLAN.md`.)
- **Exportar:** VRM 1.0, niveles de detalle (LOD).
- **Selector de polígonos al exportar:** Low-poly (proxy741), Ligero (proxy ~1.600), Medio (reducción automática de la base), Completo (base). Opción de sombreado plano. Mismos huesos y anclajes; pesos heredados de la base; textura de prenda horneada por nivel; pruebas de deformación por nivel.

---

## Después del MVP: pestaña Cara

- Deslizadores por rasgo (mentón, nariz, pómulos, mandíbula, ojos, boca…), como los creadores de personajes de los juegos. Valorar reutilizar las formas de cara de MakeHuman sobre la cabeza anime (mismos vértices).
- Los ojos de calcomanía se deforman en tres cuartos y de perfil: hará falta otro sistema de ojos.
- Un deslizador por rasgo a partir de las formas de la cara anime (`cuenca_plana`, `boca_anime`, `mandibula_anime`, `menton_anime`, `nariz_anime`): cada una, una fila de la tabla del 2.1.
- Esas formas aplastan las bolsas interiores de la boca y los ojos (hasta 58 mm): hay que resolverlo antes de abrir la boca (expresiones, visemas).
- Candidatas CC0 de OpenGameArt para la pestaña Cara y la base chibi: Generic Anime Face (Barely_Banquo, con expresiones), 3d female anime head (ColdOneK), Base Rigged Stylized Humanoid YW (Girush) y Tiby (PINKCANNON, chibi).
- Cabezas con licencia CC-BY-SA como pack opcional, con aviso claro de la licencia al elegirlas.

---

## Después del MVP: contorno

- Contorno tipo ilustración regulable: desde quitarlo del todo hasta muy grueso, con un deslizador; quizá también color del contorno y grosor distinto por zona (cara más fino, silueta más grueso).
- Hace grumos en los dedos de manos y pies (grosor en píxeles mayor que el dedo en pantalla): hace falta grosor por zona.
- El borde de la prenda sale ondulado en primeros planos: revisarlo.

---

## Después del MVP: estilos visuales

- **Estilo como archivo de datos** (como la tabla de deslizadores): tonos de sombra (2, 3 o suave), dureza del borde, contorno (grosor y color), luz de borde y tono de la piel en sombra. Añadir un estilo = añadir un archivo.
- **Grado de realismo**, de anime a semirrealista: cambia el sombreado (toon o PBR), las texturas de piel y la cabeza. Sin hiperrealismo: el `.glb` sale con UV limpias y malla completa para que cada uno añada sus texturas en Blender.
- **Tinte de sombra** en el panel Acabado: que la sombra pueda cambiar de matiz (p. ej. más rojiza o azulada), no solo oscurecerse.
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
- **Simetría relativa:** mover un lado suma lo mismo al otro y conserva la diferencia.
- **8 influencias:** opción de exportar con 8 influencias por vértice (sin pérdida; Godot lo admite, algunos motores solo leen 4).
- **Cuelgue de GLTFDocument:** investigar el cuelgue de `GLTFDocument` al leer un glTF con BoneAttachment y sin malla ni piel; reproducción mínima y posible reporte a Godot.

---

## Para el juego oscuro (se hará junto con el juego)

- Espadas, escudos y linternas en los puntos de anclaje.
- Base chibi (unas 2,5 cabezas) y base esbelta con partes exageradas.
- Daño por zonas del cuerpo usando los mismos huesos.

---

## Descartadas (y por qué)

- **VRoid Studio como base:** es cerrado y sus mallas son de pixiv.
- **MB-Lab:** sus personajes son AGPL.
- **SMPL / SMPL-X:** licencias restringidas.
- **Buscador abierto de assets en internet:** las licencias vienen mezcladas.
