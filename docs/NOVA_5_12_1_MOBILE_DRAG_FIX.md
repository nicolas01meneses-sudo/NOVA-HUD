# NOVA HUD 5.12.1 — corrección del límite superior en Android

Base: `ui/neon-5-12-stability`. Rama: `fix/mobile-hud-top-drag-5-12-1`.

## Evidencia

El usuario adjuntó dos videos el 30 de octubre de 2026. El video `279547.mp4`, de 11,28 segundos, muestra NOVA 5.12 abierto en **Visual**, escala 100%-110%, e intentos de arrastrar el HUD hacia la parte superior. El usuario describe una "pared invisible" que impide subirlo más.

Al revisar el código 5.12 se encontró:

```lua
local minY=halfHeight+58 -- leave room for Roblox mobile controls
```

Ese cálculo limita artificialmente la posición mínima del centro a la mitad de la altura de la ventana **más 58 píxeles**. Como el ScreenGui ya usa `IgnoreGuiInset=false`, esa reserva adicional no corresponde a una medición dinámica del área segura. La causa del bloqueo superior está confirmada en el código.

## Corrección

- Se reemplaza la barrera fija `halfHeight+58` por un límite basado en la **altura real escalada de la barra de título**.
- Permite que la ventana quede casi pegada a la parte superior y que un 35% de la barra de título pueda sobrepasar el borde. Como mínimo permanece visible el 65%, salvo escalas extremadamente pequeñas en que se conservan al menos 12 px.
- Si la ventana está ampliada y no entra completa en pantalla, todavía puede moverse en un intervalo vertical controlado. No queda inmovilizada por `maxY = minY`.
- Se preservan los límites horizontales, el soporte de orientación móvil, la escala 10–150%, el arrastre táctil y el botón flotante N para recuperar la interfaz.
- Se actualiza el texto de ayuda en Config y la versión visible a 5.12.1.
- No se modifica ningún motor de compra, recolección, Roblox Remote Buy, poderes o permisos.

## Comprobación aritmética

Con un dispositivo hipotético de 2772×1280 y escala 100%, el ajuste automático da `scale = 2.04`, la altura del HUD es aprox. 1122 px y la barra de título mide 149 px. Antes el borde superior mínimo era **+58 px** desde el origen de interfaz; ahora puede llegar aproximadamente a **−52 px**, manteniendo aproximadamente 97 px de la barra de título visibles. Son cálculos basados en el tamaño de cámara hipotético y no medidas directas del `ScreenGui` del video.

## Validación

1. `node tests/static_5_12_1.test.cjs` valida el código y las cotas de geometría en varios tamaños/zoom.
2. GitHub Actions compila HUD y loader con el compilador oficial de Luau.
3. **Pendiente:** probar arrastre y recuperación en el dispositivo real; la compilación Luau y los tests de geometría no sustituyen una prueba visual en Roblox/Android.

## Prueba rápida en Android

1. Inicia NOVA 5.12.1 y abre la pestaña Visual.
2. Arrastra desde la barra superior negra que dice NOVA hasta el borde superior de la pantalla.
3. Comprueba escalas 100% y 110% y que la barra de título permanezca parcialmente visible.
4. Si te resulta difícil moverla después de subirla, toca dos veces la N flotante para restablecer escala y mostrar la ventana.

## Rollback

El loader anterior permanece en la rama `ui/neon-5-12-stability` (`NOVA_BOOT_5_12.lua`). Esta revisión no modifica los archivos 5.12.
