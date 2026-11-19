# DECISIONES — lo que necesito del responsable

> Sesión de traspaso (2026-11-16). Cada entrada: pregunta, opciones, recomendación y qué pasa si no se decide.
> **«Supuesto»** = ya elegí la opción más prudente para poder seguir escribiendo; se puede cambiar.
> Los documentos de `ruta/` citan estas entradas por su código (D1, D2…).

## Tomadas al juntar las ramas (2026-11-16, Linux)

El responsable delegó las decisiones técnicas. Las de 4.4 a 5.2 ya estaban resueltas en el código (ver el registro de `PLAN.md`).

- **D4 a)** y **D5 a)**: A1 y A2 entran en `PLAN.md` antes del 5.3. A2 cuesta menos cuanto antes se haga.
- **D10 a)**: el 5.3 exige 53 huesos, todos del perfil; los 3 que faltan llegan con la cara.
- **D12**: se queda la biblioteca entera (7,3 MB, ya subida); el responsable prefiere no subir más peso por ahora.
- **D27 a)**, pero como paso **7.0** (la Fase 4 ya está cerrada).
- **A3 (`WorldPose`)**: no entra ahora. El 5.1 y el 5.2 se resolvieron con `pose_retarget.gd` y `static_pose.gd`, con sus pruebas. El borrador sigue en `ruta/codigo/` para la Fase 10 (estudio y proyecto).
- **A4**: no se rehace. El 4.4 y el 4.7 guardan los valores en `body_editor.gd` y el acabado en el material; el diccionario de estado único se retoma con el formato de proyecto (Fase 10).
- Fichas borradas por ya hechas: 4.4 a 4.7, 5.1, 5.2 y A4.

## Las 3 más urgentes

1. **D5** — mover `datos/` a `godot/datos/`. Condiciona A2, el 5.1, los builds y Android. Cuanto más tarde, más archivos que cambiar.
2. **D4** — `.gitattributes` para `datos/` (A1). Dos líneas; evita que un clon en Windows deje de cargar.
3. **D3** (con D1 y D2) — cómo se comportan el 4.4 y el 4.5, que son los siguientes pasos. Tienen supuesto: si no dices nada, se sigue con él.

Después: **D16** (instalar Godot en la máquina Windows; sin ello no se pudo medir nada en esta sesión) y **D27** (botones Guardar y Abrir preset en el MVP).

## Supuestos tomados en esta sesión (se pueden cambiar)

D1 a), D2 a), D3 a), D7 a), D17 a) y D20 a) condicionada a la medida. Además, sin código de decisión:

- Las fichas se escribieron sobre el commit `61aaee9` sin ejecutar nada (esta máquina no tiene Godot ni Blender). Toda API marcada «NO VERIFICADO» lleva su comprobación o su plan B en la ficha.
- El build de Windows es la Fase 8 (después del MVP), no parte del 7.1.
- La versión de la primera publicación es `0.1.0`.
- Nombre de paquete provisional en Android: `org.gamemolde.humo` (solo para el APK de medidas).

## Urgentes (bloquean el siguiente paso)

| Código | Antes de | Pregunta | Opciones | Recomendación | Si no decides |
| --- | --- | --- | --- | --- | --- |
| D1 | 4.4 | ¿La simetría empieza activada? | a) Sí · b) No | **a)** El preset de personaje nuevo es simétrico. | Supuesto: a). |
| D2 | 4.4 | «Restablecer zona», ¿a qué valores vuelve? | a) Al preset de personaje nuevo · b) Al neutro de la tabla | **a)** Hoy dan lo mismo en el cuerpo; a) seguirá valiendo con otros presets de inicio. | Supuesto: a). |
| D3 | 4.5 | ¿«Probar huesos» anima el personaje **horneado** (el que se exporta) en vez del maniquí en vivo? | a) Horneado · b) En vivo | **a)** Prueba lo que de verdad sale del editor; el maniquí en vivo difiere hasta 20,1 mm al doblar (medida del 3.6.3). | Supuesto: a). |
| D4 | A1 | ¿Apruebas añadir a `.gitattributes` que `datos/` no cambie los finales de línea? | a) Sí · b) No | **a)** Sin esto, un clon en Windows con `core.autocrlf=true` cambia el `sha256` de los `.json` y `.csv` y el editor no carga. | No se aplica; riesgo en cada clon de Windows. |
| D5 | A2, 7.1 y Fase 15 | ¿Mover `datos/` a `godot/datos/` (dentro del proyecto de Godot)? | a) Mover · b) Dejarla fuera y copiarla junto al ejecutable | **a)** Es la única forma que vale igual en Linux, Windows y Android (en Android no hay «junto al ejecutable»). Ver `PLATAFORMAS.md` §2. | b): vale para PC; Android queda bloqueado hasta decidir. |

## Antes de cerrar el MVP

| Código | Antes de | Pregunta | Opciones | Recomendación | Si no decides |
| --- | --- | --- | --- | --- | --- |
| D6 | 4.6 | La vista en vivo usa dos mallas: la normal al arrastrar y la de estilo al soltar. Al empezar a arrastrar hay un cambio brusco de sombreado. ¿Vale? | a) Vale · b) No vale (hace falta otro método, más caro) | Decidir **mirando** las capturas de la ficha 4.6. | Se implementa a) y se enseña. |
| D7 | 4.7 | El preset v2, ¿guarda los 6 valores del acabado (también tono medio y sombra) aunque el panel solo muestre 4? | a) Los 6 · b) Solo los 4 del panel | **a)** Así, añadir esos dos controles más adelante no obliga a una versión 3. | Supuesto: a). |
| D8 | 4.7 | ¿El panel Acabado incluye también el color de la prenda? El PLAN no lo pide; el preset ya lo guarda. | a) No · b) Sí | **a)** Ceñirse al paso. | a). |
| D9 | 4.7 | `datos/humana/presets/anime.json` está en formato v1. Migrarlo cambia su `sha256` y hay que regenerar el manifiesto con Blender. | a) Dejarlo en v1 (el cargador lo migra al leer) · b) Migrarlo y regenerar el manifiesto | **a)** hasta la próxima vez que se regenere `datos/` (6.2). | a). |
| D10 | 5.3 | El PLAN dice «56 huesos humanoides»; el personaje tiene **53** (faltan 3 del perfil; sin comprobar cuáles: probablemente los dos ojos y la mandíbula). | a) La prueba exige 53 y que todos sean del perfil · b) Añadir los 3 ya | **a)** Los 3 huesos se añaden en la Fase 9 (Cara), que es donde hacen falta. | a). |
| D11 | 5.5 y 5.7 | Pose de exportación: T horneada o A. Y además: ¿exportar los huesos con los ejes del perfil humanoide de Godot? | Se decide con las capturas y medidas de 5.5, 5.7 y 5.8 | Mi apuesta técnica: **T + ejes del perfil** (ver ficha 5.7). | **Decidida el 2026-11-18: T + ejes del perfil** (paso 5.16). |
| D12 | 5.1 | Las animaciones de prueba van dentro del editor. ¿La biblioteca de Quaternius entera o recortada? | a) Entera · b) Recortada a las 5–8 que se usan | **b)** El archivo pesa 7,6 MB (medido con `ls`, sin abrirlo). | a). |
| D13 | 6.1 | Las formas «Por crear», ¿se hacen por script (como la cara anime) en vez de esculpirlas a mano con MakeTarget? | a) Por script · b) A mano (lo haces tú en Blender) · c) Mixto | **c)** Script para lo geométrico (altura de hombros, alisado); a mano si el resultado no convence. | a) y se enseña. |
| D14 | 6.2 | Al añadir las formas, ¿sube la `version` del manifiesto a 3? `PLAN.md` dice que sí; `FORMATO.md`, solo si el cambio es incompatible. | a) Sube a 3 · b) Se queda en 2 | **a)** Seguir el PLAN: cuesta una línea y evita mezclar datos viejos con código nuevo. | a). |
| D27 | 4.7 | Ningún paso del PLAN pone en la ventana «Guardar preset» y «Abrir preset». Sin ellos, el MVP no puede guardar el trabajo salvo exportando. ¿Se añaden al 4.7 (subpaso 4.7c)? | a) Sí · b) No, después del MVP | **a)** Son dos botones sobre código que ya existe. | b): no se hace el 4.7c. |
| D15 | 7.4 | ¿Se publica el `.exe` de Windows sin firma de código? Windows mostrará un aviso de SmartScreen. | a) Sin firma, con aviso en el README · b) Comprar certificado | **a)** | a). |
| D28 | 7.3 y 7.4 | «GameMolde» es un nombre provisional. ¿Se publica la 0.1.0 con ese nombre? Cambiarlo después cambia la carpeta `user://`, el nombre del ejecutable y los enlaces. | a) Publicar como GameMolde · b) Elegir antes el definitivo | **b)** si ya tienes candidato; si no, a) y avisar en las notas de que el nombre puede cambiar. Comprobar que no lo usa otro programa pide red: lo haces tú. | **Decidida el 2026-11-18: GameMolde** (definitivo). |
| D29 | 7.4 | ¿La 0.1.0 sale como versión preliminar (*pre-release*) en GitHub hasta que la pruebe una persona ajena? | a) Sí · b) No | **a)** Se puede retirar sin que parezca una versión rota. | a). |

## Después del MVP

| Código | Antes de | Pregunta | Opciones | Recomendación | Si no decides |
| --- | --- | --- | --- | --- | --- |
| D16 | Fase 8 | Esta máquina Windows no tiene Godot ni Blender. ¿Instalo Godot 4.7.2 aquí para la Fase 8? (Blender no hace falta en Windows.) | a) Sí · b) Probar Windows solo con el build hecho en Linux | **a)** Permite pasar las pruebas sin ventana en Windows. | b). |
| D17 | Fase 10 | Nombre definitivo y extensión del archivo de proyecto. | a) `.gmolde` · b) Esperar al nombre definitivo | **a)** El lector reconoce el archivo por su campo `formato`, no por la extensión: cambiarla después cuesta una línea. | Supuesto: a). |
| D18 | Fase 10 | Si un proyecto viene de una versión **más nueva** del programa, ¿se rechaza o se abre ignorando lo desconocido? | a) Rechazar con el mensaje «actualiza el programa» · b) Abrir e ignorar | **a)** Es lo coherente con la carga estricta del preset (decidida en el 3.7). | a). |
| D19 | Fase 9 | ¿Se admiten assets CC-BY? (Pendiente en `IDEAS.md`.) | a) No · b) Sí, con el autor en `CREDITOS.md` y visible en la ficha | **a)** hasta que falte algo concreto que solo exista en CC-BY. | a). |
| D20 | Fase 15 | En Android, ¿se pueden mover los deslizadores? | a) Sí · b) No | **a)**, con condición medida: ver `PLATAFORMAS.md` §5.6. Si la medida en el aparato falla (p99 > 66 ms), se apaga con una etiqueta de plataforma. | a) condicionada a la medida. |
| D21 | Fase 15 (o 8.5) | Android necesita instalar JDK 17, el SDK de Android y las plantillas de exportación (red e instalación). ¿Cuándo? | a) Ya, tras Windows, para un APK de humo y medir · b) En la Fase 15 | **a)** Las medidas reales en el móvil condicionan el diseño del estudio (Fase 10). | b). |
| D22 | Fase 15 | Compartir imágenes desde Android con el menú «Compartir» del sistema necesita un plugin de Android (dependencia nueva o código Kotlin propio). | a) Solo «Guardar en…» con el selector del sistema · b) Plugin propio mínimo · c) Plugin de terceros (MIT) | **a)** primero; b) si de verdad se echa en falta. | a). |
| D23 | Fase 16 | Largo y grosor de hueso: ¿nuevo tipo de deslizador o siguen siendo «Proporción»? `CLAUDE.md` fija tres tipos. | a) Siguen siendo Proporción, con prefijos nuevos `largo:` y `grosor:` · b) Cuarto tipo «Hueso» | **a)** No cambia la regla de los tres tipos. | a). |
| D24 | Fase 17 | VRM: ¿código propio desde la especificación o depender del addon `godot-vrm` (MIT, V-Sekai; licencia y estado **NO VERIFICADOS**)? | a) Propio · b) Dependencia | Decidir tras el paso 17.1 (estudio). | No se empieza la Fase 17. |
| D25 | Cada fase | Orden de fases propuesto en `HOJA_DE_RUTA.md` §3. | Aprobar o cambiar | El propuesto. | Se sigue el propuesto. |
| D30 | 14.6 | ¿La interfaz usa una fuente propia con licencia OFL (pendiente en `diseno/`) o la de Godot? | a) La de Godot · b) Una OFL, con su archivo de licencia y fila en `CREDITOS.md` | **a)** hasta el paso 14.6; ahí se decide mirando la interfaz. | a). |
| D31 | 9.7 | Las expresiones y visemas tienen que **quedarse como formas dentro del `.glb`** para que el juego las anime. Hoy la regla es que el `.glb` no lleva formas (se hornean todas). ¿Se aprueba la regla nueva «las formas de identidad se hornean; las de expresión se exportan»? | a) Sí · b) No: las expresiones solo sirven dentro del editor y del estudio | **a)** Sin ella no hay expresiones en el juego ni VRM (Fase 17). Cambia `glb_exporter.gd`, `probar_glb.gd` y la tabla de reglas de `CLAUDE.md`. | No se empieza el 9.7. |
| D42 | X.17 | ¿Se permiten personajes de 5 a 60 años, como Anny (deslizador Edad completo y plantillas por edad)? | a) No: siempre adulto · b) Sí, cambiando la regla 11 y con las salvaguardas de X.17 | b) | **Decidida el 2026-11-19: b)**. Regla 11 ya cambiada; se construye en X.17. |
| D26 | Cada prueba nueva | Los límites numéricos de las pruebas nuevas van marcados «PROVISIONAL»: se fijan con la medida real (regla 9). | Aprobar cada uno al cerrar su paso | — | El paso no se cierra sin tu aprobación del límite. |
