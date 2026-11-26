# Plan de assets (extra, fuera del proyecto principal)

Assets 3D propios para ir llenando el programa. **No se toca el repo principal**: cada asset vive en
`assets_3d_codex/claude_<asset>/` y se prueba instalando su pack en
`%APPDATA%/Godot/app_userdata/GameMolde/packs/<id_pack>/` (el `user://packs` del programa).

## Receta para cada asset

1. **Plano**: hoja de referencia en `planos/` (medidas, vistas, partes, colores).
2. **Generador** `generar_<asset>.py` (Python + numpy, sin Blender): construye la malla con código a partir
   del cuerpo real (`godot/datos/humana/cuerpo.glb`) y usa el esqueleto de `godot/packs/base/tights.glb`.
   El lector de `.glb` es `claude_gorra/glb.py`.
3. **Encaje**: medir el cuerpo (y los peinados o prendas con los que convive) y dejar la holgura justa.
4. **Seguir al cuerpo**: pesos al hueso que toque (rígido) o copiados de la piel (flexible), y las formas
   del cuerpo transferidas desde la piel cercana (solo las que mueven esa zona).
5. **Siempre una sola pieza, con zonas de color** (decidido por el responsable): todo el asset va en un solo `.glb`,
   y cada parte que deba poder tener otro color (visor, logos, hebillas, ribetes…) se marca como zona en `COLOR_0`
   (r, g, b, o sus mezclas), como el casco felino y el qipao. Hoy el shader lo pinta todo de un color; al integrarlo
   (G), cada zona se podrá cambiar de color sin rehacer el asset. Nada de piezas aparte para los detalles.
6. **Ranura**: `accesorio` si debe convivir con todo; la de ropa o pelo si debe sustituir a otra.
7. **Licencia**: `propia`; nada de marcas registradas (por eso GM y no NY).
8. **Prueba**: instalar el pack, abrir el programa y juzgarlo a mano (el responsable). Capturas solo si se piden
   (`claude_gorra/capturar_gorra.gd`).

## Assets

| Asset | Estado | Notas |
| --- | --- | --- |
| Gorra plana (holgada + GM) | Aprobada | Para cualquier peinado; deja 1,8–2,8 cm de hueco |
| Gorra plana ajustada (+ GM) | Pendiente de probar | Sin pelo o rapado; hueco de 4–6 mm |
| Falda corta plisada | Aprobada | `claude_falda/`; talle bajo, 25 cm, 16 pliegues, cintura pegada a la piel; en Accesorios (en `ropa_piernas` quitaría los shorts). Adaptable al cuerpo (76 formas, 4,9 MB); aún 100 % `Hips` (pesos de piernas en C) |
| Sudadera oversize con capucha | Aprobada | `claude_sudadera/`; ranura `ropa_exterior` (no sustituye nada); piel copiada e hinchada (pesos y formas del cuerpo), cae recta desde el pecho, bajo a ~0,95 m, mangas hasta los nudillos, capucha bajada, bolsillo; 268 formas dispersas, 6,8 MB. Conocido: 58 caras plegadas en las axilas |
| Casco de astronauta | Aprobado | `claude_casco/`; 4 piezas: carcasa (ranura `pelo`: quita el peinado), metal (anillo, orejeras, marco, cierre, remaches), acolchado y visor espejo (sin él, casco abierto). Burbuja de 14,3 cm de radio medida sobre la cabeza (5 mm de aire + 10 mm de acolchado); anillo con 6–8 mm de holgura a cuello y hombros. 32 formas afines (se estira con la caja de la cabeza; la base sigue a los hombros), 8,3 MB |
| Orejas de gato (sin diadema) | Aprobadas | `claude_orejas/`; el plano traía diadema, pero el responsable la quitó. 2 piezas: orejas (negro) e interior (rosa). Nacen del cráneo (base hundida 1 cm), 6,2 cm de alto: salen de la piel o entre el pelo; con el afro (3 cm) solo asoman las puntas. Rígidas, cada una sigue a su base (15 formas), 1,1 MB |
| Tentáculos de la espalda | Aprobados | `claude_tentaculos/`; 6 (3 por lado: arriba y en medio grandes, 58–62 cm; abajo pequeño, 36 cm), 1 pieza con las ventosas en relieve. Nacen juntos en el centro de la espalda, bajo los omóplatos (raíces de y=1,10 a 1,25, a distinta altura en cada lado; hundidas 2 cm), salen hacia los lados (8–13° hacia atrás; hasta 22 cm de la espalda). **Sin simetría** (no son alas): cada uno con su dirección, ondas, punta enroscada y vaivén en profundidad (lista `TENTACULOS`). En reposo, a 4,2 cm de los brazos. 100 % `UpperChest`; cada uno rígido con su raíz (42 formas), 10,9 MB. Tamaño fijo: ver H |
| Vestido qipao | Aprobado | `claude_vestido/`; corto y ajustado (bajo en y=0,73, a 4 cm de la entrepierna): cuello mao, sin mangas, rendija en diagonal con 4 alamares y perlas, ribetes, aberturas laterales en V hasta la cadera (y=0,93; ~5 cm abiertas abajo), borde de pelo y borlas. **Una sola pieza con todo** (ranura `ropa_torso`, `cubre: ["ropa_piernas"]`); hoy de un color (rojo), con las zonas marcadas en `COLOR_0` para G. Hecho envolviendo el cuerpo rodaja a rodaja (envolvente convexa sin brazos, +4 mm; falda +6 mm), con caída bajo el pecho y los glúteos; recortes sobre la rejilla. Pesos y formas de la piel cercana (centro de la falda repartido con `Hips`). 15,8 MB |
| Coraza medieval de acero | Aprobada | `claude_coraza/`; peto y espaldar en una, cresta en el peto, cuello en V, bajo en pico (y=0,935 delante, 0,985 en el costado), reborde en los bordes, costuras en los costados, tirantes de cuero con hebilla y 2 correas con hebilla por costado. **Una sola pieza** (ranura `ropa_exterior`: sustituye a la sudadera), zonas en `COLOR_0`. Envolvente del tronco (+1,5 cm, lisa: cubre el pecho por encima); sisas automáticas a ≥ 2,5 cm del brazo en reposo. Formas: la envolvente recalculada con cada forma (las del pecho, sobre el cuerpo femenino), nunca por dentro de la piel; hueco mínimo ≥ 5,5 mm en 5 cuerpos de prueba. Pesos de la piel, solo tronco y hombros. 137 formas, 11,5 MB |
| Orejas de conejo (sin diadema) | Aprobadas | `claude_conejo/`; reutiliza el generador de las de gato (solo cambia la forma). 2 piezas: orejas (blanco) e interior (rosa). 17 cm, estrechas en la base (2,4 cm), 4,8 cm de ancho a media altura, punta redonda y 2,2 cm hacia delante. Nacen del cráneo (base hundida 1,2 cm), casi verticales. Rígidas con `Head` (13 formas), 1,8 MB. En Linux se genera con el Python de Blender (trae numpy) |
| Sombrero de bruja (grande, estilo RPG) | Aprobado | `claude_sombrero/`; 3 piezas: sombrero (copa + ala), cinta y hebilla. Ranura `accesorio`: va encima del peinado (copa medida sobre la cabeza + 2,4 cm de holgura en la banda y 3,5 cm arriba; hueco mínimo medido 2,0 cm). Banda a y=1,583 (2,5 cm sobre la oreja, deja ver los ojos) e inclinado 8° hacia atrás. Copa de 55 cm por su eje que cede por el peso: recta alrededor de la cabeza, luego 4 pliegues que tuercen el eje en zigzag (14–24°, la tela recogida abulta bajo cada uno, en diagonal) y la punta caída 120° hacia atrás; arrugas pequeñas encima. Alto 45,5 cm; ala de 56 cm, ondulada y caída 3 cm. 100 % `Head`; formas afines por ejes de la caja de la cabeza, como el casco (30 formas), 9,5 MB |
| Traje rosa: mono | Aprobado | `claude_traje/`; base: la «Malla de cuerpo completo» (`tights.glb`, CC0), recortada por planos: sin mangas (sisa en \|x\| = 0,168), cuello alto (y=1,45) y bajo en el tobillo (y=0,095); a 3 mm de la piel cerca de los bordes. Cremallera delante (hasta y=1,00), costuras en relieve (dos curvas delante, una detrás) y 3 franjas en el muslo izquierdo y 3 en la pantorrilla derecha. **Una sola pieza** (ranura `ropa_torso`, `cubre: ["ropa_piernas"]`), zonas en `COLOR_0` (r = 1 franjas, g = 1 cremallera). Pesos y formas: los de la malla (interpolados en los cortes); los detalles, del mono. 191 formas, 6,3 MB |
| Traje rosa: chaqueta corta con capucha | Aprobada | `claude_traje/generar_chaqueta.py` (la llama `generar_traje.py`; usa las herramientas de la sudadera). Ranura `ropa_exterior` (sustituye a la sudadera). Piel copiada e hinchada (2 cm; antebrazo abombado hasta 4,2 cm); bajo detrás a y=1,17 y delante en arco hasta y=1,27; mangas que se recogen en un puño de 4 cm hasta la muñeca; capucha bajada que cae 10 cm. Logos en relieve: gato delante, píxeles en el pecho izquierdo, doble flecha detrás y estrella en cada manga. Zonas en `COLOR_0`: r = 1 puños, g = 1 logos. 218 formas, 4,3 MB |
| Kigurumi de conejito | Aprobado | `claude_kigurumi/`; usa las herramientas de la sudadera y la chaqueta. **Una sola prenda** con la capucha puesta: ranura `ropa_exterior` (debajo se ve la ropa ajustada del personaje), `cubre: ["pelo"]` (quita el peinado). Piel copiada e hinchada: tronco +3,5 cm, mangas abullonadas con puño hasta la muñeca, perneras bombachas (+4 cm en el muslo, +6,5 cm en la pantorrilla) recogidas en un puño de 5 cm en el tobillo; las perneras no pasan de x = ±6 mm (no se cruzan). Cremallera abierta en V del cuello a la pelvis (y=0,83, a 5 cm de la entrepierna; ±11 cm arriba), dos cintas y cursor abajo; detrás, cerrado. 2 franjas en cada pierna. Zonas en `COLOR_0`: r = 1 puños (oscuros), g = 1 franjas, r = g = 1 cremallera. Capucha (`generar_capucha.py`): nace del borde del cuello del pijama (esquinas de la V y detrás) y envuelve la cabeza sobre una envolvente redonda del cráneo (+3,5 cm; detrás, más); abierta: no ciñe el cuello; por los lados la abertura sigue a la cremallera y arriba se cierra en arco sobre la frente, a la altura de las cejas (y=1,60). Sin orejas (las quitó el responsable). Cordones desde el borde de la capucha, junto al cuello, hasta un pompón. Zonas en `COLOR_0` también: b = 1 pompones. 273 formas, 10,6 MB. Movimiento: ver J y K |
| Leotardo negro | Aprobado (provisional: falta L) | `claude_leotardo/`; como el mono rosa: la `tights.glb` (CC0) recortada y luego «tela tensa» (alisada sin meterse en la piel; a 2,5 mm). Cuello redondo alto (1 cm bajo la base del cuello: sobre y = 1,39 − 0,3·z y dentro de una elipse de ±8,5 cm; tirante hasta la sisa en \|x\| = 0,15). Piernas de corte alto tipo bikini: delante sube por la ingle sin pasar a los muslos, detrás en curva; tira de la entrepierna medida desde el centro (\|x\| + lo que baja por el muslo < 3 cm): continua y cubre el surco. Ribete plano de 8 mm en cada borde. **Una sola pieza** (ranura `ropa_torso`, `cubre: ["ropa_piernas"]`), de un color. Pesos y formas de la malla; con cada forma, nunca por dentro de la piel. 184 formas, 12,4 MB |
| Bikini negro (liso) | Aprobado (falta M, en el núcleo) | `claude_bikini/`; del plano solo la forma (sin flores, borlas, cuentas ni anillas). La tela es **la piel del cuerpo recortada** y separada 2,5 mm: copas triangulares, banda de 1,2 cm bajo el pecho y braguita baja (cintura y=0,905 delante y 0,925 detrás). Delante en **V** (media anchura 1,6 cm en la entrepierna) y sin pasar al muslo (corta también donde la piel pesa más de 0,4 de pierna); detrás **tanga**: triángulo de 15 cm bajo la cintura que acaba en hilo de 1,2 cm desde y=0,845. **Tira halter plana**: cinta de 1,2 cm sobre la piel, de dentro de cada copa alrededor del cuello, con lazo en la nuca; tira de 1 cm en cada cadera, también cinta sobre la piel, con su lazo. Sin ribete: en los bordes la tela baja hasta la piel en 6 mm (el contorno no parpadea). Cada vértice sigue a su triángulo de piel (pesos y formas). Hueco mínimo con cada forma 1,5 mm lejos de los bordes. **Una sola pieza** (ranura `ropa_torso`, `cubre: ["ropa_piernas"]`), negra; zonas en `COLOR_0` (r = 1 lazos). 237 formas, 11,3 MB |
| Casco felino neón | Pendiente de probar | `claude_casco_felino/`; casco integral de moto con orejas de gato. **Una sola pieza** (ranura `pelo`: quita el peinado) con las zonas en `COLOR_0` para cuando el núcleo pinte un color por zona (G): carcasa (0,0,0), visor r = 1, neón g = 1, galones b = 1; hoy, de un color. Carcasa: el elipsoide que contiene la cabeza + 2,2 cm (6 mm de grosor), cerrada delante (el visor es opaco, en relieve encima) y abierta abajo desde 47° bajo el centro de la cabeza; hueco a la piel por dentro 16 mm (13 mm con la peor forma). Orejas de 8,8 cm (las de `claude_orejas`, más grandes) con el interior de neón; logo del gato en cada lado; barra de luz detrás; franjas de neón abajo; dos galones «<» en cada lado; rejillas en la mentonera. 100 % `Head`, formas afines como el casco de astronauta (26 formas), 8,6 MB |
| Máscara de gas | Aprobada (quedan arreglos menores, los dará el responsable) | `claude_mascara/`; **una sola pieza** (ranura `accesorio`: convive con el peinado), zonas en `COLOR_0`: goma (0,0,0), cristales r = 1, filtro y válvulas g = 1, correas, placa y hebillas b = 1. Máscara: la piel de la cara que se ve de frente (sin el interior de boca y ojos), de la frente (y=1,63) a la barbilla, separada 6 mm y alisada (pasa sobre nariz y ojos); el borde baja a la piel (sello). Lentes de 4 cm con aro, filtro de 6,6 cm en la boca (mirando 25° abajo) con radios en la tapa, válvula con rejilla en cada mejilla: rígidas, siguen a su punto de la cara. Correas planas de 2 cm **pegadas al cráneo** (arriba, sobre las orejas y bajo ellas) hasta una placa detrás, con hebillas: hoy el pelo pasa por encima (ver O). Pesos y formas de la piel; cara de fuera ≥ 1,8 mm sobre la piel con cada forma. 82 formas, 10,7 MB |
| Traje espacial EVA (sin casco) | Aprobado | `claude_eva/`; como el kigurumi: **la piel entera** (salvo cabeza y cuello) copiada e hinchada, con pesos y formas por índice (sigue a cualquier edición del cuerpo), guantes (2 mm, siguen a cada dedo) y botas (1 cm, dedos alisados) en la misma pieza. Holgura: tronco 2,4 cm, brazos 2 cm, muslo 2,4 → pantorrilla 2,8 cm. **Una sola pieza** (ranura `ropa_exterior`, `cubre: ["ropa_torso", "ropa_piernas", "ropa_pies"]`), sin mochila. Cuello: anillo medido sobre el del casco de astronauta (lo alto queda dentro del anillo del casco; asoma el reborde). Relieve: anillos de las muñecas, caja de mandos (rígida) con dos tubos, cinturón con hebilla, hombreras, rodilleras, bolsillos con solapa, aros acolchados en brazos y piernas, caña de las botas. Zonas en `COLOR_0`: r = 1 gris (guantes, suelas, almohadillas, cinturón, solapas, caña), g = 1 metal (anillos, hebilla), b = 1 caja y tubos. 272 formas, 14,7 MB. En Linux se genera con `~/.venvs/gamemolde_assets/bin/python` (numpy + scipy) |
| Botas blindadas medievales | Aprobadas | `claude_botas_medievales/`; el par en **una sola pieza**, ranura `ropa_pies` (la primera; no quita nada: van con shorts, mallas y trajes ceñidos, ver P). Cuero: la piel de pantorrilla y pie copiada e hinchada (pesos y formas por índice), con grosor; caña hasta 4 cm bajo la rodilla a 9 mm de la piel, con arrugas abajo; pie a 6 mm, puntera 1,5 cm más larga, dedos alisados; suela que sobresale 4 mm, con tacón (la suela baja 4 mm bajo el suelo). Acero rígido con su hueso (formas de la piel de debajo): espinillera con cresta y punta, acaba bajo la rodilla (decidido por el responsable), con remaches; empeine de 3 láminas (`Foot` y `Toes`). Correas con hebilla: dos arriba, media caña, tobillo y bajo el pie. Zonas en `COLOR_0`: r = 1 acero, g = 1 correas, r = g = 1 hebillas y remaches, b = 1 suela. 27 formas, 7 MB |
| Guanteletes de garras de dragón | Aprobados | `claude_guanteletes/`; la piel de la mano y del final del antebrazo copiada e hinchada (pesos y formas por índice: crece con las manos), con grosor. **Más grandes que la mano**: dorso y palma 8 mm, dedos 6 mm (nunca más de 0,45 × el hueco con el dedo de al lado), puño acampanado de 2 a 3,2 cm (tapa el anillo de muñeca del EVA); surco en cada nudillo. `SIZE` escala todo lo grande a la vez. Garras rígidas con la última falange (curvadas hacia la palma; la del pulgar, hacia el índice), escudo con cresta y chevrón en el dorso (rígidos con la mano), correas en X y muñequera con bloque. Ranura `accesorio` (va encima de cualquier ropa). Zonas en `COLOR_0`: r = 1 correas y escudo, g = 1 garras. 56 formas, 5,4 MB |
| (siguiente) | — | — |

## Pendiente: se hace en el propio asset (sin tocar el núcleo)

### C. Falda: pesos de piernas para que sea funcional

Hoy va rígida con la cadera (ya se adapta al cuerpo: hecho el 2026-11-23).
- **Pesos**: arriba 100 % `Hips`; hacia el bajo, mezcla gradual con `LeftUpperLeg` / `RightUpperLeg` según el
  lado, y los pliegues del centro (delante y detrás) repartidos entre los dos muslos, para que se mueva al
  andar sin partirse entre las piernas. Máximo 4 influencias y suma 1.
- Riesgo que queda: con la pierna muy levantada («Atacar», sentarse) el muslo atravesará la tela; sin
  físicas no se evita del todo.
- Si se pasa a la ranura `ropa_piernas`, decidir antes qué hacer con los shorts (lo decide el responsable).

### J. Kigurumi: pesos para que se mueva sin rasgarse (pedido por el responsable; no hecho)

Hoy cada vértice lleva los pesos y las formas del vértice de piel del que sale. Con 3,5–6,5 cm de holgura eso falla
al animar: la tela lejos de la piel gira como si estuviera pegada al hueso. Riesgos y arreglo, todo en
`generar_kigurumi.py`:
1. **Entrepierna (se rasga al abrir las piernas)**: como en el qipao y la falda (C), el centro (|x| < 5 cm,
   y = 0,75–0,92) se reparte entre `Hips` y los dos `UpperLeg` (más `Hips` cuanto más al centro). Así, al abrir las
   piernas, la tela se estira en vez de partirse.
2. **Axilas e ingles (picos y pliegues)**: difuminar los pesos sobre la malla (media con los vecinos, 10–20 pasadas,
   y después volver a 4 influencias que sumen 1) solo en las zonas de la articulación: axila (`UpperChest`,
   `Shoulder`, `UpperArm`) e ingle (`Hips`, `UpperLeg`). Lo demás no se toca, para que la manga y la pernera no pierdan
   su forma.
3. **Codo y rodilla (la parte de dentro se mete en el brazo o la pierna al doblar)**: en el antebrazo y la
   pantorrilla, que pesen más `LowerArm` y `LowerLeg` (el abombado sigue al hueso de abajo) y la transición sea corta
   en el codo y la rodilla. Sin físicas no se evita del todo con el codo o la rodilla muy doblados: se acepta.
4. **Prueba**: una captura en las poses del programa (andar, «Atacar», sentado si la hay) y la medida por pose de
   cuántos vértices del kigurumi quedan dentro de la piel (como `check_shapes` del traje). Antes y después del
   cambio, para ver que mejora.

### L. Leotardo: delante más «bikini» (pedido por el responsable; no hecho; antes de integrarlo)

Delante la tela todavía se va hacia el muslo: el corte se hace en la vista de frente, (|x|, y), y la cara delantera
del muslo junto a la ingle (|x| = 0,04–0,10, y = 0,80–0,90) queda por encima de la línea, así que la tela pasa al muslo.
Arreglo en el asset: cortar por el **pliegue de la ingle del cuerpo**, no por una línea en la vista de frente. Por
ejemplo, quitar delante donde la piel más cercana pesa más de `UpperLeg` que de `Hips` (el pliegue sale solo y sigue
al cuerpo), o medir el pliegue en la piel y usarlo como línea. Detrás se queda como está (aprobado). Comprobar con
capturas de frente y de tres cuartos que delante solo cubre la ingle hasta la entrepierna.

### N. Pasar a una sola pieza con zonas de color (pedido por el responsable; no hecho)

Según la receta (paso 5), cada asset va en un solo `.glb` con sus partes como zonas en `COLOR_0`. Estos se hicieron con
piezas aparte y hay que fundirlas (en su generador; mismas formas y pesos, que ya son comunes):
- **Casco de astronauta**: carcasa (0,0,0), metal r = 1, acolchado g = 1, visor b = 1. Una sola pieza en la ranura
  `pelo`. Ya no harán falta los «conjuntos» de G: «sin visor» sería una segunda pieza sin la zona del visor.
- **Orejas de gato** y **orejas de conejo**: orejas (0,0,0), interior r = 1.
- **Sombrero de bruja**: sombrero (0,0,0), cinta r = 1, hebilla g = 1.
- **Gorra plana** (holgada y ajustada): gorra (0,0,0), GM r = 1.
Comprobar después que el pack carga y se ve igual (capturas solo para comprobar) y actualizar su línea en la tabla.

## Pendiente: requiere tocar el núcleo (proponer a quien lleva el proyecto)

### A. Cambiar sola de holgada a ajustada según el pelo

Hoy las piezas solo se excluyen por ranura o con `cubre`; no hay variantes condicionales.
Propuesta: un campo en `pack.json`, por ejemplo `"variante_sin_pelo": "gorra_plana_ajustada"`, y que
`body_view.gd` (`set_piece`) cambie a esa variante cuando no hay pieza en la ranura `pelo`, y vuelva a la
holgada al poner pelo. Pequeño, pero es código del programa.

### B. Esconder el pelo bajo la gorra (la solución buena)

Al ponerse la gorra, el pelo que queda por encima de la banda se aplasta hacia dentro, justo bajo la tela
(lo de abajo —melena, coleta, flequillo— no se toca), como hace una gorra de verdad.
- Ventajas: el pelo deja de atravesar la copa y la gorra puede ir siempre ajustada (sin flotar ni variantes;
  haría innecesario A).
- Debe hacerse en CPU (en la malla del pelo, en el espacio del hueso `Head`), no en el shader: el `.glb`
  exportado también tiene que salir con el pelo aplastado.
- Datos: la gorra declara su volumen interior (banda y copa) en `pack.json`; el pelo se ajusta al ponerla o
  quitarla y al cambiar formas.
- Peinados extremos (afro, moños altos): aun aplastados quedarían raros; para esos, ocultarlos
  (`cubre: ["pelo"]` solo en ese caso, o una lista de excepciones).

### D. `cubre` en piezas de la ranura `accesorio` (casco)

`body_view.gd` (`set_piece`) solo busca conflictos si la ranura **no** es `accesorio`, así que un accesorio con
`cubre: ["pelo"]` no quita el peinado (y ponerse un peinado después sí quita el accesorio). Por eso la carcasa del casco
va hoy en la ranura `pelo`. Arreglo: comprobar `cubre` también en los accesorios (lo de «varios a la vez» solo vale
entre accesorios). Después, la carcasa vuelve a `accesorio` con `cubre: ["pelo"]` (también serviría para B).

### E. Visor transparente (casco)

El shader de piezas es opaco y de un color. Para un cristal haría falta transparencia por pieza (p. ej.
`"opacidad": 0.35` en `pack.json`, con `ALPHA`, sin contorno y sin escribir profundidad) y que el `.glb` exportado la
lleve (`alphaMode: BLEND`). Entonces se añade una tercera variante del visor: cristal.

### F. Ajuste afín de piezas rígidas (peso del casco)

Las 32 formas del casco solo son una escala y un desplazamiento por ejes de la caja de la cabeza (cómo se calculan:
`shape_fields` y `deltas` en `generar_casco.py`). Si el núcleo hiciera ese cálculo al cambiar las formas (p. ej.
`"ajuste": "caja_cabeza"` en `pack.json`), el casco no necesitaría formas: de 8,3 MB a ~0,6 MB. Valdría para gafas, cascos
y otros accesorios rígidos.

### G. El casco como una sola pieza con varios colores (decidido por el responsable)

Forma final: **dos opciones, «con visor» y «sin visor»**, y las dos llevan siempre el metal y el acolchado. Hoy no se
puede: cada pieza pinta un solo color (`set_piece` pone el mismo en `skin_color` y `garment_color`), así que van como
4 piezas que se ponen una a una. Dos caminos en el núcleo:
- **Varios colores por pieza**: zonas por color de vértice (el shader ya mezcla dos con `COLOR`; harían falta tres o
  cuatro: carcasa, metal, acolchado, visor) y `"colores": ["carcasa", "metal", …]` en `pack.json`. El generador
  fundiría las piezas en una y pintaría cada zona.
- **Conjunto**: un campo de grupo en `pack.json` (p. ej. `"conjunto": ["casco_astronauta_metal", …]`) para poner y
  quitar las piezas a la vez; «con visor» y «sin visor» serían dos conjuntos.

### H. Tamaño ajustable de los tentáculos (pedido por el responsable; no hecho)

Un deslizador «Tamaño» propio de la pieza (p. ej. de ×0,5 a ×1,5). Cómo:
1. **Asset**: `generar_tentaculos.py` añade dos formas propias, `tentaculos_mas` y `tentaculos_menos`: cada vértice se
   aleja o se acerca a la raíz de su tentáculo (delta = (p − raíz) × 0,5). Las raíces ya las calcula (`root_point`).
   Así crecen desde la espalda, sin despegarse de ella.
2. **Núcleo**: hoy `ShapeWeights.apply` pone a 0 toda forma de la pieza que el cuerpo no tiene, así que una forma propia
   no se puede mover. Hace falta: (a) un campo en `pack.json`, p. ej. `"deslizadores": [{"id": "tamano", "nombre":
   "Tamaño", "decr": "tentaculos_menos", "incr": "tentaculos_mas", "neutro": 0.5}]`; (b) que `apply` respete esas
   formas y la interfaz muestre el deslizador cuando la pieza está puesta; (c) guardarlo en el proyecto (`project_file`)
   y que el `.glb` exportado salga con ese tamaño.
3. Otra vía sin formas: escalar cada tentáculo en CPU alrededor de su raíz (raíces en `pack.json`). Pesa menos, pero
   es más código en el núcleo.
- Las formas del cuerpo (que mueven la raíz) y el tamaño se suman: con tamaños extremos y cuerpos extremos, la raíz
  puede asomar unos milímetros (está hundida 2 cm).
- Peso: hoy 10,9 MB por las 42 formas densas; F (ajuste sin formas) también le valdría (cada tentáculo es rígido).

### I. Movimiento propio de los tentáculos (pedido por el responsable; no hecho)

Un ondular suave **siempre puesto y sin controles** (no se puede cambiar ni quitar desde la interfaz). La vía simple, sin
huesos nuevos, es mover los vértices en el shader:
1. **Asset**: `generar_tentaculos.py` guarda por vértice, en `TEXCOORD_1` (UV2), `s` (0 en la raíz, 1 en la punta;
   las ventosas, la `s` de su anillo) y la fase de su tentáculo (una distinta para cada uno, para que no se muevan a la
   vez). Lo demás no cambia.
2. **`pack.json`**: `"movimiento": "ondular"`, sin parámetros: amplitud y velocidad fijas en el núcleo, para que no se
   puedan tocar. Sugerencia de partida: desplazamiento = 0,03 m × s² × sin(1,2 · TIEMPO + fase + 4 · s), hacia arriba y un
   poco hacia atrás en el espacio del hueso; la raíz (s = 0) no se mueve, así que no se despega de la espalda.
3. **Núcleo**: si la pieza trae `movimiento`, `BodyMaterial` usa una variante del shader con ese desplazamiento en
   `vertex()`, y `outline.gdshader` hace lo mismo (si no, el contorno se queda quieto). Hay que comprobar en Godot 4.7
   en qué espacio llega `VERTEX` en una malla con piel, para que el desplazamiento siga al hueso al animar.
4. **Exportar**: un shader no viaja en el `.glb`; el exportado sale quieto (en la pose de reposo). Que se mueva también
   en el juego exige la otra vía: 4–6 huesos por tentáculo, colgados de `UpperChest`, y una animación en bucle dentro del
   `.glb`. Eso rompe la regla de los 53 huesos del `CLAUDE.md`, así que la decide el responsable.
- Pausa: si se quiere quieto en las capturas y miniaturas, que el núcleo lo pare ahí (no el usuario).

### K. Kigurumi: movimiento y peso de los pompones (pedido por el responsable; no hecho)

Las orejas se quitaron; quedan los cordones con pompones, hoy rígidos con el pecho. Para que cuelguen y se balanceen:
1. **Asset**: cada cordón con su cadena de huesos propios (3; el pompón, en el último), colgada de `Neck` o
   `UpperChest`. Nombres con `x_` (por ejemplo, `x_cordon_l_01`…`x_cordon_l_03`). Pesos rígidos por tramo y suaves
   entre tramos.
2. **`pack.json`**: el campo `fisica`, que ya existe en el formato (`ruta/ARQUITECTURA.md` §6), una cadena por cordón:
   `{"raiz", "fin", "rigidez", "arrastre", "gravedad", "radio"}`. De partida: rigidez baja y gravedad alta (péndulo).
3. **Núcleo**: hoy solo comprueba que `fisica` sea una lista. Falta crear, para cada cadena, un
   `SpringBoneSimulator3D` (apuntado en `IDEAS.md` para las coletas), con el pecho como colisionador (`radio`), para
   que los pompones no atraviesen el cuerpo. Primero hay que comprobar su API en Godot 4.7.
4. **Riesgos**: (a) huesos extra frente a la regla de los 53 huesos del `.glb` exportado (`CLAUDE.md`): lo decide el
   responsable (exportarlos aparte o fijar la pose); (b) sin colisionador, el pompón entra en el pecho: el `radio` es
   obligatorio; (c) en Android, coste de la simulación: limitarla a estas cadenas.
- Vía corta sin núcleo nuevo: un vaivén en el shader, como en I (no tiene peso real ni choca, pero no añade huesos).

### M. Contorno en los bordes de la ropa pegada a la piel (visto con el bikini; no hecho)

En los bordes de la tela pegada a la piel, el contorno negro (`outline.gdshader`, malla invertida empujada en pantalla)
se mezcla con la piel y, según el ángulo, el borde sale dentado o se cuela el color de la piel. En el asset ya se hizo
lo posible: la tela baja hasta la piel en los bordes, sin ribete. El arreglo es del shader del contorno (por ejemplo,
empujar también en profundidad o no dibujarlo donde la pieza toca la piel). De momento no molesta (el responsable).

### O. Máscara de gas: correas sobre el pelo (decidido por el responsable; no hecho)

Hoy las correas van pegadas al cráneo y el peinado las tapa (se aceptó así para que la máscara quede bonita y en una sola
pieza). La forma correcta: que las correas vayan **por encima del pelo**, aplastándolo bajo ellas, como la gorra con B
(el pelo bajo la correa se hunde hasta justo debajo de ella, en CPU y en el espacio de `Head`). Cuando B exista, las
correas pasan a ir a 2–3 mm del pelo aplastado. Necesita el núcleo.

### P. Botas con pantalón holgado: la pernera dentro de la bota (decidido por el responsable; no hecho)

Hoy las botas (`ropa_pies`) no quitan nada y un pantalón holgado (`ropa_piernas`) asoma a través de la caña. La forma correcta:
cuando se llevan los dos, la pernera se estrecha por debajo de la boca de la caña hasta quedar dentro de la bota (en CPU, como
la gorra con B: los vértices de la pernera bajo la boca se acercan a la piel hasta 2–3 mm menos que el cuero). Necesita el núcleo.

## Ficha de integración (para cuando se metan en el proyecto)

Hoy viven fuera del repo. Meterlos es un **paso del PLAN con su ficha en `ruta/pasos/`** (reglas 1, 9 y 10 del
`CLAUDE.md`); esta sección es el material para escribirla.

### Qué hay de cada asset

| Asset | Generador | Pack (id) | Piezas | Tipo / ranura | Peso | Hueso / pesos | Formas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gorra plana | `claude_gorra/generar_gorra.py` (`ajustada` para la variante) | `claude_gorras` | `gorra_plana`, `gorra_plana_gm`, `gorra_plana_ajustada`, `gorra_plana_ajustada_gm` | accesorio / accesorio | 4,0 + 0,35 MB cada variante | 100 % `Head` | 19 (cráneo) |
| Falda corta plisada | `claude_falda/generar_falda.py` | `claude_faldas` | `falda_plisada` | accesorio / accesorio | 4,9 MB | 100 % `Hips` | 76 (cintura, cadera, muslos) |
| Sudadera con capucha | `claude_sudadera/generar_sudadera.py` | `claude_sudaderas` | `sudadera_capucha` | ropa / ropa_exterior | 6,8 MB | copiados de la piel (4 influencias, suman 1) | 268, dispersas |
| Vestido qipao | `claude_vestido/generar_vestido.py` (capturas: `capturar_vestido.gd`) | `claude_vestidos` | `vestido_qipao` | ropa / ropa_torso (cubre ropa_piernas) | 15,8 MB | de la piel (4 influencias, suman 1) | 204, dispersas |
| Coraza de acero | `claude_coraza/generar_coraza.py` (capturas: `capturar_coraza.gd`) | `claude_corazas` | `coraza_acero` | ropa / ropa_exterior | 11,5 MB | de la piel, solo `Hips`, `Spine`, `Chest`, `UpperChest` y hombros (4 influencias, suman 1) | 137 (envolvente por forma; densas las macro) |
| Tentáculos de la espalda | `claude_tentaculos/generar_tentaculos.py` (capturas: `capturar_tentaculos.gd`) | `claude_tentaculos` | `tentaculos_espalda` | accesorio / accesorio | 10,9 MB | 100 % `UpperChest` | 42 (cada tentáculo, rígido con su raíz) |
| Orejas de gato | `claude_orejas/generar_orejas.py` (capturas: `capturar_orejas.gd`) | `claude_orejas` | `orejas_gato`, `orejas_gato_interior` | accesorio / accesorio | 0,64 + 0,48 MB | 100 % `Head` | 15 (cada oreja, rígida con su base) |
| Casco de astronauta | `claude_casco/generar_casco.py` (capturas: `capturar_casco.gd`) | `claude_cascos` | `casco_astronauta` (pelo), `_metal`, `_acolchado`, `_visor` (accesorio) | accesorio | 3,8 + 2,0 + 1,6 + 0,9 MB | 100 % `Head` | 32, afines (densas) |

Todos: licencia `propia`, autor «GameMolde», color plano (un color por pieza), mismo esqueleto que
`godot/packs/base/tights.glb`, generados con Python + numpy (+ scipy la sudadera), sin Blender. Se regeneran
con `python generar_<asset>.py` desde su carpeta.

### Pasos para integrarlos

1. **Copiar** cada `packs/<id>/` a `godot/packs/<id>/` (nombres en minúsculas). Renombrar los ids
   `claude_*` si se quiere (p. ej. `gorras`, `faldas`, `sudaderas`) y regenerar `pack.json` (el `sha256` cambia
   si cambia el `.glb`).
2. **`.import`**: cada `.glb` con su `<archivo>.glb.import` con `[remap]` / `importer="keep"` (como los demás
   packs), para que viaje tal cual en el `.pck`.
3. **Créditos**: fila propia de cada carpeta de `godot/packs/` en `CREDITOS.md` y su copia
   `godot/CREDITOS.txt` (lo exige `probar_licencias`). Licencia `propia` ya la admite `PackLibrary.LICENSES`.
4. **Pruebas** a pasar (sin tocar límites sin aprobación, regla 9): `probar_packs` (añadir el límite de
   tamaño de cada pack nuevo, `# PROVISIONAL`, con la medida real), `probar_piezas`, `probar_licencias`,
   `probar_piezas_limpias`, autoprueba (`--autoprueba`) y `probar_glb --piezas=N` (piel, mismo esqueleto,
   bind poses y pesos que suman 1).
5. **Peso del programa**: suman unos 20 MB (con las dos variantes de gorra). Valorar quitar la variante
   ajustada si se hace B, y reducir resolución o formas si el build pesa demasiado.
6. **Decisiones del responsable** antes de integrar:
   - Gorra: ¿solo holgada, las dos variantes, o la ajustada + B (pelo aplastado)?
   - Falda: ¿sigue en `accesorio` o pasa a `ropa_piernas` (quitaría los shorts)? Tipo `ropa` para que salga en
     la pestaña Ropa.
   - Monograma GM: ¿pieza aparte o el núcleo admite un segundo color por pieza (p. ej. por color de vértice)?

### Mejoras pendientes por asset

- **Gorra**: A (cambio automático según el pelo) o B (aplastar el pelo), ambos en el núcleo.
- **Falda**: C (pesos de piernas) en el propio asset.
- **Sudadera**:
  - 58 caras plegadas en las axilas (la manga y el costado hinchados se cruzan); arreglo en el asset:
    hinchar menos en la cara interna del brazo y en el costado bajo la axila, o fundir esa zona.
  - El bajo va con los pesos de la piel de la cadera: con la pierna muy levantada puede cruzarse (como C).
  - Capucha subida: pieza aparte, con el mismo problema que la gorra con el pelo (A/B).
  - Los pesos y formas de pretina, puños, capucha y bolsillo salen de los 8 vértices de piel más cercanos;
    revisar con animaciones al integrarla.
- **Vestido qipao**:
  - **Decidido por el responsable: una sola pieza con todo**, y los colores (vestido, adornos, alamares) editables.
    Ya va en una pieza; falta el color por zonas (G). Zonas en `COLOR_0` por vértice: `r = 0` vestido, `r = 1` adornos
    (ribetes, pelo, perlas), y además `g = 1` alamares. El shader ya pinta `skin_color` donde `r = 0` y `garment_color`
    donde `r = 1`: basta con que el núcleo deje dar a la pieza un segundo color (`"colores": ["principal", "adornos"]`)
    en vez de poner el mismo en los dos. El tercero (alamares, `g`) necesita un uniform más en el shader.
  - **Interfaz (pedido por el responsable)**: al seleccionar el vestido, una ventana (o panel) adicional con un selector
    de color por zona: «Vestido», «Adornos» (ribetes, pelo y perlas) y «Alamares». Los nombres de las zonas salen de
    `"colores"` en `pack.json`; cada color se guarda en el proyecto (`project_file`) y viaja al `.glb` exportado (color
    por vértice o un material por zona). Servirá igual para las orejas de gato (fuera / interior) y el casco.
  - **Pesos de las piernas (pendiente, pedido por el responsable)**: con las animaciones las piernas atraviesan la
    falda. Hoy cada panel sigue a la piel más cercana y el centro se reparte con `Hips`. Al integrarlo: panel delantero
    y trasero repartidos entre `Hips` y los dos `UpperLeg` según la altura (arriba, `Hips`; hacia el bajo, cada mitad
    con su muslo y el centro a medias), probado con las animaciones del programa (andar, correr, sentarse). Sin físicas,
    con la pierna muy levantada seguirá cruzándose algo.
  - Bajo un pecho muy grande se ve una línea (el contorno marca la curva del pecho). Las formas del pecho llevan una
    mezcla para que la tela no se meta debajo (`weights_and_shapes`, `hang`); si molesta, bajar `CAIDA` o subir
    `GAP_TORSO`.
  - Las borlas van con la piel cercana, no cuelgan. Las sisas se calculan solas (zona a menos de 2,5 cm del brazo en
    reposo); con brazos muy musculosos, revisar.
  - Pesa 15,8 MB por las formas densas del tronco (las macro mueven todo el vestido).
- **Coraza de acero**:
  - Hoy de un color (gris acero). Zonas en `COLOR_0`: `r = 0` metal, `r = 1` cuero (tirantes y correas), y además
    `g = 1` hebillas y remaches. Con G: «Metal», «Cuero» y «Hebillas» (tres colores, como el vestido).
  - Formas: la envolvente no es lineal (la suma de dos formas no es la suma de sus efectos). Cada forma se mide desde
    su cuerpo de partida (`start_of`: las del pecho, desde el femenino; el resto, desde el base) y nunca sale menos que
    la piel de debajo. Comprobado (sin pose) en base, femenino con pecho grande, fuerte, femenino gordo con pecho y
    delgado. Con combinaciones muy distintas (pecho grande y músculo al máximo, edades extremas) revisar.
  - Rígida a medias: sigue la columna y los hombros como la piel; al doblarse mucho el tronco (animaciones) la chapa se
    dobla con él. Las sisas se calculan en pose T; en la pose A del programa no se cruza, pero con los brazos muy
    pegados al costado (animaciones) puede rozar.
  - El bajo (y=0,935 delante) pisa la cintura de la falda plisada (accesorio) si se ponen juntas; revisar al integrar.
  - La cresta del peto (1 cm) apenas se ve con el sombreado de 3 tonos; si se quiere más marcada, subir `RIDGE_H` o
    partir las normales en la columna del centro.
  - Pesa 11,5 MB por las formas densas (las macro mueven toda la coraza); F (ajuste en el núcleo) no le vale (no es
    rígida); bajar `NH`/`NR` si hace falta.
- **Tentáculos**: H (tamaño ajustable), I (ondular fijo) y F (peso). Van rígidos con `UpperChest`: con los brazos muy
  hacia atrás (animaciones) pueden cruzarse con ellos.
- **Orejas de gato**: ya hay unas «Orejas de gato» (conos generados) en `godot/packs/base`; al integrar, decidir si
  estas las sustituyen. **Decidido por el responsable: al integrarlas serán una sola pieza, con sus dos colores
  (fuera e interior) editables por separado**; hoy van en dos piezas porque cada pieza pinta un solo color (lo resuelve
  «Varios colores por pieza» de G: dos zonas, que el shader ya mezcla con `COLOR`). Peinados muy altos (afro) las
  tapan casi enteras; arreglo en el asset si molesta: base algo más alta o una variante para pelo voluminoso.
- **Casco**: D (vuelve a `accesorio` con `cubre`), E (cristal), F (sin formas) y G (una pieza con y sin visor), en el núcleo.
  - Todo va con `Head`: al inclinar mucho la cabeza (animaciones), el anillo entra en hombros y pecho. Arreglo en el
    asset, si molesta: anillo y base con pesos de `Neck`/`UpperChest`, y la burbuja con más hueco para que la cabeza
    gire dentro.
  - Pesa el doble que la gorra por las formas densas (todas mueven todos los vértices); F lo resuelve.
  - Al integrarlo, la decisión del responsable: ¿visor espejo y abierto como ahora, o esperar a E?
- **Leotardo negro** (aprobado provisionalmente): **antes de integrarlo, L** (delante más bikini, sin pasar al muslo).
  Hoy de un color, sin zonas.
- **Kigurumi de conejito** (aprobado):
  - **Al integrarlo, obligatorio (pedido por el responsable): huesos o movimiento en los pompones (borlas) y en la
    capucha.** Hoy van rígidos: los cordones y los pompones siguen al pecho y la capucha sigue a la piel más cercana
    (cabeza y cuello). Pompones: K (una cadena `x_` por cordón con `fisica`, o el vaivén en el shader). Capucha: que
    se mueva con la cabeza sin despegarse del cuello del pijama: pesos repartidos de `Neck` (abajo) a `Head` (arriba)
    y, si se quiere caída propia al girar la cabeza, una cadena `x_capucha` con `fisica`, como K. Mismo riesgo de los
    53 huesos (K, 4a): lo decide el responsable.
  - Pesos del cuerpo holgado (entrepierna, axilas, codo y rodilla): J.
  - Hoy de un color; zonas en `COLOR_0`: `r = 1` puños (oscuros), `g = 1` franjas, `r = g = 1` cremallera, `b = 1`
    pompones. Con G: «Pijama», «Puños», «Franjas», «Cremallera» y «Pompones».
  - Lleva `cubre: ["pelo"]` (la capucha va puesta): quita el peinado mientras se lleva.
