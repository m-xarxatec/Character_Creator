# Recursos 3D externos: hoja para el agente

Búsqueda del mentor (2026-11-18 y 2026-11-19). Todo lo de esta hoja se comprobó **solo en la web**: la licencia hay que volver a comprobarla en el archivo descargado. La hoja de trabajo es `propuestas/recursos_3d.csv` (una fila por recurso, con la columna `estado`); este documento explica cómo usarla.

**Resumen:** 9 recursos de prioridad 1, 15 de prioridad 2, 19 de prioridad 3–4, 5 en la lista B (esperan una decisión) y 9 descartados. Lo más valioso es MakeHuman: sus packs CC0 están hechos para **nuestra misma malla base**, así que encajan sin moldear.

---

## 1. Reglas (no se negocian)

1. **Permiso de red por lote.** El agente presenta la lista de URLs del lote y espera el «sí» del responsable. Nada se baja sin ese permiso.
2. **Licencias:** solo CC0, MIT, Apache 2.0 o GPL. El código GPL solo vale como herramienta de `blender/`; nunca entra en el núcleo MIT (tampoco un shader GPL3). La lista B espera su decisión; los descartados no se bajan nunca.
3. **Dos comprobaciones de licencia:** (a) la página del autor: copiar la frase de la licencia y la fecha en `LICENCIA_pagina.txt`; (b) el `LICENSE` o el léeme que trae el archivo. Si no dicen lo mismo, el recurso pasa a `descartado` (señal de alarma 3).
4. **Nada** de VRoid, MB-Lab, SMPL, Mixamo ni código de Humanizer.
5. **Edad:** solo piezas y cuerpos de proporción adulta. Las proporciones «Teen» de Quaternius no se usan. Las edades del editor salen solo de MakeHuman (X.17, D42).
6. **Solo la versión gratis** de cada pack (las versiones «Source» o «Extra» no hacen falta).
7. **Un paso cada vez, con su ficha** en `ruta/pasos/`. El responsable hace todo lo de git.

## 2. Seguridad con lo descargado

Todo lo descargado es **no confiable** hasta revisarlo:

- Cada recurso en su carpeta vacía: `recursos_externos/<id>/original/`. La carpeta está fuera de `godot/`, así Godot no la importa sola, y va en `.gitignore`.
- Guardar el **sha256** del archivo descargado.
- **Listar antes de extraer** (`unzip -l`). Rechazar rutas con `../` o absolutas, enlaces simbólicos y ejecutables (`.exe`, `.bat`, `.sh`, `.py`, `.dll`, `.so`).
- Los scripts del agente viven en el repo, **no** dentro de `recursos_externos/`. Python se ejecuta con `-I` y recibe las rutas como argumento.
- Blender: abrir los `.blend` con `blender --disable-autoexec`. No activar nunca «Auto Run Python Scripts».
- Addons de Godot (HE03, el paquete de Calinou): **leer el código** antes de activarlos. Solo entran en `godot/addons/` con ficha aprobada.

## 3. Carpetas

| Carpeta | Qué guarda | ¿Git? |
| --- | --- | --- |
| `recursos_externos/<id>/original/` | El archivo tal cual, `LICENCIA_pagina.txt`, `sha256.txt` | No |
| `recursos_externos/<id>/prueba/` | Capturas y el informe de la prueba | No (el informe se copia a la ficha) |
| `pruebas/recursos/` | Escena de Godot para probar (cargar, mirar, medir) | Solo el script y la escena |
| La columna `destino_final` | La pieza **ya adaptada** | Sí (`.glb` por LFS) |

Proponer en RE.0 si las texturas grandes (`.png`, `.hdr` y `.exr` dentro de `godot/packs/`) también van por LFS, y vigilar la cuota de LFS de GitHub.

## 4. Pasos nuevos: fase RE (va antes de la fase AB y con ella)

| Paso | Qué hace | Modelo |
| --- | --- | --- |
| **RE.0** | `.gitignore`; script `pruebas/recursos/inventario.py` (lista el zip, sha256, cuenta archivos por tipo, avisa de rutas o ejecutables raros); plantilla del informe | Barato |
| **RE.1** | Lote de **prioridad 1**: bajar, comprobar licencia, inventario, prueba rápida, informe. **No** se mete nada en `godot/packs/` todavía | Barato para bajar y contar; Fable para juzgar el encaje |
| **RE.2** | Lote de prioridad 2 (igual) | Igual |
| **RE.3** | Lote de prioridad 3, solo lo que pida algún paso | Igual |

**Adaptar** (moldear un peinado, transferir un traje, pasar una pose al rig) **no** es parte de la fase RE: se hace en el paso de la columna `paso` (AB.9b, 12.1, X.3…), con su propia ficha. Así cada adaptación se revisa sola.

Estados de la columna `estado`: `pendiente` → `descargado` → `licencia_ok` → `probado` → `adaptado`, o `descartado (motivo)`. La lista B empieza en `espera_decision`.

## 5. Informe de cada recurso

```
## <id> — <nombre>
- Descargado: fecha · archivo · tamaño · sha256 (8 primeros)
- Licencia: página (frase corta + fecha) · archivo (nombre + frase) · ¿coinciden? sí/no
- Contenido: n.º de piezas · formatos · triángulos (mín./máx.) · texturas (tamaños) · ¿esqueleto? ¿cuál?
- Prueba: qué se hizo · capturas · problemas
- Encaje: directo / moldear / transferir / solo referencia / no sirve
- Propuesta: siguiente paso y tamaño (S/M/L)
```

En `CREDITOS.md` se añade una fila con el formato que ya tiene (Qué es | Autor | Licencia | De dónde sale | Dónde se usa). En «De dónde sale» van el enlace, la fecha de descarga y los 8 primeros caracteres del sha256. Se añade **solo** cuando algo del recurso entra en git.

## 6. Señales de alarma (parar y avisar)

- La licencia del archivo no es la de la página, o pide atribución aunque diga CC0.
- Un personaje o pieza con aspecto de menor.
- Ejecutables, scripts o rutas raras dentro del archivo.
- Logos, marcas o personajes con derechos dentro del pack.
- El tamaño amenaza la cuota de LFS.

---

## 7. Prioridad 1: alimenta lo siguiente y encaja casi solo

| Id | Recurso | Licencia | Para qué | Paso | Prueba rápida |
| --- | --- | --- | --- | --- | --- |
| MH01 | MakeHuman: Shirts 01, Pants 01, Skirts 01, Dress 01, Suits 01/02/05, Underwear 01 | CC0 (cada pack) | Prendas hechas para NUESTRA malla base: prueba real del lector .mhclo y de la transferencia | 12.1, AB.4, AB.5 | 3 prendas sobre el cuerpo neutro y 2 plantillas extremas; capturas frente y espalda; medir piel que atraviesa |
| MH02 | MakeHuman: pelo de system assets + Hair 01 + hair materials 01/02 | CC0 | Peinados anclados a helper-hair: encajan sin moldear | AB.9d | 3 peinados; transparencia y orden de dibujo con el estilo toon; contar triángulos |
| MH03 | MakeHuman: Faceunits 01 (52 ARKit), Visemes 01 (Microsoft), Visemes 02 (Meta/Oculus) | CC0 | Expresiones y bocas para hablar (sincronía de labios) | R.1, 9.x, R.14 | 5 expresiones y 5 visemas sobre el cuerpo neutro; nombres iguales a ARKit |
| MH04 | MakeHuman targets: Animal 01, Arms 01, Cheek 01, Ears 01, Hands 01, Nose 01 | CC0 | Más deslizadores: orejas (elfo, animal), nariz, mejillas, brazos, manos | X.2, AB.12, 9.2 | Cada target a 0,5 y 1; ver que no mueve la prenda base ni los helpers |
| QU01 | Quaternius: Universal Base Characters (solo proporciones adultas) | CC0 | Peinados toon para moldear, cejas y barba | AB.9b | Contar peinados de la versión gratis; moldear 2 con blender/moldear_peinado.py |
| QU02 | Quaternius: Universal Animation Library 2 (versión gratis) | CC0 | Más clips con el mismo esqueleto que UAL1 (ya en el proyecto) | X.3, fase 10 | 10 clips con PoseRetarget; medir pies flotando (X.1) y hombros (X.4) |
| KK01 | KayKit: Character Pack Adventurers (versión Free) | CC0 | 25+ armas y accesorios rígidos para los anclajes | AB.11 | 5 armas en los anclajes de mano y espalda; escala y giro; capturas |
| KE01 | Kenney: Prototype Textures (o la versión para Godot de Calinou) | CC0 | Rejilla para ver UV estiradas y suelo del estudio con escala | pruebas, fase 10 | Aplicar al cuerpo y a 2 prendas: ver costuras y estiramiento |
| HE01 | Khronos glTF-Validator | Apache-2.0 (no se distribuye) | Validar los .glb que exportamos y los que bajamos | 7.x, AB.7, 17 | Validar el .glb que exporta hoy el editor: 0 errores |

## 8. Prioridad 2: hay que adaptarlo o va en fases próximas

| Id | Recurso | Licencia | Para qué | Paso | Prueba rápida |
| --- | --- | --- | --- | --- | --- |
| MH05 | MakeHuman: Hats 01, Hats 02 (cascos), Glasses 01, Masks 01, Jewelry01, Gloves 01, Shoes 01, Underwear 04 (calcetines) | CC0 | Calzado, guantes y accesorios que siguen al cuerpo | AB.10, AB.11, R.9 | Casco + pelo juntos (R.9: el casco quita el pelo); zapatos en 2 alturas |
| MH06 | MakeHuman: Bodyparts 01 (cuernos), 04 (uñas), 05 (barbas), Eyebrows 01, Eyelashes 01 | CC0 | Cuernos, barbas, cejas y pestañas que siguen a la cara | 9.x, AB.11 | Cejas y pestañas con 3 caras distintas; cuernos con la cabeza más grande |
| MH07 | MakeHuman: eye materials 01 y 02 (02 = no humanos) | CC0 | Iris para la pestaña Cara y ojos | 9.4 | Ver 5 iris con el estilo toon y con el semirrealista |
| MH08 | MakeHuman: system poses + Poses 01–05 (sentado, deporte, de pie, dramáticas, lucha) | CC0 | Poses del estudio | fase 10, X.3 | Pasar 5 poses al rig Game engine; revisar dedos y hombros |
| MH09 | MakeHuman: Skins 01–03 + clothes materials 01 | CC0 | Base para el estilo semirrealista y las texturas de piel | 14.4, X.6 | 2 pieles en el estilo semirrealista; ver costuras UV |
| QU03 | Quaternius: Modular Character Outfits – Fantasy (nov. 2025) | CC0 | 12 trajes en 62 piezas, 3 texturas cada uno | 12.1 (transferencia) | Transferir 1 traje a nuestro cuerpo; medir atravesados con 3 plantillas |
| QU04 | Quaternius: LowPoly Medieval Weapons | CC0 | 22 armas rígidas | AB.11 | Igual que KK01 |
| KK02 | KayKit: Character Animations 1.1 | CC0 | Clips de acciones y herramientas | X.3 | 5 clips con PoseRetarget |
| PE01 | Micket: peinados low poly (coleta, punk corto, melena, hacia arriba, raya al lado) | CC0 | Primeros peinados para estrenar el moldeado (pocos vértices) | AB.9b | Moldear 1 a nuestra cabeza |
| OJ01 | byzmod3d: texturas de ojos | CC0 | Ojos de estilo toon | 9.4 | 3 ojos en la cara anime |
| OJ02 | n64guy: N64 Eyes | CC0 | Ojos de baja resolución para el estilo pixel art | X.6, 9.4 | Con el estilo pixel art |
| HD01 | Poly Haven: 3–4 HDRI (estudio, día, atardecer, interior oscuro) a 1k–2k | CC0 | Presets de luz y reflejos | X.8, IU.3 | Mismo personaje con los 4 presets; medir memoria |
| MA01 | ambientCG: telas (algodón, denim, cuero, punto) | CC0 | Materiales de ropa para el semirrealista y para sacar texturas toon | AB.5, X.6, R.18 | 2 telas en una camiseta de AB.5 |
| HE02 | VRM Add-on for Blender | MIT (no se distribuye) | Abrir VRM de prueba y revisar nuestra exportación VRM | fase 17 | Abrir 1 avatar de VR01 y ver sus metadatos |
| HE03 | godot-vrm (fork activo de AzPepoze, v2.5.7) | MIT | Importar y exportar VRM dentro de Godot | fase 17 (D24) | LEER EL CÓDIGO antes de activarlo; importar 1 avatar de VR01 |

## 9. Prioridad 3–4: más adelante u opcional

| Id | Recurso | Licencia | Para qué | Paso | Prueba rápida |
| --- | --- | --- | --- | --- | --- |
| QU05 | Quaternius: Ultimate Modular Men y Ultimate Modular Women | CC0 | Más pelo y ropa para moldear o transferir | AB.9b, 12.1 | Contar piezas útiles; probar 1 peinado |
| QU06 | Quaternius: Ultimate Animated Character Pack | CC0 | Personajes con otro esqueleto: prueba de cargar animaciones ajenas | X.3, R.17 | Pasar 3 clips de su esqueleto al nuestro |
| QU07 | Quaternius: Fantasy Props MegaKit (211 modelos) | CC0 | Objetos para las manos y para el estudio | AB.11, fase 10 | 5 objetos en la mano |
| QU08 | Quaternius: Modular Dungeon, Medieval Village, Nature | CC0 | Fondos del estudio de poses y de la vista previa | X.8, fase 10 | 1 fondo con el personaje; medir FPS |
| QU09 | Quaternius: Background Posed Humans | CC0 | Pelo para separar del cuerpo y moldear | AB.9b | Solo si faltan peinados |
| KK03 | KayKit: Skeletons | CC0 | Cascos y escudos; 90+ animaciones para probar el reajuste | AB.11, X.3 | 2 accesorios y 3 clips |
| KK04 | KayKit: Dungeon Remastered (versión Free 1.1) | CC0 | 200+ piezas: fondo «mazmorra» del estudio | X.8, fase 10 | 1 sala de fondo |
| KE02 | Kenney: Furniture Kit | CC0 | Sillas y sofás para las poses sentadas de MH08 | fase 10 | Pose sentada sobre una silla |
| KE03 | Kenney: Interface Sounds + UI Audio | CC0 | Sonidos de interfaz (opcional, apagados por defecto) | IU (opcional) | Clic, deshacer, exportar |
| KE04 | Kenney: Animated Characters 1–3, Mini Characters, Blocky Characters | CC0 | Esqueletos ajenos para probar X.3; referencia chibi para PL.9 | X.3, PL.9 | 1 clip ajeno en nuestro cuerpo |
| VR01 | 100 Avatars R1–R3 (bajar solo 3 avatares) | CC0 (comprobar cada avatar) | Archivos VRM reales para probar importar y exportar | fase 17 | Abrir con HE02 y HE03; el repo entero pesa unos 2,26 GB: NO clonarlo |
| PE02 | tiko479: rastas toon | CC0 | Peinados para moldear | AB.9b | Moldear 1 |
| PE03 | The Wild Dodo: Low Poly Male And Female Models (solo el pelo) | CC0 | Coleta, cortos, pelo con gorra | AB.9b | Moldear 1 |
| PE04 | PINKCANNON: Tiby (solo el pelo) | Dominio público (comprobar el texto exacto) | Pelo chibi separable | AB.9b, PL.9 | Solo si faltan peinados |
| RF01 | Girush: Base Rigged Stylized Humanoid Character (YW) | CC0 (comprobar) | Referencia de proporciones anime masculinas | PL (plantillas) | Medir cabezas de alto y comparar con nuestras plantillas |
| RF02 | System G6 Modular RPG Characters | CC0 (comprobar) | Más piezas modulares para transferir | 12.1 | Contar piezas útiles |
| MA02 | Poly Haven texturas + ShareTextures | CC0 | Suelos y paredes del estudio, telas extra | fase 10, X.6 | 1 suelo del estudio |
| SH01 | godotshaders.com: «Ultimate Toon Shader» y otros con etiqueta CC0 o MIT | CC0 / MIT según el shader | Comparar con nuestro toon y con el contorno | X.6, X.7 | Solo CC0/MIT: un shader GPL3 no puede entrar en el núcleo MIT |
| RF03 | Anny (Naver): mallas ligeras y proyección | Código Apache-2.0 | Ya analizado: reimplementar y citar (D40), no copiar | R.4, R.5 | Nada que bajar ahora |

## 10. Lista B: esperan una decisión del responsable

| Id | Recurso | Licencia | Decisión o paso | Qué hacer |
| --- | --- | --- | --- | --- |
| B01 | MakeHuman packs CC-BY: Bodyparts 02/03 (colas y alas)/06, Hair 02/03, Shirts 02/03, Pants 02/03, Shoes 02/03, Skirts 02, Dress 02/03, Suits 03/04, Hats 03/04, Glasses 02, Masks 02, Jewelry02, Equipment 02/03, Underwear 02/03, eye materials 03, Animal 02–04 | CC-BY | D19 | NO BAJAR hasta que se decida D19 |
| B02 | edusilvart: Low Poly Character Customization | CC-BY 4.0 | D19 | NO BAJAR hasta D19 |
| B03 | CMU Graphics Lab Motion Capture Database | Licencia propia: uso libre, pero no se pueden vender los datos | Decisión nueva D43 (o el siguiente número libre) | NO BAJAR: no está en la lista de licencias del proyecto |
| B04 | Nunito | OFL | D30 (paso 14.6) | NO BAJAR hasta D30 |
| B05 | Alas con huesos | — | D19 / AB.11 | Nada que bajar |

Decisión nueva propuesta, **D43:** ¿se admite la base de datos de CMU (uso libre, pero sin vender los datos)? a) No · b) Sí, solo como fuente para hacer nuestras propias animaciones, con fila en `CREDITOS.md`. Recomendación del mentor: **a)** hasta que UAL2 y KayKit se queden cortos.

## 11. Descartados: nunca se bajan

| Id | Qué | Por qué no |
| --- | --- | --- |
| NO01 | Mixamo | No se puede redistribuir |
| NO02 | VRoid Studio y los «VRoid CC0 models» de OpenGameArt | Regla del proyecto; licencias mezcladas dentro de los archivos |
| NO03 | SMPL / SMPL-X / AMASS, MB-Lab | Uso no comercial / regla del proyecto |
| NO04 | Humanizer (código) | AGPL-3.0 en su LICENSE: solo ideas (alarma 7) |
| NO05 | Packs de tienda «royalty free» (CGTrader, Fab, ArtStation, Unity, TurboSquid, aunque sean gratis) | No se pueden redistribuir dentro de un programa libre |
| NO06 | Superhive «Basemesh Pack – Free Edition» | Solo uso personal |
| NO07 | FreePBR, AITextured | Uso personal o licencia restringida |
| NO08 | Proporciones «Teen» de Quaternius y cualquier pieza externa con aspecto de menor | Las edades salen solo de MakeHuman (X.17, D42) |
| NO09 | Versiones «Source» o «Extra» de Quaternius y KayKit | No hacen falta: solo la versión gratis |

## 12. Fuentes generales para buscar más (siempre con la regla 3)

- MakeHuman: https://static.makehumancommunity.org/assets/assetpacks/index.html (la licencia de cada pack está en la propia lista)
- Quaternius: https://quaternius.com · KayKit: https://kaylousberg.itch.io · Kenney: https://kenney.nl/assets
- OpenGameArt (filtrar por CC0): https://opengameart.org · Poly Haven: https://polyhaven.com · ambientCG: https://ambientcg.com
- Biblioteca de assets de Godot (la licencia se ve en cada ficha): https://godotengine.org/asset-library/asset
