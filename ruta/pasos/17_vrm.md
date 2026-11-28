# Fase 17 — VRM 1.0 (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo **fuerte** escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: Fase 9 (expresiones y huesos de ojos), Fase 11 (huesos de muelle). Decisión D24 (código propio o dependencia).
> Las notas de diseño se escribieron de memoria; lo comprobado en el paso 17.1 está en **§ 17.1 — Resultados** (al final) y manda sobre ellas.

**Objetivo de la fase:** exportar el personaje como `.vrm` (VRM 1.0), que abren programas de avatares.

**Hecho cuando:** el `.vrm` exportado pasa un validador de VRM y se abre, con expresiones y pelo con movimiento, en al menos un programa libre que lea VRM 1.0 (por ejemplo Blender con un importador de VRM, o Godot con un addon lector).

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| 17.1 | Estudio de la especificación y de licencias; elegir entre código propio y dependencia (D24) | S | Bajo | fuerte | red (permiso) |
| 17.2 | Humanoide y metadatos (`VRMC_vrm`: huesos, autor, permisos de uso) | M | Medio | fuerte | 17.1, 9.3 |
| 17.3 | Expresiones y mirada | M | Medio | medio | 17.2, 9.7 |
| 17.4 | Huesos de muelle (`VRMC_springBone`) | M | Medio: parámetros distintos de los de Godot | fuerte | 17.2, 11.3 |
| 17.5 | Material (`VRMC_materials_mtoon`) | M | Alto: nuestro toon no es MToon | medio | 17.2 |

## Notas de diseño que no deben perderse

- **Un `.vrm` es un `.glb`** con extensiones JSON añadidas. No hace falta un exportador nuevo: se añade el bloque de extensiones al JSON que ya escribe `GLTFDocument`. En Godot se hace con una clase `GLTFDocumentExtension` registrada antes de exportar (existe en Godot 4; funciones exactas para escribir extensiones en la raíz: comprobar en la ficha detallada).
- **Pose de reposo:** VRM 1.0 exige pose T y personaje mirando a +Z: coincide con las reglas del proyecto. VRM 0.x mira a −Z: **no** se soporta 0.x.
- **Huesos obligatorios** del humanoide de VRM: la lista se parece al perfil de Godot pero no es idéntica (nombres en *camelCase*: `leftUpperArm`). Tabla de correspondencia en datos, con prueba: todo hueso obligatorio de VRM tiene pareja.
- **Metadatos y permisos:** VRM obliga a declarar autor y permisos (uso comercial, modificación, redistribución). Son decisiones **del usuario**: el diálogo de exportación los pide, con valores por defecto prudentes. No se rellenan en silencio.
- **Material:** MToon es otro modelo de sombreado. Se exporta una **aproximación** (color base, color de sombra, grosor y color de contorno). Avisar al usuario de que el aspecto fiel es el de Godot con el `.tres`.
- **Licencias:** la especificación VRM es abierta (documentos del VRM Consortium). **No se usa ningún archivo, malla ni código de VRoid Studio.** Si se elige la dependencia `godot-vrm` (D24), comprobar licencia y estado de mantenimiento, y fila en `CREDITOS.md`.
- **Prueba sin programas externos:** leer el `.vrm` escrito como JSON y comprobar la estructura contra una lista escrita desde la especificación (huesos obligatorios presentes, versión de la extensión, índices de nodos válidos). El validador externo y el programa lector son la prueba final, con el responsable.
- **Solo PC:** `Platform.can("exportar_vrm")` es `false` en Android.

## Juicio visual

17.5: comparar el `.vrm` abierto en el programa lector con el personaje en el editor. El responsable decide si la aproximación vale.

## Si te atascas

Si un requisito de la especificación choca con una regla del `.glb` del proyecto (por ejemplo, formas dentro del archivo): **para**. Puede que el `.vrm` necesite su propio camino de exportación; es decisión de arquitectura.

## 17.1 — Resultados (comprobado el 2026-11-28, solo lectura en la red)

Base de las URL: `S` = `https://github.com/vrm-c/vrm-specification/blob/master/specification`, `G` = `https://github.com/V-Sekai/godot-vrm`.

**Versión y extensiones**
- VRM 1.0: `VRMC_vrm` con `specVersion = "1.0"`, estado «Complete» — `S/VRMC_vrm-1.0/README.md`.
- Carpetas de la especificación: `0.0`, `VRMC_vrm-1.0`, `VRMC_springBone-1.0`, `VRMC_springBone_extended_collider-1.0`, `VRMC_springBone_limit-1.0`, `VRMC_materials_mtoon-1.0`, `VRMC_materials_hdr_emissiveMultiplier-1.0`, `VRMC_node_constraint-1.0`, `VRMC_vrm_animation-1.0` — `https://github.com/vrm-c/vrm-specification/tree/master/specification`.
- `VRMC_springBone` y `VRMC_materials_mtoon`: `specVersion = "1.0"`, «Complete» — `S/VRMC_springBone-1.0/README.md`, `S/VRMC_materials_mtoon-1.0/README.md`.
- En `VRMC_vrm` son obligatorios `humanoid` y `meta`; `expressions`, `lookAt` y `firstPerson` son opcionales (si falta `firstPerson`, todas las mallas cuentan como `auto`) — `S/VRMC_vrm-1.0/README.md`, `S/VRMC_vrm-1.0/firstPerson.md`.
- Unidades: metros, como glTF — `S/VRMC_vrm-1.0/README.md`.

**Ejes y pose** (`S/VRMC_vrm-1.0/tpose.md`)
- Mirando a **+Z**, simétrico en X; puntas de los pies hacia +Z; suelo (planta) en **Y = 0**. Coincide con nuestras reglas (Y arriba, +Z).
- Pose T: brazos a lo largo de X, paralelos al suelo; hombros relajados; **palmas hacia −Y**; dedos y pulgar con reglas propias (1.7, 1.8).
- Todos los nodos con **escala uniforme y positiva** (también en `S/VRMC_vrm-1.0/humanoid.md`).
- VRM 0.x mira a −Z y 1.0 a +Z — `https://vrm.dev/en/vrm1/changed/`. Se confirma: no se soporta 0.x.

**Meta** (`S/VRMC_vrm-1.0/meta.md`)
- Obligatorios: `name`, `authors` (al menos uno no vacío) y `licenseUrl` = `https://vrm.dev/licenses/1.0/` (Licencia Pública VRM 1.0, texto en `https://vrm.dev/en/licenses/1.0/`).
- Opcionales con valor por defecto (el más prudente): `avatarPermission` = `onlyAuthor`, `commercialUsage` = `personalNonProfit`, `creditNotation` = `required`, `allowRedistribution` = false, `modification` = `prohibited`, `allowExcessivelyViolentUsage`, `allowExcessivelySexualUsage`, `allowPoliticalOrReligiousUsage`, `allowAntisocialOrHateUsage` = false. Otros: `version`, `copyrightInformation`, `contactInformation`, `references`, `thirdPartyLicenses`, `thumbnailImage`, `otherLicenseUrl`.

**Humanoide** (`S/VRMC_vrm-1.0/humanoid.md`)
- `humanoid.humanBones.<nombre>.node`; cada hueso, una vez.
- Obligatorios (15): `hips`, `spine`, `head`, `leftUpperArm`, `leftLowerArm`, `leftHand`, `rightUpperArm`, `rightLowerArm`, `rightHand`, `leftUpperLeg`, `leftLowerLeg`, `leftFoot`, `rightUpperLeg`, `rightLowerLeg`, `rightFoot`. Opcionales: `chest`, `upperChest`, `neck`, `leftEye`, `rightEye`, `jaw`, hombros, `leftToes`/`rightToes` y los 30 de dedos.
- Correspondencia con nuestros 56: los nombres de VRM son los de `SkeletonProfileHumanoid` con la **primera letra en minúscula** (`LeftThumbMetacarpal` → `leftThumbMetacarpal`). Los 55 menos `Root` tienen pareja; `Root` no es hueso VRM. Los 15 obligatorios están entre los nuestros.
- Padres que exige VRM: `upperChest` solo si hay `chest`; `neck` y los hombros cuelgan de `upperChest`; cada proximal (y el metacarpo del pulgar) de la mano. **NO VERIFICADO** que nuestro `.glb` cumpla todos los padres: prueba en 17.2.

**Expresiones y mirada** (`S/VRMC_vrm-1.0/expressions.md`, `S/VRMC_vrm-1.0/lookAt.md`)
- 18 preajustes, **todos opcionales**: `happy`, `angry`, `sad`, `relaxed`, `surprised`, `aa`, `ih`, `ou`, `ee`, `oh`, `blink`, `blinkLeft`, `blinkRight`, `lookUp`, `lookDown`, `lookLeft`, `lookRight`, `neutral`. Los nuestros existen todos con el mismo nombre; nuestro `blink` también.
- Cada expresión une formas con `morphTargetBinds` (`node` con malla, `index` de la forma, `weight` 0–1), y supone que todas las primitivas de la malla tienen las mismas formas. También `materialColorBinds`, `textureTransformBinds`, `isBinary`, `overrideBlink/LookAt/Mouth`.
- Qué atributos puede llevar una forma (solo posiciones, normales): **NO VERIFICADO** (la página no lo dice).
- `lookAt.type`: `bone` (gira `leftEye`/`rightEye`) o `expression`; `offsetFromHeadBone` y 4 `rangeMap`. Que `bone` exija los huesos de ojo no lo dice explícitamente: **NO VERIFICADO**.

**springBone frente a nuestro pelo** (`S/VRMC_springBone-1.0/README.md`)
- `colliders` (esfera o cápsula: `offset`, `radius`, `tail`), `colliderGroups`, `springs` (`joints`, `colliderGroups`, `center`). Por articulación: `hitRadius`, `stiffness`, `gravityPower`, `gravityDir`, `dragForce` (0–1). Sin valores por defecto en la página.
- Cadena: cada articulación es antepasada de la siguiente; sin repetidos; ramas sin definir. Algoritmo de referencia (no normativo): Verlet.
- Nuestro `hair_physics.gd` ya usa los mismos conceptos por articulación (rigidez, freno, gravedad y su dirección, radio) y colisiones de esfera y cápsula: la traducción es directa en forma. Que los mismos números den el mismo movimiento en Godot y en VRM: **NO VERIFICADO** (riesgo de 17.4).

**MToon frente a nuestro toon** (`S/VRMC_materials_mtoon-1.0/README.md`)
- Va sobre `pbrMetallicRoughness` (color base). Dos tonos: `lerp(shadeColor, baseColor, rampa)` con la rampa de `dot(N, L)` + `shadingShiftFactor`, estrechada por `shadingToonyFactor` (0,9 por defecto). Contorno: `outlineWidthMode` (`none`/`worldCoordinates`/`screenCoordinates`), `outlineWidthFactor`, `outlineColorFactor`. Rim y matcap opcionales.
- Se parece a nuestro `toon_soft` (2 tonos, sombra desde el color, contorno teñido). No tiene banda cálida ni brillo de piel propios (como mucho, el rim).
- **«In MToon, vertex colors are ignored.»** Nuestra prenda base (`garment`) y la boca oscura van en color por vértice: en un lector MToon se perderían, salvo que se horneen en la textura de color base. Decisión de 17.5.

**Licencias**
- Licencia de la propia especificación: **NO VERIFICADO**. El repositorio no tiene archivo `LICENSE` y la API de GitHub da `"license": null` (`https://api.github.com/repos/vrm-c/vrm-specification`); ni el esquema ni los README de las extensiones la dicen. Implementarla desde su texto no copia código; aun así, conviene preguntarlo al VRM Consortium antes de publicar.
- La Licencia Pública VRM 1.0 es para **los modelos** (`.vrm`), no para la especificación — `https://vrm.dev/en/licenses/1.0/`.

**godot-vrm (V-Sekai)** — para D24
- Licencia **MIT** (copyright V-Sekai, VRM Consortium, Masataka SUMI por MToon, Godot) — `G/blob/master/LICENSE`. Los modelos de muestra tienen otras licencias (Alicia Solid de DWANGO; Godette CC-BY 3.0): no CC0 — `G/blob/master/vrm_samples/LICENSE_SAMPLES.txt`.
- Lee VRM 0.0 y 1.0; **exporta VRM 1.0** (`.vrm`) — `G` (README). Qué partes exporta enteras (meta, expresiones, springBone): **NO VERIFICADO**.
- Godot: el README dice «4.0 stable or newer»; la Asset Library, 4.1 (v2.1.0, 2024-11-10) — `https://godotengine.org/asset-library/asset/2031`. Con **4.7** se rompía (errores de análisis, issue abierto `G/issues/149`); su mantenedor dice (2026-07-08) que está arreglado **solo en `master`**, sin publicar en la tienda.
- Mantenimiento: **sin releases** (`G/releases`); último commit el 2026-07-08 (`G/commits/master`); issue abierto sin respuesta sobre MToon 1.0 mal convertido en Godot 4.7.2 (`G/issues/156`, 2026-10-27). Se instala como dos addons (`addons/vrm` y `addons/Godot-MToon-Shader`).

**Recomendación para D24 (decide el responsable):** **a) código propio**, porque solo hay que añadir un bloque JSON al `.glb` que ya escribimos, y `godot-vrm` (aunque MIT) no tiene releases, se rompió con Godot 4.7 y obligaría al núcleo a depender de dos addons. Sí sirve como **lector externo** para la prueba final del responsable, fuera del proyecto.

**Avisos para los pasos siguientes**
- «Hecho cuando» pide expresiones, pero `blender/expresiones.json` está vacío desde el 2026-11-25 (9.7 y 9.8 cerrados sin expresiones). Como son opcionales, el `.vrm` es válido sin ellas; decidir si la fase espera a rehacerlas.
- 17.2: comprobar palmas hacia −Y en nuestra pose T y escala uniforme positiva en todos los nodos.
