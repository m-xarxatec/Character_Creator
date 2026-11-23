# GUÍA DE INTERFAZ — cómo debe verse y comportarse la ventana

> Propuesta del mentor (2026-11-18). Sustituye a «plano y sobrio» de la primera maqueta.
> Referencia visual: `diseno/maqueta-v2.html` (ábrela en el navegador; tiene tema claro y oscuro).
> Los pasos para construirla están en `propuestas/expansion_v2.md`, fase **IU**. Aquí solo está el «cómo debe quedar».
> Inspiración: la **organización** de VRoid Studio (elegir antes que ajustar, personaje grande en el centro). No se copia nada suyo: ni iconos, ni capturas, ni colores, ni textos.

---

## 1. Siete principios

1. **El personaje es lo principal.** La vista 3D ocupa el centro y es la zona más grande y luminosa. Los paneles la rodean sin taparla.
2. **Primero se elige y después se ajusta.** Las miniaturas (género, peinados, prendas) van antes que los deslizadores. Quien empieza no tiene que entender 48 barras.
3. **Pocos controles a la vista.** Se ve solo la zona elegida; lo demás está plegado o en otra pestaña.
4. **Cada control dice qué hace.** Nombre claro en español y una ayuda (tooltip) de una línea. Sin palabras técnicas en la ventana: «Rim» pasa a «Brillo de borde».
5. **Respuesta inmediata.** Todo lo que se puede pulsar cambia al pasar el ratón por encima, y las transiciones duran entre 120 y 180 ms. Nada parpadea ni salta.
6. **Un acento, colores suaves.** Fondo lavanda muy claro, paneles blancos y un violeta como único color de acción. El resto de colores solo tiene significado: bien, aviso, error y tipo de deslizador.
7. **Una acción principal siempre visible:** **Exportar .glb**, arriba a la derecha, con el color de acento.

---

## 2. Distribución de la ventana

Tamaño mínimo: 1280 × 720. Referencia de diseño: 1440 × 900.

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ ◆ GameMolde  personaje.json •   Cuerpo  Cara·  Pelo·  Ropa·  Accesorios·  Estilo      │  barra superior, 56 px
│                                                     ↶ ↷   Abrir  Guardar  [Exportar]  │
├───────────────┬──────────────────────────────────────────────┬───────────────────────┤
│ Zonas│Plantill│  [Frente][Lado][¾][Cara]        [⇆][👕][#]    │ Cabeza          3 aj. │
│               │                                              │ 🔍 Buscar ajuste…      │
│   silueta     │                 personaje                    │ Tamaño  ────●───  50 ↺ │
│   con zonas   │                                              │ Ancho   ───●────  45 ↺ │
│               │              ( sombra de suelo )             │ Alto    ────●───  50 ↺ │
│ ▸ Global   4  │  ┌────────────────────────────────────────┐  │                       │
│ ▸ Cabeza   3  │  │ Reposo  Pose T  Caminar  Correr  Atacar │  │ [Restablecer zona]    │
│ …             │  └────────────────────────────────────────┘  │                       │
│   280 px      │        Arrastra para girar · Rueda: zoom     │   360 px              │
├───────────────┴──────────────────────────────────────────────┴───────────────────────┤
│ ✓ Informe: todo bien   ·   1,68 m · 6,9 cabezas   ·   26.756 triángulos · 53 huesos   │  barra de estado, 32 px
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- **Barra superior:** marca, nombre del archivo (un punto `•` si hay cambios sin guardar), pestañas principales, Deshacer/Rehacer, Abrir, Guardar y **Exportar** (botón principal).
- **Pestañas principales:** Cuerpo, Cara y ojos, Pelo, Ropa, Accesorios, Estilo (Pelo, Ropa y Accesorios: una fila por pieza, con su nombre y su color; autor y licencia, solo en Créditos (D45); paso AB.13). Las que aún no existen se ven con una etiqueta pequeña «Pronto» y su ayuda dice qué llegará; no se ven grises y muertas. La pestaña **Exportar** deja de ser pestaña: pasa a ser el botón principal, que abre un diálogo con opciones.
- **Panel izquierdo (280 px):** dos pestañas pequeñas. **Zonas**: una silueta del cuerpo en la que cada zona se ilumina al pasar el ratón y se elige con un clic, y debajo la lista de zonas con su número de ajustes. **Género**: Aleatorio, Femenino, Masculino y Neutro (paso PL.10); lo demás, con los deslizadores.
- **Vista 3D (centro):** fondo degradado, sombra de suelo, botones flotantes (vistas rápidas arriba a la izquierda, interruptores arriba a la derecha y barra de poses abajo). La primera vez, una pista: «Arrastra para girar · Rueda para acercar · Clic en el cuerpo para elegir zona».
- **Panel derecho (360 px):** los ajustes de la zona elegida. Arriba, el nombre de la zona y un buscador que filtra entre todos los ajustes.
- **Informe de deformación:** el desplegable del P.2 se queda bajo la vista, y además la barra de estado enseña su resumen como una pastilla de color que lo abre.
- **Barra de estado (32 px):** informe, medidas en vivo (altura en metros y cabezas de alto) y presupuesto (triángulos y huesos).
- Los paneles laterales se pueden plegar (botón en su borde) para ver el personaje a pantalla completa.

---

## 3. Tokens de diseño

Todos los valores viven en **un solo archivo** (`godot/app/tema/tokens.gd`). Ningún otro archivo de `app/` escribe un color, un tamaño de letra o un margen a mano.

### 3.1 Colores

Contrastes medidos con la fórmula WCAG (texto normal ≥ 4,5:1).

| Token | Claro | Oscuro | Uso |
| --- | --- | --- | --- |
| `fondo` | `#F3F1F8` | `#15131D` | Detrás de todo |
| `panel` | `#FFFFFF` | `#1E1B29` | Paneles, barra superior, tarjetas |
| `panel_2` | `#F7F6FB` | `#262234` | Filas al pasar el ratón, campos de texto |
| `borde` | `#E3E0EC` | `#36314A` | Separadores y bordes finos |
| `borde_fuerte` | `#CFCADD` | `#4A4462` | Borde de campos y botones secundarios |
| `texto` | `#1E1B2E` | `#F2F0FA` | Texto principal (16,8:1 / 15,0:1) |
| `texto_2` | `#4F4A66` | `#C3BED6` | Etiquetas y valores (8,4:1 / 9,4:1) |
| `texto_3` | `#6E6987` | `#9C97B2` | Ayudas y pistas (5,2:1 / 6,0:1) |
| `acento` | `#6A55E0` | `#6A55E0` | Botón principal, relleno de barras, selección; texto blanco encima (5,3:1) |
| `acento_hover` | `#5A46D0` | `#5A46D0` | Botón principal al pasar el ratón |
| `acento_linea` | `#6A55E0` | `#8F7DFF` | Foco del teclado, pestaña activa, borde de la tarjeta elegida |
| `acento_suave` | `#EEEBFF` | `#2D2650` | Fondo de lo seleccionado (zona, chip, miniatura) |
| `acento_texto` | `#4B37C4` | `#C9C0FF` | Texto sobre `acento_suave` (6,8:1 / 8,3:1) |
| `exito` | `#17794C` | `#4CC38A` | Informe «bien» |
| `aviso` | `#946000` | `#F2B544` | Informe «aviso» |
| `error` | `#D63A40` | `#FF6B70` | Informe «error» |
| `forma_fondo` / `forma_texto` | `#EEEBFF` / `#4B37C4` | `#2D2650` / `#CFC7FF` | Insignia «Forma» |
| `proporcion_fondo` / `proporcion_texto` | `#E0F4F6` / `#0B6E78` | `#12363B` / `#8EE3EC` | Insignia «Proporción» |
| `crear_fondo` / `crear_texto` | `#FFF1D6` / `#8A5A00` | `#3A2A0A` / `#F7C873` | Insignia «Por crear» |
| `vista_centro` → `vista_borde` | `#FFFFFF` → `#E6E1F3` | `#2B2640` → `#14121B` | Degradado radial de la vista 3D |
| `sombra_suelo` | negro al 18 % | negro al 35 % | Mancha bajo los pies |

El rosa coral (`#E2477A` / `#FF7AA2`) queda solo para ilustraciones (miniaturas, logotipo), nunca para texto.

### 3.2 Letra

| Token | Tamaño | Peso | Uso |
| --- | --- | --- | --- |
| `letra_titulo` | 18 px | 700 | Nombre de la zona, títulos de diálogo |
| `letra_cuerpo` | 14 px | 500 | Etiquetas, botones, pestañas |
| `letra_valor` | 13 px | 600 | Números de los deslizadores (cifras de ancho fijo si la fuente lo permite) |
| `letra_pequena` | 12 px | 600 | Insignias, «Pronto», barra de estado. **Nada por debajo de 12 px.** |

Fuente: una **redondeada** da el aire amable que buscamos. **Nunito** (SIL OFL 1.1, comprobada; D30 b), variable: los pesos 500, 600 y 700 con `FontVariation` (eje `wght`).

### 3.3 Espacio, formas y movimiento

- **Espaciado:** múltiplos de 4: 4, 8, 12, 16, 24, 32. Margen interior de los paneles: 16. Separación entre filas de deslizadores: 12.
- **Radios:** 8 (botones, campos, chips), 12 (tarjetas, miniaturas), 16 (paneles flotantes de la vista), 999 (pastillas: barra de poses, insignias).
- **Sombras:** solo en lo que flota sobre la vista (barra de poses, botones flotantes, diálogos): 0 4 16 con negro al 10 % (claro) o al 40 % (oscuro).
- **Altura mínima de lo que se pulsa:** 32 px (36 px el botón principal).
- **Movimiento:** al pasar el ratón, cambio de color en 120 ms; abrir o plegar un panel, 180 ms con salida suave; la cámara ya se mueve suave (P.3). Con la opción «Reducir animaciones», todo es instantáneo.

---

## 4. Componentes

**Botón principal** (`BotonPrincipal`): fondo `acento`, texto blanco 14/600, radio 8, alto 36, icono a la izquierda. Solo uno por pantalla (Exportar; en un diálogo, su botón de aceptar).

**Botón secundario** (estilo por defecto de `Button`): fondo `panel`, borde 1 px `borde_fuerte`; al pasar el ratón, fondo `panel_2`; pulsado, `acento_suave` con texto `acento_texto`.

**Botón fantasma** (`BotonFantasma`): sin fondo ni borde hasta pasar el ratón. Para Deshacer, Rehacer, restablecer (↺) y los iconos de la vista.

**Pestaña principal:** texto 14/600 con icono de 18 px. Activa: texto `texto` y una línea de 3 px `acento_linea` debajo. Inactiva: `texto_2`. Al pasar el ratón, fondo `panel_2`.

**Chip** (`Chip`): pastilla de 28 px con radio 999. Elegido: `acento_suave` + `acento_texto`. Se usa para las vistas rápidas, la barra de poses y los filtros.

**Fila de deslizador** (lo más usado; se cuida al detalle):

```
Tamaño            Forma ·   ──────────●──────────   [ 50 ]  ↺
```

- Nombre (14/500, `texto`) e insignia de tipo pequeña (12/600, pastilla) en la misma línea.
- Barra de 4 px con radio 999: la parte rellena en `acento` **desde el valor neutro**, no desde la izquierda. Así se ve de un vistazo cuánto se ha alejado del neutro y hacia qué lado.
- Una marca fina en la posición del neutro.
- Agarrador: círculo de 18 px, blanco con borde 2 px `acento`; al pasar el ratón crece a 20 px.
- Número de 0 a 100 a la derecha (`letra_valor`). Se puede pulsar y escribir. Por dentro sigue siendo de 0 a 1.
- ↺ restablece solo ese deslizador (también con doble clic en el nombre). Se ve atenuado si el valor ya es el neutro.
- Ayuda al pasar el ratón: una frase de qué cambia («Hace la cabeza más ancha o más estrecha»). Los textos van en `godot/app/textos/ayuda_deslizadores.csv` (`id,ayuda,extremo_izq,extremo_der`); así `datos/` no cambia.
- Extremos con nombre cuando aporta: Complexión muestra «Femenino» y «Masculino» bajo la barra.
- **Dos lados:** con Simetría activada, las filas «(izq.)» y «(der.)» se ven como **una sola fila** con un pequeño ⇆. Al desactivarla, se abren en dos filas «Izq.» y «Der.».
- «Por crear»: fila atenuada con su insignia ámbar y la ayuda «Llega en una versión futura».

**Silueta de zonas:** dibujo propio (SVG) de un cuerpo de frente, con cada zona como forma pulsable. Al pasar el ratón, la zona se rellena en `acento_suave` con borde `acento_linea`; la elegida queda rellena. Debajo, la lista: icono, nombre y número de ajustes.

**Miniatura** (`Tarjeta`): tarjeta de radio 12 con una imagen de 1:1 renderizada **por el propio editor** y el nombre debajo. Elegida: borde 2 px `acento_linea` y un ✓. Si es de terceros, el autor y la licencia van en una línea pequeña debajo del nombre.

**Barra de poses** (flotante, abajo en la vista): pastilla `panel` con sombra, chips Reposo · Pose T · Caminar · Correr · Atacar · Sentarse · Rango de movimiento, y un botón ▶/⏸.

**Interruptores de la vista** (flotantes, arriba a la derecha): botones fantasma de 32 px con icono y ayuda: Simetría, Prenda base, Rejilla, Luz (abre un pequeño panel con ángulo e intensidad; solo para ver, no se exporta).

**Vistas rápidas** (arriba a la izquierda): Frente, Lado, ¾, Espalda, Cara. Llevan la cámara con el movimiento suave del P.3.

**Barra de estado:** pastilla del informe (✓ verde / ⚠ ámbar / ✕ rojo, con texto, nunca solo color), medidas y presupuesto en `texto_3` 12/600.

**Diálogos** (simetría, exportar, licencias, cambios sin guardar): tarjeta `panel` centrada, radio 16, sombra, fondo de la ventana oscurecido al 40 %. Botón principal a la derecha; Cancelar como secundario a su izquierda.

**Ayudas (tooltips):** fondo `texto` y letra `panel` (inverso), radio 8, 13 px, aparecen a los 400 ms.

---

## 5. Cómo se construye en Godot 4.7

### 5.1 Archivos

```
godot/app/tema/
  tokens.gd           # CLARO y OSCURO: diccionarios con los tokens de §3 (lo único con colores y tamaños)
  theme_builder.gd    # build(tokens, escala) -> Theme, por código (texto revisable, como recomienda la ficha 14)
  iconos/*.svg        # 24 px, trazo 2 px, color blanco (se tiñen con el tema)
  fuentes/            # nunito.ttf + ofl.txt (D30 b)
godot/app/textos/ayuda_deslizadores.csv
```

### 5.2 Qué estiliza cada token

| Control de Godot | Elementos del tema | Tokens |
| --- | --- | --- |
| `Button` | estilos `normal`, `hover`, `pressed`, `disabled`, `focus`; colores `font_color`, `font_hover_color`, `font_pressed_color` | `panel`, `panel_2`, `acento_suave`, `borde_fuerte`, `acento_linea` |
| Variación `BotonPrincipal` (base `Button`) | los mismos estilos | `acento`, `acento_hover`, blanco |
| `TabBar` / `TabContainer` | `tab_selected`, `tab_unselected`, `tab_hovered`, `tab_disabled`, `panel` | `panel`, `panel_2`, `acento_linea` |
| `HSlider` | estilos `slider`, `grabber_area`, `grabber_area_highlight`; iconos `grabber`, `grabber_highlight` | `borde`, `acento`, iconos SVG del agarrador |
| `PanelContainer` y variación `Tarjeta` | estilo `panel` (`StyleBoxFlat` con radio y margen interior) | `panel`, `borde` |
| `LineEdit`, `SpinBox` | `normal`, `focus`, `read_only` | `panel_2`, `borde_fuerte`, `acento_linea` |
| `CheckButton`, `CheckBox` | iconos `checked`, `unchecked` (SVG propios) | `acento` |
| `TooltipPanel` / `TooltipLabel` | estilo `panel`, `font_color` | `texto` (fondo), `panel` (letra) |
| `ScrollBar` | `scroll`, `grabber`, `grabber_highlight` | barra fina de 6 px, `borde_fuerte` |
| `PopupMenu`, `AcceptDialog`, `FileDialog` | `panel`, `hover`, `separator` | `panel`, `panel_2`, `borde` |

- Todo con `StyleBoxFlat` (`set_corner_radius_all`, `set_content_margin_all`, `set_border_width_all`, `shadow_size`, `shadow_offset`, `anti_aliasing`).
- Las variaciones se declaran con `Theme.set_type_variation(nombre, tipo_base)` y se usan con `theme_type_variation` en el control.
- El `Theme` se pone **una vez** en la raíz (`main.gd`); los hijos lo heredan.
- **Escala de la interfaz:** `get_window().content_scale_factor`, con la opción «Tamaño de la interfaz» (90–150 %) guardada en `user://ajustes.cfg` (`ConfigFile`). Valor inicial: el de `DisplayServer.screen_get_scale()` (en Linux con X11 puede devolver 1: comprobarlo).
- **Iconos SVG:** Godot los importa como textura. Se dibujan en blanco y se tiñen con `icon_normal_color` / `icon_hover_color` / `icon_pressed_color` del tema.

### 5.3 La vista 3D bonita sin tocar el estilo del personaje

- **Fondo:** `SubViewport.transparent_bg = true` y, detrás, un `TextureRect` con `GradientTexture2D` radial (`vista_centro` → `vista_borde`). **Comprobar** que el contorno toon (caras invertidas) y las capturas de las pruebas no cambian; si algo cambia, plan B: el mismo degradado como `Environment` con fondo de color y una esfera de cielo propia.
- **Sombra de suelo:** un `MeshInstance3D` plano bajo los pies, con un shader que dibuja una mancha radial suave (sin texturas). Sigue la posición del personaje en X y Z y se queda en el suelo al animar.
- **Rejilla opcional:** el mismo plano con líneas cada 0,5 m, apagada por defecto.
- **Luz de vista previa:** gira la `DirectionalLight3D` de la vista (ángulo e intensidad). No se guarda en el preset ni se exporta.
- El color de fondo de las **pruebas** no cambia: las capturas de `pruebas/` usan sus propias escenas. Si alguna usa `main.gd`, se fija su fondo en la prueba.

### 5.4 Reglas para que no se estropee con el tiempo

- En `godot/app/`, fuera de `tema/`, **ningún** `Color(`, `add_theme_color_override`, `add_theme_font_size_override` ni `add_theme_stylebox_override`. La prueba lo busca con texto (como `probar_ventana.gd` busca `app/` en el núcleo).
- Los colores de las insignias de tipo salen de los tokens (`TYPE_COLORS` de `slider_panel.gd` desaparece).
- Un control nuevo usa una variación existente; una variación nueva se añade al `theme_builder.gd` y a la tabla de §5.2.

---

## 6. Textos

- Español neutro, frases cortas, sin tecnicismos en la ventana. Los términos técnicos pueden ir en la ayuda.
- Cambios: «Rim» → «Brillo de borde» (fuerza y ancho); «Borde» → «Suavidad de la sombra»; «Probar huesos» → chip «Pose T» en la barra de poses; «Informe de deformación» se mantiene.
- Números con coma decimal (P.5). Medidas: «1,68 m», «6,9 cabezas».
- Avisos que dicen qué hacer: no «Error al exportar», sino «No se pudo guardar en esa carpeta. Elige otra o revisa los permisos».

## 7. Accesibilidad

- Contraste: texto ≥ 4,5:1; el agarrador del deslizador ≥ 3:1 frente a su fondo (D43).
- El color nunca va solo: el informe lleva icono y palabra; las insignias, texto.
- Todo se puede usar con teclado: Tab recorre los controles con un foco visible (`acento_linea`, 2 px); flechas mueven el deslizador enfocado (paso 1; con Mayús, 10).
- Tamaño de la interfaz ajustable y opción «Reducir animaciones».

## 8. Cómo se comprueba

- **Sin ventana — `probar_tema.gd`:** (1) los dos juegos de tokens tienen las mismas claves; (2) los pares de §3.1 cumplen los contrastes; (3) el `Theme` tiene estilo para cada control de §5.2; (4) ningún tamaño de letra baja de 12; (5) la búsqueda de colores sueltos de §5.4 da 0 resultados. Que detecta el fallo: poner `texto_3` a `#B0B0B0` hace saltar (2).
- **Las pruebas de la ventana que ya existen** (`probar_ventana`, `probar_panel`, `probar_acciones`, `probar_informe`, `probar_encuadre`…) siguen pasando. Si una depende del orden de los nodos y cambia por la nueva distribución, se adapta en el mismo paso y se dice en el informe.
- **Con ventana — capturas** en `pruebas/capturas/interfaz/`: claro y oscuro, a 1280 × 720 y a 1920 × 1080, y al 150 %. Lo juzga el responsable (regla «lo visual lo juzgo yo»).

## 9. Decisiones que necesita (detalle en `propuestas/expansion_v2.md` §7)

- **D30:** decidida: Nunito.
- **D33:** iconos dibujados por nosotros (CC0) o un juego MIT (Tabler Icons, licencia por comprobar).
- **D34:** decidida: oscuro por defecto, con un botón pequeño y visible para cambiar a claro.
- **D35:** la pestaña Exportar pasa a botón principal con diálogo.
