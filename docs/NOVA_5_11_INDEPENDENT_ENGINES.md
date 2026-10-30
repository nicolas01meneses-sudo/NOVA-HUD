# NOVA 5.11 NEON — motores independientes en el script móvil

Esta rama deriva de `ui/normal-auto-buy-5-10` y **no requiere instalar un laboratorio** para revisar el código o el cargador. Las versiones 5.10 y anteriores siguen intactas.

## Cambios verificables en el código

1. **Recolección independiente del motor de compras.** `runCollectionTick()` se ejecuta en su propia tarea. La lógica original de Auto Comprar sigue en otro ciclo; si un intento de compra espera brevemente, el motor de recolección puede continuar.
2. **Escaneo más eficiente del mapa.** `Workspace:GetDescendants()` se utiliza una vez para construir índices de `ProximityPrompt`, `ClickDetector`, `TouchTransmitter` y botones GUI. Después, los eventos `DescendantAdded` y `DescendantRemoving` mantienen el índice actualizado. Ya no se recorre todo el mapa cada 1,2 segundos para encontrar interacciones.
3. **Filtro por cercanía antes de inspeccionar etiquetas complejas.** El escaneo ahora evita clasificar modelos lejanos que no son objetivos actuales, lo que reduce el trabajo en dispositivos móviles.
4. **Contadores separados.** El HUD muestra intentos de recolección de fruta, hielo y dinero por separado de las compras verificadas por contador. Un intento enviado no es una recompensa confirmada.
5. **Sin filtros de color ni poder Remote Buy** en el modo principal de compra normal de NOVA 5.10. No se agregaron llamadas a remotos privados ni métodos para eludir la validación del servidor.

## Límites conocidos

- No hay prueba de funcionamiento real en el servidor de Sell Lemons, en Android ni con ejecutores externos. Los tests estáticos o la compilación Luau no prueban gameplay.
- Este cambio **no implementa** la compra a distancia sin mover al personaje como la observada en Hoshi, porque no conocemos su mecanismo ni tenemos un permiso del servidor para usarlo.
- La recolección de contactos físicos `TouchTransmitter` sigue limitada en el código legado; esos objetos pueden aparecer escaneados pero el intento devuelve que hay que acercarse físicamente. Tampoco es correcto afirmar que cada `ProximityPrompt` aceptará un intento.
- El motor de compra normal puede desplazar al personaje hacia plataformas; la recolección automática sigue condicionada a estar cerca de las interacciones compatibles.
- Los dos ciclos de ejecución no garantizan **paralelismo real** en el servidor: sólo evitan que la espera del scheduler de compras detenga el de recolección.
- Los controles de compra remota oficial siguen internamente como código legado desactivado de la interfaz y del scheduler. No se anuncian como funcionales.
- La lógica de precios, propiedad de terrenos y compra de la versión 5.10 fue conservada. Esto evita cambios no fundamentados en reglas del juego.

## Validación

- `node tests/static_5_11.test.cjs` comprueba estructura, presencia de los dos ciclos, indexado incremental, conservación de medidas básicas y cargador.
- GitHub Actions compila los archivos con el compilador oficial Luau fijado en un commit.
- **Pendiente:** evidencia en juego de detección de mejoras, latencia, reconocimiento de limones, aceptación de compras y recompensas.

## Para enviar evidencia útil desde el teléfono

Captura un video con las páginas **Build** y **Mundo 1** activando por separado Auto Comprar y Recoger fruta; después muestra el contador y el dinero del juego. Si aparecen intentos pero nada cambia, la causa puede ser un tipo de interacción incompatible o una validación del servidor. No debe interpretarse como compra confirmada.

## Reversión

Usa `NOVA_BOOT_5_10.lua` de la rama anterior. Ningún archivo original 5.10 se modifica en esta rama.
