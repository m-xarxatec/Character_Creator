# Fase 17 — VRM 1.0 (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo **fuerte** escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: Fase 9 (expresiones y huesos de ojos), Fase 11 (huesos de muelle). Decisión D24 (código propio o dependencia).
> Todo lo que digo de la especificación VRM en esta ficha es de memoria: **NO VERIFICADO**. El paso 17.1 existe para comprobarlo.

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
