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

### Calzado: el método aprobado (obligatorio para zapatos, zapatillas y botas)

Decidido por el responsable el 2026-11-27, tras aprobar las zapatillas futuristas, las altas y las botas medievales:
**la forma sale del plano, nunca de la piel del pie ni del molde de otro asset**. Copiar e hinchar la piel deja ver los
dedos y la curva del pie; eso ya no se acepta.
1. **Horma**: `claude_zapatillas_futuristas/horma.py`, clase `Horma`. El generador crea la suya con sus medidas:
   - pie: perfiles a lo largo de z (`pz`, `pw` media anchura, `pc` centro x, `pt` alto), `toe_r` y `heel_r` (punta y talón);
   - caña: tablas por altura del eje de la pierna (`axis_x`, `axis_z`) y de sus medios ejes (`shaft_ax`, `shaft_az`),
     con la boca (`collar`) y arrugas opcionales (`fold`);
   - rejilla: `na`, `n_shaft`, `n_arc`, `n_foot`, `n_toe`, y el codo del eje (`y_b`, `r_arc`): el centro del codo debe
     quedar **por encima** de la puntera (si no, `cast` falla porque un rayo no sale).
   Se hace el pie izquierdo; el derecho se refleja (`horma.mirror_both`, o reflejar las piezas como en las futuristas).
2. **Medir el cuerpo solo para la holgura**: cortar la pierna y el pie por rodajas (centro y medio ancho; ver las tablas de
   `generar_botas.py`) y darle a la horma curvas suaves con la holgura encima. Comprobar con un `check_fit` (piel bajo la
   boca: ninguna fuera y hueco mínimo ≥ 3 mm; medir contra la superficie, no solo contra los vértices).
3. **Piezas sobre la horma, no sobre la rejilla**: paneles y punteras recortados por su borde con `tr.clip` y en relieve con
   canto (`panels` de las futuristas, `relief` de las altas); radios y altos medidos con rayos (`H.cast`, `HormaRadius` y
   `top_y` de las botas). Medir con los vecinos de la rejilla deja dientes.
4. **Suela por contorno** (`Outline` de las futuristas): centro = el de la caja del pie, **no la media** de los puntos.
   El pie del cuerpo es plano y está en el suelo: nada de tacones altos (el asset no puede levantar al personaje).
5. **Pesos y formas**: de la piel más cercana (`sud.nearest_skin`, 8 vecinos, máscara del lado: pierna o pie); las piezas
   rígidas, a su hueso. **Forro** solo en las filas que se ven por la boca (`H.lining`), no una cara de dentro entera.
6. **Peso**: vigilar el `.glb` (las tres aprobadas: 8,8–10,3 MB); bajar `na` y filas antes de perder forma.
7. **Revisión propia** antes de enseñarlo: un visor rápido (render ortográfico con las caras traseras en rojo) para cazar
   caras al revés y huecos; luego, pack a `user://packs` y abrir el editor para el responsable.
Ejemplos: `generar_zapatillas_futuristas.py` (todo desde cero), `generar_zapatillas.py` (zapatilla alta, suela doble),
`generar_botas_futuristas.py` (líneas sobre la superficie exacta con `project`, correa en relieve, puño, plataforma con hendidura),
`generar_botas.py` (caña alta con arrugas, acero y correas).

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
| Leotardo negro | Aprobado (rehecho pegado a la piel; L hecha) | `claude_leotardo/`; desde el 2026-11-27, con el generador de maillots (`claude_bodysuits/cortes.py`): **la piel recortada y separada 2,5 mm, pegada al cuerpo** (pedido por el responsable tras el bodysuit; antes era la `tights.glb` con «tela tensa», que hacía puente en la ingle). Mismo diseño: cuello redondo alto (plano y = 1,39 − 0,3·z y elipse de ±8,5 × 7,5 cm), sin mangas (sisa en |x| = 0,15), delante tipo bikini que **se para en el pliegue de la ingle** (por el peso de pierna de la piel: L hecha), detrás braguita en curva. Bordes que bajan a la piel, sin ribete. **Una sola pieza** (ranura `ropa_torso`, `cubre: ["ropa_piernas"]`), de un color. Tela a la piel ≥ 2,0 mm (≥ 1,6 mm con cada forma); 242 formas, 7,5 MB (regenerado con `refine_near`: mismo aspecto, antes 12,7) |
| Bikini negro (liso) | Aprobado (falta M, en el núcleo) | `claude_bikini/`; del plano solo la forma (sin flores, borlas, cuentas ni anillas). La tela es **la piel del cuerpo recortada** y separada 2,5 mm: copas triangulares, banda de 1,2 cm bajo el pecho y braguita baja (cintura y=0,905 delante y 0,925 detrás). Delante en **V** (media anchura 1,6 cm en la entrepierna) y sin pasar al muslo (corta también donde la piel pesa más de 0,4 de pierna); detrás **tanga**: triángulo de 15 cm bajo la cintura que acaba en hilo de 1,2 cm desde y=0,845. **Tira halter plana**: cinta de 1,2 cm sobre la piel, de dentro de cada copa alrededor del cuello, con lazo en la nuca; tira de 1 cm en cada cadera, también cinta sobre la piel, con su lazo. Sin ribete: en los bordes la tela baja hasta la piel en 6 mm (el contorno no parpadea). Cada vértice sigue a su triángulo de piel (pesos y formas). Hueco mínimo con cada forma 1,5 mm lejos de los bordes. **Una sola pieza** (ranura `ropa_torso`, `cubre: ["ropa_piernas"]`), negra; zonas en `COLOR_0` (r = 1 lazos). 237 formas, 11,3 MB |
| Casco felino neón | Pendiente de probar | `claude_casco_felino/`; casco integral de moto con orejas de gato. **Una sola pieza** (ranura `pelo`: quita el peinado) con las zonas en `COLOR_0` para cuando el núcleo pinte un color por zona (G): carcasa (0,0,0), visor r = 1, neón g = 1, galones b = 1; hoy, de un color. Carcasa: el elipsoide que contiene la cabeza + 2,2 cm (6 mm de grosor), cerrada delante (el visor es opaco, en relieve encima) y abierta abajo desde 47° bajo el centro de la cabeza; hueco a la piel por dentro 16 mm (13 mm con la peor forma). Orejas de 8,8 cm (las de `claude_orejas`, más grandes) con el interior de neón; logo del gato en cada lado; barra de luz detrás; franjas de neón abajo; dos galones «<» en cada lado; rejillas en la mentonera. 100 % `Head`, formas afines como el casco de astronauta (26 formas), 8,6 MB |
| Máscara de gas | Aprobada (quedan arreglos menores, los dará el responsable) | `claude_mascara/`; **una sola pieza** (ranura `accesorio`: convive con el peinado), zonas en `COLOR_0`: goma (0,0,0), cristales r = 1, filtro y válvulas g = 1, correas, placa y hebillas b = 1. Máscara: la piel de la cara que se ve de frente (sin el interior de boca y ojos), de la frente (y=1,63) a la barbilla, separada 6 mm y alisada (pasa sobre nariz y ojos); el borde baja a la piel (sello). Lentes de 4 cm con aro, filtro de 6,6 cm en la boca (mirando 25° abajo) con radios en la tapa, válvula con rejilla en cada mejilla: rígidas, siguen a su punto de la cara. Correas planas de 2 cm **pegadas al cráneo** (arriba, sobre las orejas y bajo ellas) hasta una placa detrás, con hebillas: hoy el pelo pasa por encima (ver O). Pesos y formas de la piel; cara de fuera ≥ 1,8 mm sobre la piel con cada forma. 82 formas, 10,7 MB |
| Traje espacial EVA (sin casco) | Aprobado | `claude_eva/`; como el kigurumi: **la piel entera** (salvo cabeza y cuello) copiada e hinchada, con pesos y formas por índice (sigue a cualquier edición del cuerpo), guantes (2 mm, siguen a cada dedo) y botas (1 cm, dedos alisados) en la misma pieza. Holgura: tronco 2,4 cm, brazos 2 cm, muslo 2,4 → pantorrilla 2,8 cm. **Una sola pieza** (ranura `ropa_exterior`, `cubre: ["ropa_torso", "ropa_piernas", "ropa_pies"]`), sin mochila. Cuello: anillo medido sobre el del casco de astronauta (lo alto queda dentro del anillo del casco; asoma el reborde). Relieve: anillos de las muñecas, caja de mandos (rígida) con dos tubos, cinturón con hebilla, hombreras, rodilleras, bolsillos con solapa, aros acolchados en brazos y piernas, caña de las botas. Zonas en `COLOR_0`: r = 1 gris (guantes, suelas, almohadillas, cinturón, solapas, caña), g = 1 metal (anillos, hebilla), b = 1 caja y tubos. 272 formas, 14,7 MB. En Linux se genera con `~/.venvs/gamemolde_assets/bin/python` (numpy + scipy) |
| Botas blindadas medievales | Aprobadas (rehechas con horma) | `claude_botas_medievales/`; el par en **una sola pieza**, ranura `ropa_pies` (no quita nada, ver P). Cuero: **horma propia** (`claude_zapatillas_futuristas/horma.py`, ver Q), no la piel: caña hasta 4 cm bajo la rodilla con la sección de la pantorrilla medida + 1 cm y arrugas abajo; pie a 7–9 mm, puntera 1,7 cm más larga; suela que sobresale 4 mm con tacón (igual que antes). Acero rígido con su hueso: espinillera con cresta y punta, con remaches; empeine de 3 láminas (medidos con rayos sobre la horma). Correas con hebilla: dos arriba, media caña, tobillo y bajo el pie. Zonas en `COLOR_0`: r = 1 acero, g = 1 correas, r = g = 1 hebillas y remaches, b = 1 suela. Pesos y formas de la piel cercana; hueco mínimo 3,5 mm; 27 formas, 10,3 MB |
| Guanteletes de garras de dragón | Aprobados | `claude_guanteletes/`; la piel de la mano y del final del antebrazo copiada e hinchada (pesos y formas por índice: crece con las manos), con grosor. **Más grandes que la mano**: dorso y palma 8 mm, dedos 6 mm (nunca más de 0,45 × el hueco con el dedo de al lado), puño acampanado de 2 a 3,2 cm (tapa el anillo de muñeca del EVA); surco en cada nudillo. `SIZE` escala todo lo grande a la vez. Garras rígidas con la última falange (curvadas hacia la palma; la del pulgar, hacia el índice), escudo con cresta y chevrón en el dorso (rígidos con la mano), correas en X y muñequera con bloque. Ranura `accesorio` (va encima de cualquier ropa). Zonas en `COLOR_0`: r = 1 correas y escudo, g = 1 garras. 56 formas, 5,4 MB |
| Zapatillas altas negras | Aprobadas (rehechas con horma) | `claude_zapatillas_altas/`; **horma propia** (`claude_zapatillas_futuristas/horma.py`, ver Q), no la piel: no se notan los dedos ni la curva del pie. Grandes, estilo VTuber: caña hasta 10 cm sobre el tobillo; puntera alta para asomar sobre la suela. **Suela doble** (pared de 6 cm, sube en la punta) con franja; puntera de goma en arco, en relieve con canto; lengüeta bajo los cordones que asoma sobre la boca; 7 pares de ojales de metal sobre la línea central con cordones cruzados; 2 ojales de ventilación por dentro; tira detrás. **Sin el parche de la estrella** (logotipo de una marca). Ranura `ropa_pies`, sin `cubre`. Zonas en `COLOR_0`: r = 1 goma, g = 1 cordones, r = g = 1 ojales, b = 1 franja. Pesos y formas de la piel cercana; hueco mínimo 4,9 mm; 27 formas, 8,8 MB |
| Zapatillas futuristas | Aprobadas (el responsable: «perfectas») | `claude_zapatillas_futuristas/`; **forma sacada del plano, no de la piel del pie**: horma propia (caja del pie de sección supereléptica con punta redonda y talón recto, unida en suave a una caña elíptica que se estrecha arriba), medida sobre el cuerpo solo para la holgura (hueco mínimo 6,4 mm; caña a ~1,6 cm); malla con rayos desde un eje que baja por la pierna y se curva hasta la punta. Paneles negros en relieve (1,6 mm, con canto) recortados de la horma: cuello acolchado, talón, galón lateral, ojales y dos franjas en diagonal; lengüeta con pestaña rosa, 5 pares de cordones cruzados, correa con hebilla en el tobillo. Suela de plataforma: cuña blanca con ranura, base negra con tacos que suben, puntera, franjas y planta rosas. Tirador y pestaña rosas detrás, triángulo (adorno genérico) a cada lado y en la lengüeta. Ranura `ropa_pies`, sin `cubre`. Zonas en `COLOR_0`: (0,0,0) negro, r = 1 blanco, g = 1 rosa, b = 1 metal, r = g = 1 cordones. Pesos y formas de la piel cercana; 27 formas, 10,3 MB |
| Botas futuristas | Aprobadas (el responsable: «perfectas») | `claude_botas_futuristas/`; **horma propia** (ver Q): botín con caña hasta y = 0,205 a ~1,2 cm de la pierna (tablas de las botas medievales), puntera ancha y alta; la planta de la horma sube a y = 0,019 (queda dentro de la suela). **Sin el tacón del plano** (decidido por el responsable): plataforma plana con tacos abajo y una hendidura en el arco que separa el bloque del talón. Puño de tela arrugado que tapa la boca (hueco a la pierna 5,9 mm). En relieve: banda oscura en cada lado y X delante; correa del tobillo (anillo) con hebilla y triángulo rosa; correa del empeine (relieve más alto, de suela a suela) con hebilla fuera; «///» fuera. Neón rosa: barra delante, tres tiras en el talón y cuña en el arco. Las líneas se proyectan sobre la superficie exacta de la horma (gradiente de su campo), no con los vecinos de la rejilla. Ranura `ropa_pies`, sin `cubre`. Zonas en `COLOR_0`: (0,0,0) crema, r = 1 oscuro, g = 1 rosa, b = 1 metal, r = g = 1 puño, r = b = 1 suela. Pesos y formas de la piel cercana; hueco mínimo 8,4 mm; 27 formas, 10,3 MB |
| Chaqueta cyberpunk | Aprobada | `claude_chaqueta_cyber/`; parte de la chaqueta del traje rosa (`generar_chaqueta.py`: piel copiada e hinchada, pesos y formas por índice). Corta (bajo a y = 1,06 detrás, 1,09 delante) y **abierta delante** (sin la piel de \|x\| < 7 cm; cuello, abertura y bajo son un solo borde, alisado sobre su plano). Forro rosa. Mangas globo desde el antebrazo (+6 cm) que se recogen en un puño acanalado de 6 cm con franja rosa. Capucha bajada grande, de pie alrededor del cuello, con forro rosa (sobre el arco del cuello: abierta delante). Cremalleras en los bordes; correas rosas del hombro al bajo que **cuelgan 11 cm** (hasta la cadera, decidido por el responsable) con hebilla de clip y puntera, y dos cintas detrás; cinturón en el pecho que cruza la abertura (a ≥ 8 mm de la piel con el pecho al máximo) con hebilla y dos anillas. Bolsillo cargo rígido con solapa y X en cada antebrazo; **kanji 東京** en relieve en la manga izquierda (único dibujo, decidido por el responsable). Ranura `ropa_exterior`. Zonas en `COLOR_0`: (0,0,0) negro, r = 1 rosa, g = 1 metal, b = 1 kanji, r = g = 1 puños, r = b = 1 plástico. Hueco a la piel ≥ 0,7 mm (en el borde del cuello, bajo la capucha). 257 formas, 8,4 MB |
| Alas demoníacas | Aprobadas (pendiente R: deslizadores de tamaño, ubicación y postura) | `claude_alas/`; **pequeñas** (35 cm de la espalda a la punta) y **abiertas** (decidido por el responsable): a los lados, 30° hacia atrás, plano inclinado 10°; envergadura hasta x = ±0,34. Silueta medida en el plano: base (placa hundida 1,2 cm en la espalda que sale 3 cm: asoma sobre la ropa), hueso del brazo hasta la muñeca con nudillo, borde de ataque hasta la punta y tres dedos (tubos que se estrechan); membrana con grosor y borde de salida en arcos; el ala se curva hacia atrás a la punta. Raíces en x = ±5,5 cm, y = 1,24; a 10,4 cm del brazo y 24 cm de la cabeza. Ranura `accesorio`. 100 % `UpperChest`; cada ala, entera con su raíz (36 formas), 2,0 MB. Zonas en `COLOR_0`: (0,0,0) membrana, r = 1 hueso y base. Tamaño, ubicación y postura con deslizadores: ver R |
| Nueve colas de kitsune | Aprobadas (el responsable: «perfectas»; pendientes S y T) | `claude_colas/`; del tamaño del plano (decidido por el responsable): 52–62 cm, abanico **simétrico** (decidido por el responsable: en remolino parecían girar; la de arriba recta, las de arriba y los lados caen hacia fuera, las de abajo se abren lejos de las piernas) de x = ±0,69 e y = 0,46 a 1,56, hasta 42 cm detrás. Nacen juntas en el coxis (y = 0,95, hundidas 2 cm), salen hacia atrás enseguida (hueco mínimo al cuerpo 1,2 cm) y se abren; las de abajo pasan detrás de las piernas (al andar pueden cruzarlas; ver T). **Muy fur** (decidido): núcleo en lágrima cubierto de mechones aplanados en punta hacia la punta de la cola, solapados como escamas y abiertos en la punta (borde dentado). Punta roja: zona propia, cada mechón cambia a una altura algo distinta (borde en llamas). Ranura `accesorio`. 100 % `Hips`; todas enteras con su raíz, solo las formas que mueven la raíz ≥ 8 mm (19 formas), 10,2 MB. Zonas en `COLOR_0`: (0,0,0) blanco, r = 1 rojo. Pelo suave por capas: ver S; deslizadores y movimiento: ver T |
| Bodysuit de espalda abierta | Aprobado (el responsable: «esto era lo que buscábamos») | `claude_bodysuits/` (familia de maillots: `cortes.py` es el generador, cada `generar_*.py` solo da sus cortes). **La piel recortada y separada 2,5 mm, como el bikini** (con la malla de cuerpo completo la tela hacía puente en la ingle y se iba hacia las piernas; el responsable: «pegados a la piel»): marca el cuerpo y cada vértice sigue a su triángulo de piel; bordes que bajan a la piel, sin ribete. Cuello alto (y = 1,455), manga corta (45 % del brazo), espalda abierta en óvalo (y = 1,00 a 1,36, ±11,8 cm). Abajo, por media anchura a cada altura: delante V que sube casi a la cintura (13,5 cm a y = 1,04) sin pasar al muslo; detrás **tanga** que acaba en hilo de 1,2 cm por el surco (pedido por el responsable). Ranura `ropa_torso`, `cubre: ["ropa_piernas"]`, de un color. Tela a la piel ≥ 1,9 mm (≥ 1,4 mm con cada forma); 247 formas, 8,0 MB (regenerado con `refine_near`: mismo aspecto, antes 14,1) |
| Bodysuit negro y dorado | Aprobado | `claude_bodysuits/generar_bodysuit_dorado.py`; generador de maillots (piel recortada, pegada). Manga larga hasta la muñeca, ventana redondeada en el pecho bajo el cuello (10 × 2,2 cm), delante V alta con la entrepierna estrecha (2 cm) y detrás **hilo hasta arriba** (pedido por el responsable: sube por el surco hasta y ≈ 0,93 y solo ahí se abre en un triángulo pequeño). **Cuello vuelto** holgado: la piel del cuello copiada e hinchada 1,2 cm con pliegues horizontales, borde arriba de y = 1,50 detrás a 1,44 delante (bajo la barbilla; a 9 mm de la cabeza), dos capas. En relieve dorado: franja de 2,2 cm del cuello al puño por el hombro y por fuera del brazo; triángulo y cuatro barritas en X en el pecho, triangulito a cada lado de la ventana; en la entrepierna barra, dos triángulos llenos y uno hueco. Nuevo en `cortes.py`: `refine_near` (divide solo cerca de los cortes, sin grietas: la mitad de peso), `window`, piezas extra en `build`, y el corte de abajo ya no toca los brazos. Ranura `ropa_torso`, `cubre: ["ropa_piernas"]`. Zonas en `COLOR_0`: (0,0,0) negro, r = 1 dorado. Tela a la piel ≥ 2,3 mm (≥ 1,6 mm con cada forma); 262 formas, 9,9 MB |
| Bodysuit arnés negro | Aprobado (el responsable: «perfecto») | `claude_bodysuits/generar_bodysuit_arnes.py`; generador de maillots (piel recortada, pegada). Top corto sin mangas: cuello redondo alto (plano y = 1,405 − 0,3·z, elipse ±6,8 × 7 cm), sisa honda en curva (tirante del hombro de ~4 cm). Abierto delante y detrás desde bajo el pecho (arco de y = 1,22 delante y 1,18 detrás); las aberturas se miden en **grados alrededor del eje del tronco**, así en el costado queda una tira de 3,4–4 cm (y = 1,10–1,14) que se ensancha al unirse con las piezas de abajo. Delante V alta con la entrepierna estrecha (1 cm); detrás **tanga triangular** como el plano (decidido por el responsable; se probará). **Solo las 2 hebillas de clip de los hombros** (decidido por el responsable), sobre una cinta en relieve; hembra con pestañas y macho, perfil achaflanado. Ranura `ropa_torso`, `cubre: ["ropa_piernas"]`. Zonas en `COLOR_0`: (0,0,0) negro, r = 1 hebillas, g = 1 cinta. Tela a la piel ≥ 2,4 mm (≥ 1,6 mm con cada forma); 224 formas, 10,6 MB |
| Traje rojo y azul con plumas | Aprobado (el responsable: «perfecto») | `claude_bodysuits/generar_traje_plumas.py`; generador de maillots. **Sin lo reconocible del plano** (decidido por el responsable: sin murciélagos en los muslos, espalda en U sin las formas de ala) y **sin guantes** (mangas hasta la muñeca). Maillot: cuello abierto y bajo (se ven las clavículas; plano y = 1,375 − 0,3·z, elipse ±12,5 × 10 cm), rombo en el pecho (y = 1,16–1,31, ±3 cm), espalda abierta en U hasta y = 1,02, piernas altas, detrás cubre la mitad de dentro de los glúteos. Mangas pegadas del hombro a la muñeca (la misma tela, otra zona). **Medias** hasta el tobillo: otra capa, la piel sacada 1,2 mm por su normal **sin «tela tensa»** (alisada, la piel asomaba), sube por debajo del maillot. Maillot y medias **de una cara** (sin grosor: los bordes bajan a la piel; de 18 a 9 MB). **Cuello de plumas** «bien fur»: 6 filas por hombro (138 plumas, hojas en punta con borde dentado y giro), las de fuera largas y más caídas (forma de ala), ×0,8 del plano (pedido por el responsable); cada pluma rígida con la piel de su raíz (formas ≥ 6 mm). Sin banda en la nuca (quitada por el responsable: el cuello, libre detrás). Nuevo en `cortes.py`: rango de alturas y separación propios (`sheet`), zona por vértice (`zone_of`), tela de una cara (`thick=False`) y `min_move` (también en `bk.write`). Ranura `ropa_torso`, `cubre: ["ropa_piernas"]`. Zonas en `COLOR_0`: (0,0,0) maillot, r = 1 mangas, g = 1 medias, b = 1 plumas (las medias de otro color, con G). Tela a la piel ≥ 1,8 mm (≥ 1,3 mm con cada forma); medias ≥ 1,1 mm (≥ 1,0 mm); 254 formas, 7,7 MB |
| Top blanco con bodysuit arnés | Aprobado (el responsable: «perfecto») | `claude_bodysuits/generar_top_arnes.py`; generador de maillots, todo en la misma tela (de una cara). Top corto blanco: cuello redondo de canalé negro (2,2 cm), bajo en arco (y = 1,18 delante, 1,165 detrás). **Mangas globo como el plano**: la tela hinchada desde un eje del brazo suave (codo redondeado), hasta 6 cm en el antebrazo, como desplazamiento alisado sobre la malla (sin pliegues en el codo), sin acercarse al costado, recogida en un puño de canalé negro; en los bordes vuelve a la piel. Tiras blancas de 2,4 cm del top a una anilla delante (y = 0,972) y otra detrás (0,985). Abajo, negro: V delante con la entrepierna estrecha y dos tiras de la anilla a sus esquinas; tira por la cadera a cada lado; detrás **hilo delgadito** (9 mm) por el surco hasta la anilla y dos tiras a la cadera (decidido). Todas las tiras **pegadas a la piel** (decidido) y medidas como curvas sobre la piel (rayos desde el eje del tronco). En relieve (apoyado con rayos desde el eje del brazo): dos bandas por manga con anilla en D, dos **cintas que cuelgan** hasta 20 y 13 cm más allá de la muñeca (decidido: se quedan; hoy rígidas, ver U), franja en el antebrazo y dos zarpazos a cada lado del pecho. Nuevo en `cortes.py`: `refine` con campo propio (divide otra vez solo cerca de las tiras estrechas) y `shape` (cambia la tela antes de escribirla). Ranura `ropa_torso`, `cubre: ["ropa_piernas"]`. Zonas en `COLOR_0`: (0,0,0) blanco, r = 1 negro, g = 1 metal. Tela a la piel ≥ 0,8 mm (≥ 0,3 mm con cada forma); 250 formas, 9,1 MB |
| Jersey corto rosa con body crema | Aprobado (el responsable: «magnífico») | `claude_bodysuits/generar_jersey_rosa.py`; generador de maillots, **sin los dibujos del plano** (decidido). Body crema de una cara, pegado a la piel: delante V alta con la entrepierna estrecha (1,4 cm), detrás **tanga delgada** (pedido por el responsable): hilo de 1,2 cm que se abre en triángulo bajo la cintura (y ≈ 0,85–0,89). Ribete rosa en las piernas (zona por vértice), rayas en relieve en los costados y en la entrepierna. **Jersey corto holgado como el plano** (decidido): otra capa de piel con grosor, holgura de 1,1 cm por la normal, delante cae recto desde el pecho, alisado (no se marcan los pezones); bajo recto y suelto en y = 1,115. Mangas globo (más grandes que las del top blanco) con puño de canalé y dos rayas crema en relieve; dos franjas crema en curva por fuera de cada manga; paneles crema en los hombros. Cuello alto de canalé doblado (dos capas; a 7,3 mm de la cabeza). Ranura `ropa_torso`, `cubre: ["ropa_piernas"]`. Zonas en `COLOR_0`: (0,0,0) rosa, r = 1 crema. Tela a la piel ≥ 2,3 mm (≥ 2,0 mm con cada forma); jersey ≥ 1,5 mm en reposo, conocido: hasta 2,2 mm dentro de la piel en el pliegue de la axila con 5 formas extremas (peor `back_width_incr`); 262 formas, 12,7 MB |
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

### L. Leotardo: delante más «bikini» (pedido por el responsable; hecho el 2026-11-27: la tela es la piel y se corta por el peso de pierna)

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

### Q. Rehacer todo el calzado con la horma de las zapatillas futuristas (pedido por el responsable; hecho y aprobado)

Las botas medievales y las zapatillas altas negras copian la piel del pie y la hinchan: se notan los dedos y la curva del pie. Rehacerlas con el método de `claude_zapatillas_futuristas/generar_zapatillas_futuristas.py`: horma propia sacada del plano (`field`: caja del pie supereléptica + caña elíptica, unión suave), malla con rayos (`rays`, `cast`), medida sobre el cuerpo solo para la holgura (`check_fit`), paneles recortados de la horma (`panels`) y suela por contorno (`Outline`). Cada una con sus perfiles (`PZ`, `PW`, `PC`, `PT`, caña y boca) según su plano; las botas, con la caña hasta bajo la rodilla. Lo mismo para todo calzado nuevo. Pesos y formas, de la piel cercana, como ahora.

Hecho el 2026-11-27: la horma está en `claude_zapatillas_futuristas/horma.py` (clase `Horma`: perfiles del pie, caña por tablas de altura, arrugas opcionales); las futuristas la usan sin cambiar su forma. Botas y zapatillas altas rehechas (las piezas, apoyadas en la horma); a las zapatillas altas, la suela doble (pedido por el responsable), a las botas no.

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

### R. Alas demoníacas: tamaño y ubicación con deslizadores (pedido por el responsable; no hecho)

Hoy salen pequeñas (~35 cm cada una) y fijas. Se quieren deslizadores propios de la pieza, visibles cuando está puesta:
- **Tamaño**: un deslizador que las agranda y las encoge (p. ej. de ×0,5 a ×2), creciendo desde su raíz.
- **Ubicación**: sus propios deslizadores para moverlas por la espalda (p. ej. altura, separación entre las dos y
  cuánto se hunden o salen), sin despegarse del cuerpo.
- **Postura**: hoy van abiertas (decidido por el responsable). Un deslizador para abrirlas y plegarlas, o huesos propios
  (base, muñeca y dedos de cada ala) para posarlas y animarlas; con huesos, el `.glb` exportado los llevaría colgando de
  `UpperChest`.
Cómo: lo mismo que H (deslizadores de la pieza en `pack.json`, que el núcleo respete, la interfaz muestre y el proyecto
guarde). Para el tamaño, formas propias `alas_mas` / `alas_menos` (cada vértice se aleja o acerca a la raíz de su ala) o
escala en CPU. La ubicación cabe mejor en CPU: mover cada ala rígida (son 100 % `UpperChest`) y volver a apoyar la raíz
en la piel de su nuevo sitio. Necesita el núcleo.

### S. Pelo suave por capas («shell fur») para las colas y lo peludo (idea propuesta; no hecho)

Hoy el «fur» de las colas es pelo esculpido (mechones de geometría): da la silueta, pero no el pelo suave ni el
degradado blanco → rojo del plano (las zonas son de un color). La mejora, en el núcleo: un shader de pelo por capas
(la pieza se dibuja N veces, cada capa algo hinchada por su normal, y en cada una solo se ven los «pelos» de una textura
de ruido, más finos hacia fuera), con el color de la raíz a la punta por la coordenada a lo largo de la cola (o un
`COLOR_1`). Va encima del pelo esculpido. Coste: N pasadas de dibujo; en PC bien, en Android con pocas capas o sin
ellas. Necesita el núcleo (shader, material por pieza y una textura de ruido con licencia limpia o generada).

### T. Nueve colas: deslizadores y movimiento predefinido (pedido por el responsable; no hecho)

- **Deslizadores**, como las alas (R): tamaño (crecen desde la raíz) y ubicación en el cuerpo.
- **Movimiento predefinido** (no lo controla el usuario): un vaivén propio en bucle, cada cola con su fase, que se ve
  en el editor y sale con el personaje (huesos propios de cada cola colgando de `Hips` con su animación, o un
  movimiento en el shader de vértices). Como I con los tentáculos. Las de abajo pasan por detrás de las piernas: con
  el movimiento, que se aparten de ellas al andar. Necesita el núcleo.

### U. Top blanco con arnés: físicas o huesos en las cintas de las mangas (pedido por el responsable; no hecho)

Hoy las dos cintas de cada manga (de la anilla en D a 20 y 13 cm más allá de la muñeca) van rígidas: lo de la manga con la
piel del antebrazo y lo que cuelga, en vertical en la pose de reposo; al mover el brazo no caen. Como K (pompones):
1. **Asset**: cada cinta, desde la muñeca, con su cadena de huesos propios (3–4, `x_cinta_l_01`…), colgada de `LeftLowerArm` /
   `RightLowerArm`; pesos rígidos por tramo y suaves entre tramos.
2. **`pack.json`**: `fisica`, una cadena por cinta (rigidez baja, gravedad alta, `radio` del antebrazo y la mano para que
   no los atraviesen).
3. **Núcleo**: `SpringBoneSimulator3D` por cadena (ver K, 3). Mismo riesgo de los 53 huesos (K, 4a): lo decide el responsable.
- Vía corta sin núcleo nuevo: vaivén en el shader (como I), sin peso real.

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
