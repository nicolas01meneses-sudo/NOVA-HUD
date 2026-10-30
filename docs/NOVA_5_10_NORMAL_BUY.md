# NOVA HUD 5.10 — Auto Comprar normal sin poder Remote Buy

## Resumen

La captura de NOVA 5.9 mostraba «COMPRA REMOTA OFICIAL» y «AUTO exige una compra confirmada». En esta actualización se elimina **esa dependencia de la interfaz** y se presenta el motor de Auto Comprar normal que el proyecto ya mantenía.

**Esta actualización NO desbloquea ni imita una compra remota de pago.** El motor original busca pads y mejoras ordinarias, se acerca al objetivo mediante movimiento o TP si es necesario, intenta interactuar según los mecanismos que el cliente reconoce y espera evidencia de compra. El servidor puede rechazar el movimiento, la interacción o la compra.

## Cambios de NOVA 5.10

- Nuevo HUD `NOVA_HUD_5_10_NEON.lua` y cargador `NOVA_BOOT_5_10.lua`, sobre la rama `ui/neon-5-9-mobile-diagnostics`; 5.9 conservada.
- Elimina de Mundo 1, Marte y Build los controles de **Auto Compra Remota oficial**, y las instrucciones de comprar ese poder.
- Dos botones en **Build** (Tierra y Marte) pasan a ser **interruptores reales** del motor de compras ordinarias, en vez de ser accesos a otras pestañas. Se sincronizan con los botones grandes de cada mundo.
- Activar Auto Comprar exige estar en el mundo correspondiente. No simula haber comprado en otro mapa.
- Añade controles compartidos para **Recoger limones cerca (Tierra)** y **Recoger hielo cerca (Marte)**. Su estado se sincroniza con cada página y no se desactiva al activar Auto Comprar.
- Ajusta el diagnóstico para mostrar pads, botones UI, compra normal, recolección, intentos y compras *verificadas por contador*.
- Desactiva el bucle de compra remota oficial y su escaneo periódico. Conserva internamente código legado sin acceso desde la interfaz como referencia histórica: no se utiliza en el flujo 5.10.
- Conserva la comprobación contra tiendas premium y los límites del servidor; no agrega APIs de red desconocidas ni altera Robux.

## Límite importante

La petición «sin Compra Remota comprada» se satisface **para el modo de compra normal, con acercamiento**. Si el servidor de Sell Lemons requiere el poder para comprar desde cualquier lugar **sin mover el personaje**, NOVA no puede conceder ese permiso ni se declara que lo evita.

No se garantiza que el motor de 5.x funcione con un ejecutor externo ni que las interacciones se acepten. Una compra se reporta confirmada sólo cuando se obtiene evidencia reconocible. Tampoco se garantiza que la recolección funcione simultáneamente mientras el personaje se desplaza; las dos opciones se procesan en el mismo bucle de manera independiente.

## Verificación

- Pruebas estáticas: `node tests/static_5_10.test.cjs`.
- Compilación Luau: configurada en `.github/workflows/nova510-static.yml`, usando la versión oficial fijada por commit.
- Pendiente: prueba en Roblox Studio, dispositivos Android, validación del movimiento real y de la aceptación de compras por el servidor.
- Prueba recomendada: dentro de la experiencia autorizada, activar Recoger fruta en Tierra y Auto Comprar Tierra; comprobar que hay objetivos cercanos y que los contadores cambian de manera independiente.

## Rollback

`ui/neon-5-9-mobile-diagnostics` conserva el HUD y cargador 5.9. `ui/normal-auto-buy-5-10` contiene los archivos nuevos, sin modificar los originales.
