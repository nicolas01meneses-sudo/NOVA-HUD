# NOVA HUD 5.6.1 — actualización del prototipo 5.6

Rama: `fix/legacy-56-buy-green`. La versión 5.6 de `main` permanece sin cambios.

## Qué se cambió

- Buscar el botón verde `BUY` en el HUD inferior de Sell Lemons mediante `GuiButton` y texto visible; se rechazan coincidencias ambiguas y elementos de tiendas premium.
- Se cambió el flujo manual de vinculación para pedir el BUY verde, no la flecha amarilla.
- Se incluyó un acceso de Auto Compra Remota en las pestañas Tierra y Marte, además de Build.
- Lectura orientativa del nombre/precio de la siguiente mejora a la derecha de BUY. Un cambio de texto **no es** compra confirmada.
- Auto Compra Remota apaga Auto Comprar, Auto Mejorar Puestos y el TP de hielo para evitar movimiento durante ese modo.
- Una bajada de saldo sin contador de compras no desbloquea Auto; dos intentos sin confirmación detienen el modo.
- Conserva los sistemas legados de Auto Ice, Auto Comprar por plataformas, Mejorar Puestos, Salto infinito y HUD NEON, **sin validarlos en el juego**.

## Prueba manual orientativa

1. Carga `NOVA_BOOT_5_6_1.lua` en el entorno donde estabas probando 5.6.
2. Abre **Build → Compra Remota Oficial → PROBAR 1 COMPRA REMOTA**. La búsqueda automática ahora prioriza el BUY verde.
3. Si aparece «No hay vínculo», usa **VINCULAR BUY VERDE** y selecciona el BUY visible. Tocar fuera no debe cerrar la selección.
4. Confirma si el panel lee «Siguiente: ...» con el nombre y precio correcto.
5. Comprueba si el contador del juego aumenta, el saldo cambia y si existe un error de entrada.
6. No mezcles Auto Ice / TP con Auto Compra Remota. Revisa los mensajes antes de activar AUTO.

## Límites

- **No hay prueba de ejecución real** en Sell Lemons ni garantía de compatibilidad con ejecutores externos.
- `VirtualUser` y otros mecanismos legados no garantizan que una interacción sea aceptada por el servidor de un juego de terceros.
- El contador estable de compras, cuando está disponible, permite declarar `confirmada`. El cambio de precio, texto o saldo es solo `observado`.
- NOVA 6.x sigue siendo una arquitectura separada para Roblox Studio; no es un loader 5.6.

El siguiente diagnóstico debe mostrar: botón detectado/vinculado, siguiente mejora, intentos, confirmaciones y motivo de rechazo.
