# IDEAS — Antes y después del MVP

> Aquí se apunta, no se construye. Para pasar una idea a `PLAN.md` hace falta mi aprobación.

---

## Antes del MVP (solo si sobra tiempo, sin desviar el plan)

- Presets de cuerpo: atlético, delgado, robusto, mayor.
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
- **Materiales:** color de piel (decidido: después del MVP), texturas, estilo pixel art. (El estilo ilustración con contorno ya está en `PLAN.md`.)
- **Exportar:** VRM 1.0, niveles de detalle (LOD), opción "solo proxy ligero" (`cuerpo_ligero.glb` con `proxy741` de MakeHuman, mismas formas y nombres; la prenda necesitaría una máscara en textura para no salir dentada).

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
