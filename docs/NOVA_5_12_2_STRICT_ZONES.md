# NOVA HUD 5.12.2 — corrección de orden de zonas (Marte y Tierra)

Rama `fix/strict-zone-order-5-12-2`, derivada de `fix/mobile-hud-top-drag-5-12-1`. La 5.12.1 permanece intacta.

## Incidente y evidencia

Video aportado por el usuario: `281153.mp4`, duración aproximada de **14,72 segundos**, resolución 2772×1280. En el segundo ~8 se observa el HUD **NOVA 5.12.1**, mundo **MARTE**, interruptor **AUTO COMPRAR: ON** y estado **`Zona 4/7: Oxygen Center · 1 pad(s) pagable(s)`**.

El jugador pide comprar en la primera zona antes de viajar a una zona avanzada. En la 5.12.1, `pricedBuildQueue` saltaba de `zoneStage[current]` a la primera `groups[index]` con botones pagables en zonas posteriores, **sin pruebas de que el mundo anterior estuviera completo**. Ese salto coincide con la señal visual del video. Además, `autoLocateStart` podía elegir como punto de inicio un botón cercano y barato, aunque perteneciera a zonas avanzadas.

## Cambios de NOVA 5.12.2

1. **Prioridad estricta por etapa**: la cola devuelve únicamente `groups[current]`. Ya no contiene el bucle que busca automáticamente las zonas `current+1` en adelante.
2. **No saltar por precio, cooldown, botón desconocido o falta de saldo**: cualquier pad observado dentro de la zona activa impide avanzar, aunque no pueda comprarse ahora. El HUD muestra un motivo específico.
3. **Inicio de primera zona verificable**: en Marte sólo se ancla automáticamente en un puesto con etiqueta Oxygen Pump / First Pump, y en Tierra con Lemon Stand / First Stand. No se ancla a una mejora barata del final. Si hay múltiples puestos iniciales ambiguos o no se reconoce el primero, se solicita marcarlo manualmente.
4. **Botones genéricos del inicio**: cuando un pad sin nombre de zona está a 55 studs o menos de un punto de inicio conocido, se atribuye a zona 1 antes de usar hitos de zonas posteriores. Un pad explícitamente marcado con una zona posterior conserva su clasificación.
5. **Avance automático con evidencia**: tras una compra de construcción cuyo contador del juego aumenta, NOVA guarda ese comprobante en `zoneReceipts[world][zone]`. Si no ve ningún pad de la zona y tiene un comprobante, exige **tres escaneos completos distintos**, no tres ticks del motor, antes de avanzar **sólo una zona**.
6. **Avance manual controlado**: en Build, el botón `ZONA TERMINADA → AVANZAR UNA` requiere dos pulsaciones en un máximo de ocho segundos, con mensaje de confirmación. Úsalo **únicamente** si esa zona estaba terminada antes de encender NOVA, pues no verifica compras.
7. **Restablecimiento**: `REINTENTAR PADS SIN RESPUESTA` vuelve a Zona 1 y limpia recibos y contadores de escaneos. `MARCAR INICIO AQUÍ (ZONA 1)` también restablece la progresión y exige estar físicamente en el verdadero comienzo.
8. **Estados legibles**: Build informa sobre `BLOQUEADA` (espera, fallos, precio no leído, saldo insuficiente) o `SIN SALTAR` en lugar de ocultar la causa detrás de un mensaje de filtros genérico.
9. **Sin alterar las demás funciones**: conserva Auto Collect, el arrastre móvil 5.12.1, protección de errores y el motor de compra normal (acercamiento/TP si lo permite el servidor). No añade compra remota que el servidor no autorice.

## Limitaciones

- Una compilación correcta y tests estáticos **no verifican funcionamiento real dentro de Sell Lemons**; hace falta comprobar en Android.
- Si los pads de Oxygen Pump/Lemon Stand no tienen nombres fiables o no están cargados, NOVA no adivinará su ubicación; **detendrá compras antes que irse a una zona equivocada**. Requiere evidencia de esa zona o marcar el inicio real manualmente.
- Los objetos y precios pueden no corresponder al juego si sus etiquetas cambiaron. Mostrar `Zona 1` es un diagnóstico del HUD, no garantía de que la zona se compró.
- La señal `Buttons Bought` sólo permite atribución tentativa al intento pendiente; si el juego no expone un contador fiable o sólo se observa que un pad desaparece, **NOVA no declara completada automáticamente la zona**.
- Si la primera zona ya estaba completa cuando se activó el script, NOVA podría detenerse en Zona 1. Usa el avance manual sólo tras verificarlo tú.
- Los tres escaneos completos reducen el riesgo de avanzar sobre datos obsoletos; no demuestran el estado de todos los pads del servidor.
- La compra en el juego de terceros sigue sujeta a sus reglas y validaciones; el script no desbloquea el poder Remote Buy.

## Prueba desde Android sin Studio

1. Ejecuta el loader 5.12.2 de esta rama y entra a **Marte**.
2. Busca el área **Oxygen Pump (Zona 1)**. Si el HUD no puede localizarla, ve físicamente a esa zona y entra a **Build → MARCAR INICIO AQUÍ (ZONA 1)**.
3. Activa **AUTO COMPRAR MARTE**. Revisa que no seleccione `Oxygen Center (Zona 4)` ni teletransporte hacia allí mientras Zona 1 permanezca pendiente.
4. En caso de bloqueo, abre **Build → ESTADO DE COMPRAS** y revisa el texto **BLOQUEADA** o **SIN SALTAR**. Una parada explícita es más segura que comprar por error en otras zonas.
5. Si ya compraste absolutamente todo en Zona 1 antes de encender NOVA, toca **ZONA TERMINADA → AVANZAR UNA** dos veces en ocho segundos, tras comprobarlo tú mismo.
6. Si aparece otro fallo, grabar pantalla mostrando `AUTO COMPRAR: ON` y el estado de zona/precio para distinguir reconocimiento de compras reales.

## Validación técnica

- Tests estructurales: `node tests/static_5_12_2.test.cjs`.
- Compilación con Luau oficial fijado por SHA en `.github/workflows/nova5122-static.yml`.
- PR en borrador hasta verificar movimiento y selección real en el teléfono.

## Reversión

La 5.12.1 original permanece disponible en `fix/mobile-hud-top-drag-5-12-1` sin cambios.
